#!/bin/bash

set -euo pipefail

LOG_DIR="$(dirname "$0")/../logs"
LOG_FILE="$LOG_DIR/cleanup-$(date +%Y-%m-%d).log"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================"
log "AWS Cost Optimisation Cleanup Started"
log "Region: $REGION"
log "========================================"

# ─────────────────────────────────────────
# EC2 INSTANCES
# ─────────────────────────────────────────
log "--- Stopping and Terminating EC2 Instances ---"

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running,stopped,stopping,pending" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  log "Terminating instances: $INSTANCE_IDS"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCE_IDS
  log "Waiting for instances to terminate..."
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INSTANCE_IDS
  log "EC2 instances terminated."
else
  log "No EC2 instances found."
fi

# ─────────────────────────────────────────
# EKS CLUSTERS
# ─────────────────────────────────────────
log "--- Deleting EKS Clusters ---"

EKS_CLUSTERS=$(aws eks list-clusters --region "$REGION" --query "clusters[]" --output text)

for CLUSTER in $EKS_CLUSTERS; do
  log "Deleting EKS cluster: $CLUSTER"

  NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$REGION" \
    --query "nodegroups[]" --output text)

  for NG in $NODE_GROUPS; do
    log "Deleting node group: $NG from cluster: $CLUSTER"
    aws eks delete-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NG" --region "$REGION"
    aws eks wait nodegroup-deleted --cluster-name "$CLUSTER" --nodegroup-name "$NG" --region "$REGION"
  done

  aws eks delete-cluster --name "$CLUSTER" --region "$REGION"
  aws eks wait cluster-deleted --name "$CLUSTER" --region "$REGION"
  log "EKS cluster $CLUSTER deleted."
done

# ─────────────────────────────────────────
# RDS INSTANCES
# ─────────────────────────────────────────
log "--- Deleting RDS Instances ---"

RDS_INSTANCES=$(aws rds describe-db-instances \
  --region "$REGION" \
  --query "DBInstances[*].DBInstanceIdentifier" \
  --output text)

for DB in $RDS_INSTANCES; do
  log "Deleting RDS instance: $DB"
  aws rds delete-db-instance \
    --db-instance-identifier "$DB" \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region "$REGION"
  log "RDS $DB deletion initiated."
done

# ─────────────────────────────────────────
# RDS CLUSTERS (Aurora)
# ─────────────────────────────────────────
log "--- Deleting RDS Aurora Clusters ---"

RDS_CLUSTERS=$(aws rds describe-db-clusters \
  --region "$REGION" \
  --query "DBClusters[*].DBClusterIdentifier" \
  --output text)

for CLUSTER in $RDS_CLUSTERS; do
  log "Deleting Aurora cluster: $CLUSTER"
  aws rds delete-db-cluster \
    --db-cluster-identifier "$CLUSTER" \
    --skip-final-snapshot \
    --region "$REGION"
  log "Aurora cluster $CLUSTER deletion initiated."
done

# ─────────────────────────────────────────
# ELASTIC LOAD BALANCERS (v2 - ALB/NLB)
# ─────────────────────────────────────────
log "--- Deleting Load Balancers (ALB/NLB) ---"

LB_ARNS=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancers[*].LoadBalancerArn" \
  --output text)

for LB in $LB_ARNS; do
  log "Deleting load balancer: $LB"
  aws elbv2 delete-load-balancer --load-balancer-arn "$LB" --region "$REGION"
done

# ─────────────────────────────────────────
# ELASTIC LOAD BALANCERS (Classic - ELB)
# ─────────────────────────────────────────
log "--- Deleting Classic Load Balancers ---"

CLASSIC_LBS=$(aws elb describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancerDescriptions[*].LoadBalancerName" \
  --output text)

for LB in $CLASSIC_LBS; do
  log "Deleting classic load balancer: $LB"
  aws elb delete-load-balancer --load-balancer-name "$LB" --region "$REGION"
done

# ─────────────────────────────────────────
# NAT GATEWAYS
# ─────────────────────────────────────────
log "--- Deleting NAT Gateways ---"

NAT_IDS=$(aws ec2 describe-nat-gateways \
  --region "$REGION" \
  --filter "Name=state,Values=available,pending" \
  --query "NatGateways[*].NatGatewayId" \
  --output text)

for NAT in $NAT_IDS; do
  log "Deleting NAT gateway: $NAT"
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT" --region "$REGION"
done

if [ -n "$NAT_IDS" ]; then
  log "Waiting for NAT gateways to delete..."
  sleep 60
fi

# ─────────────────────────────────────────
# ELASTIC IPs
# ─────────────────────────────────────────
log "--- Releasing Elastic IPs ---"

ALLOC_IDS=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --query "Addresses[*].AllocationId" \
  --output text)

