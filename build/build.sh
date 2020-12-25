#!/usr/bin/env bash

set -euxo pipefail

REGISTRY=${REGISTRY:-689494258501.dkr.ecr.us-east-1.amazonaws.com}
TAG=${TAG:-$(git describe --dirty)}
APPS="init-cert kip kube-proxy image-cache-controller kip-aws-meteringagent kip-uptime"

for APP in $APPS; do
    docker build -t ${REGISTRY}/elotl/${APP}:${TAG} -f Dockerfile.${APP} .
    docker push ${REGISTRY}/elotl/${APP}:${TAG}
done
