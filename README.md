# FizzBuzz in Kubernetes

A distributed, fault-tolerant, production-ready FizzBuzz implementation for the microservice cloud.

## Run the FizzBuzz

Dependencies:
- [`aws cli`](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) (`pip install --upgrade --user awscli`)
- [`jq`](https://stedolan.github.io/jq/) (`brew install jq`)
- [`kops`](https://github.com/kubernetes/kops) (`brew install kops`)
- [`kubectl`](https://kubernetes.io/docs/user-guide/prereqs/) (`brew install kubectl`)
- An existing Route53 Hosted Zone that is correctly serving DNS queries.
    + Easiest way to do this is simply set up a Hosted Zone for a subdomain already handled in Route53. Something like `cluster.example.com`.
- aws cli must be authenticated with a user that has the following group policies
    + `arn:aws:iam::aws:policy/AmazonEC2FullAccess`
    + `arn:aws:iam::aws:policy/AmazonRoute53FullAccess`
    + `arn:aws:iam::aws:policy/AmazonS3FullAccess`
    + `arn:aws:iam::aws:policy/IAMFullAccess`
    + `arn:aws:iam::aws:policy/AmazonVPCFullAccess`

Then, finally,

```bash
./bin/get-programming-job.sh cluster.example.com
```

## What Happens

- Create an S3 bucket to store the `kops` state,
- Create a multi-zone Kubernetes cluster using `kops`,
- Wait for the cluster to spin up and schedule pods,
- Deploy an ElasticSearch `StatefulSet`,
- Deploy a fluentd `DaemonSet` running a pod on each node in the cluster which forwards logs to ElasticSearch for indexing,
- Deploy a 100-replica `StatefulSet` of the `fizzbuzzer` container, which accepts a `StatefulSet` hostname (`fizzbuzzer-n`) as an argument and computes whether or not it should output `Fizz`, `Buzz`, `FizzBuzz`, or `n`.
- Waits for all of those pods to have spun up and then,
- Queries the ElasticSearch Search API to collect all of the logs from the `fizzbuzzer` pods,
- Outputs the result of the FizzBuzz,
- Tears everything down (cluster, s3 bucket)

## Why

Someone had to.

