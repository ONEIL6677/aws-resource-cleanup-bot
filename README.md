# AWS Cost Optimisation — Midnight Cleanup

Automatically deletes all running AWS resources every day at **midnight (00:00)**
to prevent unnecessary charges. A cron job runs a shell script that sweeps your
AWS account clean across all major regions.

---

## What Gets Deleted

| Resource | Details |
|----------|---------|
| EC2 Instances | All running, stopped, and pending instances |
| EKS Clusters | Node groups deleted first, then the cluster |
| RDS Instances | Deleted with no final snapshot |
| Aurora Clusters | Full cluster deletion |
| Load Balancers | ALB, NLB, and Classic ELB |
| NAT Gateways | All available/pending gateways |
| Elastic IPs | All allocated addresses released |
| Auto Scaling Groups | Force deleted with all instances |
| Launch Templates | All templates removed |
| EBS Volumes | Unattached (available) volumes only |
| EBS Snapshots | All snapshots owned by your account |
| S3 Buckets | Emptied then deleted |
| Lambda Functions | All functions removed |
| CloudFormation Stacks | All completed stacks deleted |
| ECR Repositories | Force deleted including all images |

---

## Regions Covered

```
us-east-1 / us-east-2 / us-west-1 / us-west-2
eu-west-1 / eu-central-1
ap-southeast-1 / ap-northeast-1
```

> Edit `scripts/cleanup-all-regions.sh` to add or remove regions.

---

## Project Structure

```
aws-cleanup/
├── scripts/
│   ├── cleanup.sh                 # Cleans a single region
│   └── cleanup-all-regions.sh    # Loops through all regions
├── config/
│   └── iam-policy.json           # IAM policy for the cleanup user
├── logs/                         # Auto-created — daily log files land here
├── install-cron.sh               # Installs the midnight cron job
└── README.md
```

---

## Setup

### Step 1 — Create a Dedicated IAM User for Cleanup

> Create the IAM user

```bash
aws iam create-user --user-name aws-cleanup-bot
```

> Create the IAM policy from the provided file

```bash
aws iam create-policy \
  --policy-name AWSCleanupPolicy \
  --policy-document file://config/iam-policy.json
```

> Attach the policy to the user — replace YOUR_ACCOUNT_ID

```bash
aws iam attach-user-policy \
  --user-name aws-cleanup-bot \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSCleanupPolicy
```

> Create access keys for the cleanup user — save the output

```bash
aws iam create-access-key --user-name aws-cleanup-bot
```

---

### Step 2 — Export Credentials

> Export the cleanup bot credentials as environment variables

```bash
export AWS_ACCESS_KEY_ID=<cleanup-bot-access-key-id>
export AWS_SECRET_ACCESS_KEY=<cleanup-bot-secret-access-key>
export AWS_DEFAULT_REGION=us-east-1
```

> Add them permanently to your shell profile

```bash
echo "export AWS_ACCESS_KEY_ID=<your-key>" >> ~/.bashrc
echo "export AWS_SECRET_ACCESS_KEY=<your-secret>" >> ~/.bashrc
echo "export AWS_DEFAULT_REGION=us-east-1" >> ~/.bashrc
source ~/.bashrc
```

---

### Step 3 — Make Scripts Executable

> Grant execute permissions to all scripts

```bash
chmod +x scripts/cleanup.sh
chmod +x scripts/cleanup-all-regions.sh
chmod +x install-cron.sh
```

---

### Step 4 — Test the Cleanup Script (Dry Run First)

> Run cleanup on a single region manually to verify it works before scheduling

```bash
AWS_DEFAULT_REGION=us-east-1 bash scripts/cleanup.sh
```

> Check the log output

```bash
cat logs/cleanup-$(date +%Y-%m-%d).log
```

---

### Step 5 — Install the Midnight Cron Job

> Run the installer — it registers the cron job automatically

```bash
bash install-cron.sh
```

> Verify the cron job was registered

```bash
crontab -l
```

> Expected output:

```
0 0 * * * AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... bash /path/to/cleanup-all-regions.sh >> /path/to/logs/cron.log 2>&1
```

---

## Manual Usage

> Run cleanup across all regions right now

```bash
bash scripts/cleanup-all-regions.sh
```

> Run cleanup on a specific region only

```bash
AWS_DEFAULT_REGION=eu-west-1 bash scripts/cleanup.sh
```

> Watch the cron log live

```bash
tail -f logs/cron.log
```

> View today's cleanup log

```bash
cat logs/cleanup-$(date +%Y-%m-%d).log
```

---

## Cron Job Reference

> View installed cron jobs

```bash
crontab -l
```

> Edit cron jobs manually

```bash
crontab -e
```

> Remove the cleanup cron job

```bash
crontab -l | grep -v "cleanup-all-regions" | crontab -
```

> Change the schedule — edit this line in install-cron.sh

```
0 0 * * *   →  run at 00:00 (midnight) every day
0 22 * * *  →  run at 22:00 (10 PM) every day
0 0 * * 1   →  run at midnight every Monday only
```

---

## Logs

All runs produce two log files in `logs/`:

| File | Contents |
|------|---------|
| `cleanup-YYYY-MM-DD.log` | Per-region detailed log of every deleted resource |
| `master-cleanup-YYYY-MM-DD.log` | High-level log of which regions were processed |
| `cron.log` | Raw output from the cron job runner |

---

## ⚠️ Important Warnings

> **This script is destructive and irreversible.** It is designed to wipe your AWS account clean.

- Do **not** run this in a production account
- Do **not** run this if you have resources you want to keep — it does not filter by tag or name
- Always verify `aws sts get-caller-identity` points to the right account before running
- S3 buckets are **permanently deleted** including all objects inside them
- RDS instances are deleted **with no final snapshot** — all data is lost

> To protect specific resources, add tag-based filtering to `scripts/cleanup.sh` before running.

---

## Add Tag-Based Protection (Optional)

> To skip resources tagged with `Environment=production`, add this filter to the EC2 section in `cleanup.sh`

```bash
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=instance-state-name,Values=running,stopped" \
    "Name=tag:Environment,Values=dev,test,staging" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)
```

> Tag your dev/test resources so only they get cleaned up

```bash
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags Key=Environment,Value=dev
```
