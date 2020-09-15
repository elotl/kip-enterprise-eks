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

- An EKS cluster, Kubernetes 1.16 or higher configured with [IAM Roles for Service Accounts}(https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
- [envsubst](https://www.gnu.org/software/gettext/manual/html_node/envsubst-Invocation.html)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) >= 1.14, configured to access the EKS cluster
- [kustomize](https://github.com/kubernetes-sigs/kustomize) >= 3.0.0

If you want to enable image caching, you also need an EFS or NFS server in
your VPC. Image caching will decrease pod start up times, especially if the
images used by your pods are large.

### Create an IAM role for the kip service account

1. Enable OIDC for service accounts in your cluster by following the instructions [here](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).
2. Create service account linked IAM role for Kip:

Create an IAM role for the Kip pod and configure it with the following policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "aws-marketplace:RegisterUsage",
                "aws-marketplace:MeterUsage"
                "ec2:ModifyVolume",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:DescribeInstances",
                "ec2:TerminateInstances",
                "ec2:CreateTags",
                "ec2:DeleteRoute",
                "ecr:GetAuthorizationToken",
		"ecr:GetDownloadUrlForLayer",
		"ecr:BatchGetImage",
                "ec2:DescribeDhcpOptions",
                "ec2:RunInstances",
                "ec2:DescribeSecurityGroups",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DescribeImages",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeAvailabilityZones",
                "ec2:ModifyInstanceCreditSpecification",
                "ec2:CreateRoute",
                "ec2:DescribeVpcs",
                "ec2:CreateSecurityGroup",
                "ec2:DescribeVolumes",
                "ec2:DeleteSecurityGroup",
                "ec2:ModifyInstanceAttribute",
                "ec2:DescribeSubnets",
                "ec2:DescribeRouteTables",
                "ec2:AssociateIamInstanceProfile",
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
```
Create a trust relationship on the IAM role, with the following fields replaced

* Replace `$AWS_ACCOUNT_ID` with your AWS account ID (e.g. 123456789012)
* Replace `$OIDC_PROVIDER` with your cluster's OIDC provider's URL (e.g. oidc.eks.us-east-1.amazonaws.com/id/AAAABBBBCCCCDDDDEEEEFFFF00001111)
* Replace `$NAMESPACE` with the namespace kip will run in (defaults to kip)
* Replace `KIP_SERVICE_ACCOUNT_NAME` with the name of the kip service account (defaults to "kip-provider")

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER:sub": "system:serviceaccount:$NAMESPACE:$BUILDSCALER_SERVICE_ACCOUNT_NAME"
        }
      }
    }
  ]
}
```

### Install from the command line

Set environment variables (modify if necessary):

    export CLUSTER_NAME=kip # Name of your EKS cluster.
    export USE_REGION=us-west-2
    export IMAGE_TAG=1.0-latest  # Change this to the version you want to install.
    export KIP_SERVICE_ACCOUNT_ROLE_ARN=arn:aws:iam::012345678910:role/kip-enterprise # REQUIRED: fill in with the ARN of the IAM role created for KIP

To be able to cache images and decrease pod start times, it is recommended that
you use an [EFS volume](https://aws.amazon.com/efs/). You can specify the EFS
volume to use via:

    export NFS_VOLUME_ENDPOINT=fs-92e61897.efs.us-west-2.amazonaws.com:/

See [the section on image caching](#enable-image-caching) for more information.

There are other variables you can use, but they are rarely needed to be changed
from their defaults. Only change them if you know what you are doing.

    # Set a namespace.
    export NAMESPACE=elotl-kip

    # Image registry to pull images from.
    export IMAGE_REGISTRY=117940112483.dkr.ecr.us-east-1.amazonaws.com/4737f648-c51e-4cca-a3a5-afe7268bf539/cg-2196059056

    # An existing instance profile that will be associated with cells by
    # default. This can be overridden via the pod.elotl.co/instance-profile
    # annotation in pod manifests.
    export CELL_INSTANCE_PROFILE_ARN=arn:aws:iam::11123456789:instance-profile/kip-cell

To deploy Kip, use the script:

    ./kustomize/deploy.sh

### Uninstall

To remove everything, first make sure you have terminated all [cells](https://github.com/elotl/kip/blob/master/docs/cells.md) started by Kip via terminating all deployments, pods, etc running via Kip.

To check pods running via Kip (use the right node name if it is not
`kip-provider-0`):

    kubectl get pods --field-selector spec.nodeName=kip-provider-0 -A

Once no more pods are running via Kip:

    export NAMESPACE=kip # Namespace used for installation.
    kubectl delete namespace $NAMESPACE

You might also want to remove all the resources you create in [the section on image caching](#enable-image-caching).

### Enable image caching

You need the following:
* AWS_ACCESS_KEY_ID and AWS_SECRET_KEY_ID set to a working access key.
* AWS_REGION set to the desired target region, for example "us-west-2".
* A VPC with at least one subnet, where your EKS cluster is installed. Set the
  environment variable VPC_ID to this VPC ID.

You can find the VPC ID using the following command:

    aws ec2 describe-vpcs

Choose the one that your EKS cluster uses and set VPC_ID to point to it.

List the subnets of this VPC:

    aws ec2 describe-subnets \
    --filters Name=vpc-id,Values=$VPC_ID \
    --region $AWS_REGION

Write down the subnet IDs of the VPC.

Create a security group that will be attached to Kip cells:

    aws ec2 create-security-group \
    --region $AWS_REGION \
    --group-name kip-cells \
    --description "Kip Cells" \
    --vpc-id $VPC_ID

Note the security group ID from the response, and set `KIP_CELL_SG` to it:

    {
        "GroupId": "<kip-cells SG ID>"
    }

    export KIP_CELL_SG=<kip-cells SG ID>

Create a second security group for your Amazon EFS mount target:

    aws ec2 create-security-group \
    --region $AWS_REGION \
    --group-name kip-efs-mt \
    --description "Kip EFS Mount Target" \
    --vpc-id $VPC_ID

    {
        "GroupId": "<kip-efs-mt SG ID>"
    }

    export EFS_MT_SG=<kip-efs-mt SG ID>

Authorize inbound access to the security group for the Amazon EFS mount target
(kip-efs-mt):

    aws ec2 authorize-security-group-ingress \
    --group-id $EFS_MT_SG \
    --protocol tcp \
    --port 2049 \
    --source-group $KIP_CELL_SG \
    --region $AWS_REGION

Create an EFS file system:

    aws efs create-file-system \
    --creation-token kip-efs-$RANDOM \
    --tags Key=Name,Value=kip-efs \
    --region $AWS_REGION

Response:

        {
            "OwnerId": "123456789abcd",
            "CreationToken": "kip-efs-24609",
            "FileSystemId": "<EFS filesystem ID>",
            "CreationTime": 1548950706.0,
            "LifeCycleState": "creating",
            "NumberOfMountTargets": 0,
            "SizeInBytes": {
                "Value": 0,
                "ValueInIA": 0,
                "ValueInStandard": 0
            },
            "PerformanceMode": "generalPurpose",
            "Encrypted": false,
            "ThroughputMode": "bursting",
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "kip-efs"
                }
            ]
        }

        export EFS_FS_ID=<EFS filesystem ID>

Create mount targets in each subnet:

    aws efs create-mount-target \
    --file-system-id $EFS_FS_ID \
    --subnet-id <subnet-id of VPC> \
    --security-group $EFS_MT_SG \
    --region $AWS_REGION

Repeat this last step creating mount targets for each subnet in your VPC.

Now that your EFS volume has been configured, you can deploy Kip:

    export NFS_VOLUME_ENDPOINT=$EFS_FS_ID.efs.$AWS_REGION.amazonaws.com:/

Deploy Kip the usual way:

    export CLUSTER_NAME=kip
    export NAMESPACE=kip
    export USE_REGION=$AWS_REGION
    export IMAGE_TAG=1.0-latest # Change this to the version you want to install.

    ./kustomize/deploy.sh

A deployment for the image cache controller will be started using the new EFS volume.
