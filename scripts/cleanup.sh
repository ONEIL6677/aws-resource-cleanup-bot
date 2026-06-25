#!/bin/bash

set -euo pipefail

LOG_DIR="$(dirname "$0")/../logs"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
LOG_FILE="$LOG_DIR/cleanup-${REGION}-$(date +%Y-%m-%d).log"

mkdir -p "$LOG_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "========================================"
log "AWS Cleanup Started — Region: $REGION"
log "========================================"

# ─────────────────────────────────────────
# EKS CLUSTERS
# ─────────────────────────────────────────
log "--- Deleting EKS Clusters ---"

EKS_CLUSTERS=$(aws eks list-clusters --region "$REGION" --query "clusters[]" --output text 2>/dev/null || echo "")

for CLUSTER in $EKS_CLUSTERS; do
  log "Deleting node groups in cluster: $CLUSTER"
  NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER" --region "$REGION" \
    --query "nodegroups[]" --output text 2>/dev/null || echo "")

  for NG in $NODE_GROUPS; do
    log "Deleting node group: $NG"
    aws eks delete-nodegroup --cluster-name "$CLUSTER" --nodegroup-name "$NG" --region "$REGION"
    aws eks wait nodegroup-deleted --cluster-name "$CLUSTER" --nodegroup-name "$NG" --region "$REGION"
  done

  aws eks delete-cluster --name "$CLUSTER" --region "$REGION"
  aws eks wait cluster-deleted --name "$CLUSTER" --region "$REGION"
  log "EKS cluster $CLUSTER deleted."
done

# ─────────────────────────────────────────
# AUTO SCALING GROUPS
# ─────────────────────────────────────────
log "--- Deleting Auto Scaling Groups ---"

ASGS=$(aws autoscaling describe-auto-scaling-groups \
  --region "$REGION" \
  --query "AutoScalingGroups[*].AutoScalingGroupName" \
  --output text 2>/dev/null || echo "")

for ASG in $ASGS; do
  log "Deleting ASG: $ASG"
  aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name "$ASG" \
    --force-delete \
    --region "$REGION"
done

# ─────────────────────────────────────────
# EC2 INSTANCES
# ─────────────────────────────────────────
log "--- Terminating EC2 Instances ---"

INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters "Name=instance-state-name,Values=running,stopped,stopping,pending" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text 2>/dev/null || echo "")

if [ -n "$INSTANCE_IDS" ]; then
  log "Terminating: $INSTANCE_IDS"
  aws ec2 terminate-instances --region "$REGION" --instance-ids $INSTANCE_IDS
  aws ec2 wait instance-terminated --region "$REGION" --instance-ids $INSTANCE_IDS
  log "EC2 instances terminated."
else
  log "No EC2 instances found."
fi

# ─────────────────────────────────────────
# LAUNCH TEMPLATES
# ─────────────────────────────────────────
log "--- Deleting Launch Templates ---"

LT_IDS=$(aws ec2 describe-launch-templates \
  --region "$REGION" \
  --query "LaunchTemplates[*].LaunchTemplateId" \
  --output text 2>/dev/null || echo "")

for LT in $LT_IDS; do
  log "Deleting launch template: $LT"
  aws ec2 delete-launch-template --launch-template-id "$LT" --region "$REGION"
done

# ─────────────────────────────────────────
# RDS INSTANCES
# ─────────────────────────────────────────
log "--- Deleting RDS Instances ---"

RDS_INSTANCES=$(aws rds describe-db-instances \
  --region "$REGION" \
  --query "DBInstances[*].DBInstanceIdentifier" \
  --output text 2>/dev/null || echo "")

for DB in $RDS_INSTANCES; do
  log "Deleting RDS: $DB"
  aws rds delete-db-instance \
    --db-instance-identifier "$DB" \
    --skip-final-snapshot \
    --delete-automated-backups \
    --region "$REGION"
done

# ─────────────────────────────────────────
# RDS AURORA CLUSTERS
# ─────────────────────────────────────────
log "--- Deleting Aurora Clusters ---"

RDS_CLUSTERS=$(aws rds describe-db-clusters \
  --region "$REGION" \
  --query "DBClusters[*].DBClusterIdentifier" \
  --output text 2>/dev/null || echo "")

for CLUSTER in $RDS_CLUSTERS; do
  log "Deleting Aurora cluster: $CLUSTER"
  aws rds delete-db-cluster \
    --db-cluster-identifier "$CLUSTER" \
    --skip-final-snapshot \
    --region "$REGION"
done

# ─────────────────────────────────────────
# LOAD BALANCERS (ALB/NLB)
# ─────────────────────────────────────────
log "--- Deleting Load Balancers (ALB/NLB) ---"

LB_ARNS=$(aws elbv2 describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancers[*].LoadBalancerArn" \
  --output text 2>/dev/null || echo "")

for LB in $LB_ARNS; do
  log "Deleting load balancer: $LB"
  aws elbv2 delete-load-balancer --load-balancer-arn "$LB" --region "$REGION"
done

# ─────────────────────────────────────────
# CLASSIC LOAD BALANCERS
# ─────────────────────────────────────────
log "--- Deleting Classic Load Balancers ---"

CLASSIC_LBS=$(aws elb describe-load-balancers \
  --region "$REGION" \
  --query "LoadBalancerDescriptions[*].LoadBalancerName" \
  --output text 2>/dev/null || echo "")

for LB in $CLASSIC_LBS; do
  log "Deleting classic ELB: $LB"
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
  --output text 2>/dev/null || echo "")

