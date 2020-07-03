# Overview

Kip is a Virtual Kubelet provider that allows a Kubernetes cluster to
transparently launch pods onto their own cloud instances. The kip pod is run on
a cluster and will create a virtual Kubernetes node in the cluster. When a pod
is scheduled onto the Virtual Kubelet, Kip starts a right-sized cloud instance
for the pod’s workload and dispatches the pod onto the instance. When the pod
is finished running, the cloud instance is terminated. We call these cloud
instances “cells”.

When workloads run on Kip, your cluster size naturally scales with the cluster
workload, pods are strongly isolated from each other and the user is freed from
managing worker nodes and strategically packing pods onto nodes. This results
in lower cloud costs, improved security and simpler operational overhead.

# Installation

## Command line instructions

Follow these instructions to install Kip Enterprise from the command line.

### Prerequisites

- An EKS cluster
- [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) >= 1.14, configured to access the EKS cluster
- [kustomize](https://github.com/kubernetes-sigs/kustomize) >= 3.0.0

If you want to enable image caching, you also need an EFS or NFS server in
your VPC. Image caching will decrease pod start up times, especially if the
images used by your pods are large.

### Install from the command line

Set environment variables (modify if necessary):

    export NAME=kip
    export NAMESPACE=kip
    export IMAGE_TAG=v0.1.0 # Change this to the version you want to install.

To be able to cache images and decrease pod start times, it is recommended that
you use an [EFS volume](https://aws.amazon.com/efs/). You can specify the EFS
volume to use via:

    export NFS_VOLUME_ENDPOINT=fs-92e61897.efs.us-west-2.amazonaws.com:/

See [the section on image caching](#enable-image-caching) for more information.

There are other variables you can use, but they are rarely needed to be changed
from their defaults. Only change them if you know what you are doing.

    export USE_REGION=us-west-2 # This is autodetected by Kip.
    export IMAGE_REGISTRY=689494258501.dkr.ecr.us-east-1.amazonaws.com

To deploy Kip, use the script:

    ./kustomize/deploy.sh
    
### Uninstall

To remove everything, first make sure you have terminated all [cells](https://github.com/elotl/kip/blob/master/docs/cells.md) started by Kip. Then simply:

    export NAMESPACE=kip # Namespace used for installation.
    kubectl delete namespace $NAMESPACE

### Enable image caching

TODO
