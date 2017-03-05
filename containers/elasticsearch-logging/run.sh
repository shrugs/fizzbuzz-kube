#!/bin/bash

set -e

# We need to chown the volume at runtime, hence this run.sh script
chown -R elasticsearch:elasticsearch /data

# Elasticsearch no longer support disk-based templates, so we have to add the index template via the API
# after the cluster starts up.
# Then, to make the template apply to the indices, delete all of the existing ones.
# > curl -X DELETE localhost:9200/_all;
# This is only necessary to run _once_ at cluster create time. After the first EBS volume is created,
# new nodes will resume where the previous left off, and this command is idempotent.
# (
#     sleep 120; \
#     curl -X PUT --header "Content-Type: applications/json" \
#         -d @/usr/share/elasticsearch/config/templates/template-k8s-logstash.json \
#         localhost:9200/_template/template_k8s_logstash; \
#     echo "Updated Index Template" \
# ) &

exec elasticsearch -Des.insecure.allow.root=true