for NAT in $NAT_IDS; do
  log "Deleting NAT gateway: $NAT"
  aws ec2 delete-nat-gateway --nat-gateway-id "$NAT" --region "$REGION"
done

if [ -n "$NAT_IDS" ]; then
  log "Waiting 60s for NAT gateways to finish deleting..."
  sleep 60
fi

# ─────────────────────────────────────────
# ELASTIC IPs
# ─────────────────────────────────────────
log "--- Releasing Elastic IPs ---"

ALLOC_IDS=$(aws ec2 describe-addresses \
  --region "$REGION" \
  --query "Addresses[*].AllocationId" \
  --output text 2>/dev/null || echo "")

for ALLOC in $ALLOC_IDS; do
  log "Releasing EIP: $ALLOC"
  aws ec2 release-address --allocation-id "$ALLOC" --region "$REGION"
done

# ─────────────────────────────────────────
# EBS VOLUMES (unattached)
# ─────────────────────────────────────────
log "--- Deleting Unattached EBS Volumes ---"

VOL_IDS=$(aws ec2 describe-volumes \
  --region "$REGION" \
  --filters "Name=status,Values=available" \
  --query "Volumes[*].VolumeId" \
  --output text 2>/dev/null || echo "")

for VOL in $VOL_IDS; do
  log "Deleting EBS volume: $VOL"
  aws ec2 delete-volume --volume-id "$VOL" --region "$REGION"
done

# ─────────────────────────────────────────
# EBS SNAPSHOTS
# ─────────────────────────────────────────
log "--- Deleting EBS Snapshots ---"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

SNAP_IDS=$(aws ec2 describe-snapshots \
  --region "$REGION" \
  --owner-ids "$ACCOUNT_ID" \
  --query "Snapshots[*].SnapshotId" \
  --output text 2>/dev/null || echo "")

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
  --output text 2>/dev/null || echo "")

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
  --output text 2>/dev/null || echo "")

for FN in $FUNCTIONS; do
  log "Deleting Lambda: $FN"
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
  --output text 2>/dev/null || echo "")

for STACK in $STACKS; do
  log "Deleting stack: $STACK"
  aws cloudformation delete-stack --stack-name "$STACK" --region "$REGION"
done

# ─────────────────────────────────────────
# ECR REPOSITORIES
# ─────────────────────────────────────────
log "--- Deleting ECR Repositories ---"

REPOS=$(aws ecr describe-repositories \
  --region "$REGION" \
  --query "repositories[*].repositoryName" \
  --output text 2>/dev/null || echo "")

for REPO in $REPOS; do
  log "Deleting ECR repo: $REPO"
  aws ecr delete-repository \
    --repository-name "$REPO" \
    --force \
    --region "$REGION"
done

# ─────────────────────────────────────────
# VPCs
# ─────────────────────────────────────────
log "--- Deleting VPCs ---"

VPC_IDS=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=isDefault,Values=false" \
  --query "Vpcs[*].VpcId" \
  --output text 2>/dev/null || echo "")

for VPC in $VPC_IDS; do
  log "Cleaning up VPC: $VPC"

  IGW_IDS=$(aws ec2 describe-internet-gateways \
    --region "$REGION" \
    --filters "Name=attachment.vpc-id,Values=$VPC" \
    --query "InternetGateways[*].InternetGatewayId" \
    --output text)
  for IGW in $IGW_IDS; do
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW" --vpc-id "$VPC" --region "$REGION"
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW" --region "$REGION"
    log "Deleted IGW: $IGW"
  done

  SUBNET_IDS=$(aws ec2 describe-subnets \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC" \
    --query "Subnets[*].SubnetId" \
    --output text)
  for SUBNET in $SUBNET_IDS; do
    aws ec2 delete-subnet --subnet-id "$SUBNET" --region "$REGION"
    log "Deleted subnet: $SUBNET"
  done

  RT_IDS=$(aws ec2 describe-route-tables \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC" \
    --query "RouteTables[?Associations[?Main==\`false\`]].RouteTableId" \
    --output text)
  for RT in $RT_IDS; do
    aws ec2 delete-route-table --route-table-id "$RT" --region "$REGION"
    log "Deleted route table: $RT"
  done

  SG_IDS=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC" \
    --query "SecurityGroups[?GroupName!='default'].GroupId" \
    --output text)
  for SG in $SG_IDS; do
    aws ec2 delete-security-group --group-id "$SG" --region "$REGION"
    log "Deleted security group: $SG"
  done

  NACL_IDS=$(aws ec2 describe-network-acls \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC" \
    --query "NetworkAcls[?IsDefault==\`false\`].NetworkAclId" \
    --output text)
  for NACL in $NACL_IDS; do
    aws ec2 delete-network-acl --network-acl-id "$NACL" --region "$REGION"
    log "Deleted NACL: $NACL"
  done

  aws ec2 delete-vpc --vpc-id "$VPC" --region "$REGION"
  log "Deleted VPC: $VPC"
done

# ─────────────────────────────────────────
# DONE
# ─────────────────────────────────────────
log "========================================"
log "Cleanup Complete — Region: $REGION"
log "========================================"