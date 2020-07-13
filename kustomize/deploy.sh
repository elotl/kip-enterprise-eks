#!/usr/bin/env bash

set -euo pipefail

export CLUSTER_NAME=${CLUSTER_NAME:-kip}
export NAMESPACE=${NAMESPACE:-kip}
export USE_REGION=${USE_REGION:-}
export IMAGE_REGISTRY=${REGISTRY:-689494258501.dkr.ecr.us-east-1.amazonaws.com}
export IMAGE_TAG=${TAG:-v0.1.0}
export NFS_VOLUME_ENDPOINT=${NFS_VOLUME_ENDPOINT:-}
export IMAGE_CACHE_CONTROLLER_REPLICAS=$([[ -n "${NFS_VOLUME_ENDPOINT}" ]] && echo -n 1 || echo -n 0)
export CELL_SECURITY_GROUP=${CELL_SECURITY_GROUP:-}
export CELL_INSTANCE_PROFILE_ARN=${CELL_INSTANCE_PROFILE_ARN:-}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

[[ -n $USE_REGION ]] && echo "Deploying in region \"$USE_REGION\""

[[ -n $CELL_SECURITY_GROUP ]] && EXTRA_SECURITY_GROUPS="[ $CELL_SECURITY_GROUP ]" || EXTRA_SECURITY_GROUPS="[]"
export EXTRA_SECURITY_GROUPS

kubectl version > /dev/null 2>&1 || {
    echo "Missing kubectl or configuration problem"
    exit 1
}

kustomize version > /dev/null 2>&1 || {
    echo "Missing kustomize"
    exit 1
}

envsubst --version > /dev/null 2>&1 || {
    echo "Missing envsubst"
    exit 1
}

kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

kustomize build "${SCRIPT_DIR}" | envsubst | kubectl apply -f -
