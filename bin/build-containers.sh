#!/bin/bash

USER_NAME=shrugs

docker build -t $USER_NAME/fizzbuzzer:latest containers/fizzbuzzer
docker push $USER_NAME/fizzbuzzer:latest

docker build -t $USER_NAME/fluentd-logging:latest containers/fluentd-logging
docker push $USER_NAME/fluentd-logging:latest

docker build -t $USER_NAME/elasticsearch-logging:latest containers/elasticsearch-logging
docker push $USER_NAME/elasticsearch-logging:latest
