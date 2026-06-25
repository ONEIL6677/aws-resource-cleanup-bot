# AWS Cost Optimisation — GitHub Actions Midnight Cleanup

Automatically deletes all AWS resources every day at **midnight (00:00 UTC)**
using a **GitHub Actions scheduled workflow** — no server, no cron machine,
no AWS compute needed. Runs entirely on GitHub's free infrastructure.

---

## How It Works

```
GitHub Actions Scheduler (00:00 UTC daily)
        │
        ▼
  Workflow triggers on GitHub's servers
        │
        ▼
  AWS credentials loaded from GitHub Secrets
        │
        ▼
  cleanup-all-regions.sh runs across 8 regions
        │
        ▼
  Logs uploaded as workflow artifacts (kept 30 days)
```

---

## What Gets Deleted

| Resource | Details |
|----------|---------|
| EC2 Instances | All running, stopped, and pending instances |
| EKS Clusters | Node groups deleted first, then the cluster |
| RDS Instances | Deleted with no final snapshot |
| Aurora Clusters | Full cluster deletion |
| Load Balancers | ALB, NLB, and Classic ELB |
| NAT Gateways | All available and pending gateways |
| Elastic IPs | All allocated addresses released |
| Auto Scaling Groups | Force deleted including all instances |
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
├── .github/
│   └── workflows/
│       └── midnight-cleanup.yml    # GitHub Actions workflow — the scheduler
├── scripts/
│   ├── cleanup.sh                  # Cleans one region
│   └── cleanup-all-regions.sh     # Loops through all regions
├── config/
│   └── iam-policy.json            # IAM policy for the cleanup user
└── README.md
```

---

## Setup

### Step 1 — Create a Dedicated IAM User

> Create the IAM user for the cleanup bot

```bash
aws iam create-user --user-name aws-cleanup-bot
```

> Create the IAM policy from the provided file — replace YOUR_ACCOUNT_ID

```bash
aws iam create-policy \
  --policy-name AWSCleanupPolicy \
  --policy-document file://config/iam-policy.json
```
> run this command to get your account ID
```bash
aws sts get-caller-identity --query Account --output text
```
> Attach the policy to the cleanup user
> replace the account id section with your account id

```bash
aws iam attach-user-policy \
  --user-name aws-cleanup-bot \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSCleanupPolicy
```

> Generate access keys save the output, you'll need it in the next step

```bash
aws iam create-access-key --user-name aws-cleanup-bot
```

---

### Step 2 — Add AWS Credentials to GitHub Secrets

> Never hardcode credentials in the repo. Store them as GitHub Secrets.

Go to your GitHub repository:

```
Settings → Secrets and variables → Actions → New repository secret
```

Add these two secrets:

| Secret Name | Value |
|-------------|-------|
| `AWS_ACCESS_KEY_ID` | Access key from Step 1 |
| `AWS_SECRET_ACCESS_KEY` | Secret key from Step 1 |

---

### Step 3 Push the Repo to GitHub

> Initialize git if not already done

```bash
git init
git add .
git commit -m "feat: add AWS midnight cleanup workflow"
```

> Add your GitHub remote and push

```bash
git remote add origin https://github.com/YOUR_USERNAME/aws-cleanup.git
git branch -M main
git push -u origin main
```

### Step 4 Verify the Workflow is Registered

> Go to your repository on GitHub and click the **Actions** tab.
> You should see **AWS Midnight Cleanup** listed as a workflow.

---

## Running Manually

You can trigger the cleanup at any time without waiting for midnight.

> Go to: `Actions → AWS Midnight Cleanup → Run workflow → Run workflow`

Or trigger it via CLI:

> Trigger the workflow manually using the GitHub CLI

```bash
gh workflow run midnight-cleanup.yml
```

> Watch the run live in the terminal

```bash
gh run watch
```

---

## Viewing Logs

After each run, logs are uploaded as **workflow artifacts** and kept for 30 days.

> Go to: `Actions → AWS Midnight Cleanup → click a run → Artifacts → cleanup-logs`

Or download via CLI:

> List recent workflow runs

```bash
gh run list --workflow=midnight-cleanup.yml
```

> Download logs from a specific run — replace RUN_ID

```bash
gh run download RUN_ID
```

---

## Changing the Schedule

> Edit `.github/workflows/midnight-cleanup.yml` and update the cron line

```yaml
on:
  schedule:
    - cron: "0 0 * * *"    # midnight UTC every day
    - cron: "0 22 * * *"   # 10 PM UTC every day
    - cron: "0 0 * * 1"    # midnight UTC every Monday only
```

> Cron runs on UTC time. Convert your local timezone:
> UTC+1 midnight = "0 23 * * *" | UTC+2 midnight = "0 22 * * *" | UTC+3 midnight = "0 21 * * *"

---

## Add Tag-Based Protection (Optional)

> To only delete resources tagged as dev or staging — edit the EC2 section in `cleanup.sh`

```bash
INSTANCE_IDS=$(aws ec2 describe-instances \
  --region "$REGION" \
  --filters \
    "Name=instance-state-name,Values=running,stopped" \
    "Name=tag:Environment,Values=dev,staging,test" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)
```

> Tag your resources so only non-production ones get cleaned up

```bash
aws ec2 create-tags \
  --resources i-1234567890abcdef0 \
  --tags Key=Environment,Value=dev
```

---

## ⚠️ Important Warnings

> **This workflow is destructive and irreversible.**

- Only use this on **dev or sandbox AWS accounts** — never production
- S3 buckets are **permanently deleted** including all objects
- RDS instances are deleted **with no final snapshot** — all data is lost
- EKS clusters are fully torn down including all workloads
- Always confirm `aws sts get-caller-identity` points to the right account before running manually

---

## Cost

| Resource | Cost |
|----------|------|
| GitHub Actions (public repo) | Free — unlimited minutes |
| GitHub Actions (private repo) | Free — ~60–90 min/month used, well within 2,000 free minutes |
| AWS resources created by this bot | None — it creates nothing |
