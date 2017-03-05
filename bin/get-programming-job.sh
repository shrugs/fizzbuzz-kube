#!/bin/bash

# create S3 bucket for state store
# assume route53 zone already exists

# http://unix.stackexchange.com/questions/45404/why-cant-tr-read-from-dev-urandom-on-osx
LC_CTYPE=C

check_for() {
  command -v $1 >/dev/null 2>&1 || { echo >&2 "I require $1 but it's not installed. Aborting."; exit 1; }
}

confirm_dependencies() {
  check_for aws
  check_for jq
  check_for kubectl
  check_for kops

  HOSTED_ZONE_NAME=$1
  if [[ $(aws route53 list-hosted-zones) == *"$HOSTED_ZONE_NAME"* ]]; then
    echo "Hosted Zone $HOSTED_ZONE_NAME exists."
  else
    echo "Must have a Route53 Hosted Zone previously set up. Aborting."; exit 1;
  fi
}

create_state_store() {
  BUCKET_NAME=$1
  aws s3api create-bucket --bucket "$BUCKET_NAME" --region us-east-1
}

delete_state_store() {
  BUCKET_NAME=$1
  aws s3api delete-bucket --bucket "$BUCKET_NAME" --region us-east-1
}

wait_for_cluster() {
  CLUSTER_NAME=$1

  echo "[🚧 Creation] Waiting for cluster to be ready. This takes a while, go grab a coffee or something."
  until kubectl --context $CLUSTER_NAME get nodes
  do
    echo -n .
    sleep 5
  done

  echo "[🚧 Creation] Waiting for cluster to be valid."
  until kops validate cluster $CLUSTER_NAME
  do
    echo -n .
    sleep 5
  done
}

wait_for_pods() {
  POD_LABEL=$1
  NAMESPACE=$2
  COUNT=$3

  echo "[🏃 Running] Waiting for $POD_LABEL in $NAMESPACE to reach $COUNT instances"
  until [[ $(kubectl get pods -n $NAMESPACE -l component=$POD_LABEL -ojson | jq '.items | map(select(.status.phase == "Running")) | length') == $COUNT ]]
  do
    echo -n .
    sleep 5
  done
}

fizzbuzz_teardown() {
  UNIQUE_ID=$1
  CLUSTER_NAME=$2

  echo "[💥 Teardown] Deleting kops cluster $CLUSTER_NAME ..."
  kops delete cluster $CLUSTER_NAME --yes
  echo "[💥 Teardown] Done deleting kops cluster $CLUSTER_NAME"

  echo "[💥 Teardown] Deleting kops state store $UNIQUE_ID ..."
  delete_state_store $UNIQUE_ID
  echo "[💥 Teardown] Done deleting kops state store $UNIQUE_ID"

  unset KOPS_STATE_STORE
}

# Main

# ex: cluster.example.com
CLUSTER_NAME=$1


if [ -z "$CLUSTER_NAME" ]; then
    echo "Must provide a Route53 Hosted Zone Name like 'cluster.example.com'. It must exist."; exit 1;
fi

confirm_dependencies $CLUSTER_NAME

# ex: bU00kHjyn9ewV7nFc03wrUDXwUbdK0NV
UNIQUE_ID=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)

echo "The unique name for your resources is $UNIQUE_ID"
echo "The cluster name is $CLUSTER_NAME"

echo "[🚧 Creation] Building kops state store $UNIQUE_ID ..."
sleep 5  # wait for the previous command to propagate a bit on AWS' side
create_state_store $UNIQUE_ID
echo "[🚧 Creation] Done building kops state store $UNIQUE_ID"

export KOPS_STATE_STORE="s3://$UNIQUE_ID"

kops create cluster \
    --node-count=3 \
    --zones=us-east-1a,us-east-1b,us-east-1c \
    --master-zones=us-east-1a \
    --dns-zone=$CLUSTER_NAME \
    --node-size=t2.medium \
    --master-size=t2.micro \
    $CLUSTER_NAME

echo "[🚧 Creation] Building cluster $CLUSTER_NAME ..."
kops update cluster ${CLUSTER_NAME} --yes
echo "[🚧 Creation] Done building cluster $CLUSTER_NAME"

wait_for_cluster $CLUSTER_NAME

echo "[🏃 Running] Applying FizzBuzz Kubernetes configs..."
kubectl --context $CLUSTER_NAME apply -f ./configs/elasticsearch.yml
wait_for_pods elasticsearch-logging kube-system 1

kubectl --context $CLUSTER_NAME apply -f ./configs/fluentd.yml
wait_for_pods fluentd-logging kube-system 4

kubectl --context $CLUSTER_NAME apply -f ./configs/fizzbuzzer.yml
wait_for_pods fizzbuzzer default 100

echo "[🏃 Running] Done! All of the pods should be up!"

GET_CLUSTER_CREDENTIALS_COMMAND=$(printf "kubectl config view $CLUSTER_NAME -o json | jq '.users[] | select(.name == \"%q-basic-auth\") | .user'" $CLUSTER_NAME)
CLUSTER_CREDENTIALS=$(eval $GET_CLUSTER_CREDENTIALS_COMMAND)
CLUSTER_USER_NAME=$(echo $CLUSTER_CREDENTIALS | jq -r '.username')
CLUSTER_PASSWORD=$(echo $CLUSTER_CREDENTIALS | jq -r '.password')

echo "[🏃 Running] Nice, let's wait a bit for fluentd to ship all of the logs to ES..."
sleep 20

echo "[🏃 Running] Querying the Elasticsearch API..."

FIZZBUZZ=$(curl --insecure -u $CLUSTER_USER_NAME:$CLUSTER_PASSWORD "https://api.$CLUSTER_NAME/api/v1/proxy/namespaces/kube-system/services/elasticsearch-logging/_search?q=kubernetes.labels.component:fizzbuzzer&sort=@timestamp:asc&size=1000" | jq -r '.hits.hits[]._source.log')

echo "[🏃 Running] Let's see what kind of results we've got here."

echo $FIZZBUZZ

echo "[🏃 Running] Well that was anticlimactic."

read -p "Press enter to tear down"

fizzbuzz_teardown $UNIQUE_ID $CLUSTER_NAME

exit 0
