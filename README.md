# FizzBuzz in Kubernetes

A distributed, fault-tolerant, production-ready FizzBuzz implementation for the microservice cloud.

## Run the FizzBuzz

Dependencies:
- aws
- jq
- kops
- kubectl
- An existing Route53 Hosted Zone that is correctly serving DNS queries.
    - Easiest way to do this is simply set up a Hosted Zone for a subdomain already handled in Route53. Something like `cluster.example.com`.
- aws cli must be authenticated with a user that has the role `arn:aws:iam::aws:policy/IAMFullAccess`

## What Happens

- Create an IAM user with the appropriate roles necessary to bootstrap a Kubernetes cluster using `kops`,
- Create an S3 bucket to store the `kops` state,
- Create a multi-zone Kubernetes cluster using `kops`,
- Wait for the cluster to spin up and schedule pods,
- Deploy an ElasticSearch `StatefulSet`,
- Deploy a fluentd `DaemonSet` running a pod on each node in the cluster which forwards logs to ElasticSearch for indexing,
- Deploy a 100-replica `StatefulSet` of the `fizzbuzzer` container, which accepts a `StatefulSet` hostname (`fizzbuzzer-n`) as an argument and computes whether or not it should output `Fizz`, `Buzz`, `FizzBuzz`, or `n`.
- Waits for all of those pods to have spun up and then,
- Queries the ElasticSearch Search API to collect all of the logs from the `fizzbuzzer` pods,
- Outputs the result of the FizzBuzz,
- Tears everything down (cluster, s3 bucket, iam user)

## Why

Someone had to.