for ALLOC in $ALLOC_IDS; do
  log "Releasing Elastic IP: $ALLOC"
  aws ec2 release-address --allocation-id "$ALLOC" --region "$REGION"
done

# ─────────────────────────────────────────
# AUTO SCALING GROUPS
# ─────────────────────────────────────────
log "--- Deleting Auto Scaling Groups ---"

ASGS=$(aws autoscaling describe-auto-scaling-groups \
  --region "$REGION" \
  --query "AutoScalingGroups[*].AutoScalingGroupName" \
  --output text)

for ASG in $ASGS; do
  log "Deleting ASG: $ASG"
  aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name "$ASG" \
    --force-delete \
    --region "$REGION"
done

# ─────────────────────────────────────────
# LAUNCH TEMPLATES
# ─────────────────────────────────────────
log "--- Deleting Launch Templates ---"

LT_IDS=$(aws ec2 describe-launch-templates \
  --region "$REGION" \
  --query "LaunchTemplates[*].LaunchTemplateId" \
  --output text)

for LT in $LT_IDS; do
  log "Deleting launch template: $LT"
  aws ec2 delete-launch-template --launch-template-id "$LT" --region "$REGION"
done

# ─────────────────────────────────────────
# EBS VOLUMES (unattached)
# ─────────────────────────────────────────
log "--- Deleting Unattached EBS Volumes ---"

VOL_IDS=$(aws ec2 describe-volumes \
  --region "$REGION" \
  --filters "Name=status,Values=available" \
  --query "Volumes[*].VolumeId" \
  --output text)

for VOL in $VOL_IDS; do
  log "Deleting EBS volume: $VOL"
  aws ec2 delete-volume --volume-id "$VOL" --region "$REGION"
done

# ─────────────────────────────────────────
# EBS SNAPSHOTS (owned by account)
# ─────────────────────────────────────────
log "--- Deleting EBS Snapshots ---"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

SNAP_IDS=$(aws ec2 describe-snapshots \
  --region "$REGION" \
  --owner-ids "$ACCOUNT_ID" \
  --query "Snapshots[*].SnapshotId" \
  --output text)

for SNAP in $SNAP_IDS; do
  log "Deleting snapshot: $SNAP"
  aws ec2 delete-snapshot --snapshot-id "$SNAP" --region "$REGION"
done

# ─────────────────────────────────────────
# S3 BUCKETS
# ─────────────────────────────────────────
log "--- Emptying and Deleting S3 Buckets ---"

BUCKETS=$(aws s3api list-buckets \
  --query "Buckets[*].Name" \
  --output text)

for BUCKET in $BUCKETS; do
  log "Emptying bucket: $BUCKET"
  aws s3 rm "s3://$BUCKET" --recursive
  aws s3api delete-bucket --bucket "$BUCKET" --region "$REGION"
  log "Bucket $BUCKET deleted."
done

# ─────────────────────────────────────────
# LAMBDA FUNCTIONS
# ─────────────────────────────────────────
log "--- Deleting Lambda Functions ---"

FUNCTIONS=$(aws lambda list-functions \
  --region "$REGION" \
  --query "Functions[*].FunctionName" \
  --output text)

for FN in $FUNCTIONS; do
  log "Deleting Lambda function: $FN"
  aws lambda delete-function --function-name "$FN" --region "$REGION"
done

# ─────────────────────────────────────────
# CLOUDFORMATION STACKS
# ─────────────────────────────────────────
log "--- Deleting CloudFormation Stacks ---"

STACKS=$(aws cloudformation list-stacks \
  --region "$REGION" \
  --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE \
  --query "StackSummaries[*].StackName" \
  --output text)

for STACK in $STACKS; do
  log "Deleting CloudFormation stack: $STACK"
  aws cloudformation delete-stack --stack-name "$STACK" --region "$REGION"
done

# ─────────────────────────────────────────
# ECR REPOSITORIES
# ─────────────────────────────────────────
log "--- Deleting ECR Repositories ---"

REPOS=$(aws ecr describe-repositories \
  --region "$REGION" \
  --query "repositories[*].repositoryName" \
  --output text)

for REPO in $REPOS; do
  log "Deleting ECR repository: $REPO"
  aws ecr delete-repository \
    --repository-name "$REPO" \
    --force \
    --region "$REGION"
done

# ─────────────────────────────────────────
# DONE
# ─────────────────────────────────────────
log "========================================"
log "Cleanup Completed Successfully"
log "Log saved to: $LOG_FILE"
log "========================================"
