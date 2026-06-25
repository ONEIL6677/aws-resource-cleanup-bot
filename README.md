# AWS Cost Optimisation — Automated Resource Cleanup

Automatically deletes all AWS resources every **50 minutes** using a
**GitHub Actions scheduled workflow** — no server, no machine, no AWS compute needed.
Runs entirely on GitHub's free infrastructure.

---

## How It Works

```
GitHub Actions Scheduler (every 50 minutes)
        │
        ▼
  Workflow triggers on GitHub's servers
        │
        ▼
  AWS credentials loaded from GitHub Secrets
        │
        ▼
  cleanup-all-regions.sh runs across all regions
        │
        ▼
  Logs uploaded as workflow artifacts (kept 30 days)
```

---

## What Gets Deleted

| Resource | Details |
|----------|---------|
| EKS Clusters | Node groups deleted first, then the cluster |
| Auto Scaling Groups | Force deleted including all instances |
| EC2 Instances | All running, stopped, pending, and stopping instances |
| Launch Templates | All templates removed |
| RDS Instances | Deleted with no final snapshot |
| Aurora Clusters | Full cluster deletion |
| Load Balancers | ALB, NLB, and Classic ELB |
| NAT Gateways | All available and pending gateways |
| Elastic IPs | All allocated addresses released |
| EBS Volumes | Unattached (available) volumes only |
| EBS Snapshots | All snapshots owned by your account |
| S3 Buckets | Emptied then deleted |
| Lambda Functions | All functions removed |
| CloudFormation Stacks | All completed stacks deleted |
| ECR Repositories | Force deleted including all images |
| VPCs | IGW → Subnets → Route Tables → Security Groups → NACLs → VPC |

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

> Navigate into the project folder first

```bash
cd aws-cleanup
```

> Create the IAM policy from the provided file

```bash
aws iam create-policy \
  --policy-name AWSCleanupPolicy \
  --policy-document file://config/iam-policy.json
```

> Attach the policy to the cleanup user — replace YOUR_ACCOUNT_ID

```bash
aws iam attach-user-policy \
  --user-name aws-cleanup-bot \
  --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/AWSCleanupPolicy
```

> Get your account ID

```bash
aws sts get-caller-identity --query Account --output text
```

> Generate access keys — save the output immediately, it is only shown once

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

### Step 3 — Push the Repo to GitHub

> Initialize git if not already done

```bash
git init
git add .
git commit -m "feat: add AWS cleanup workflow"
```

> Add your GitHub remote and push

```bash
git remote add origin https://github.com/YOUR_USERNAME/aws-cleanup.git
git branch -M main
git push -u origin main
```

---

### Step 4 — Verify the Workflow is Active

> Go to your repository on GitHub and click the **Actions** tab.
> You should see the workflow listed and the first run either queued or completed.

---

## Running Manually

> Trigger the cleanup immediately from the GitHub UI:

```
Actions → AWS Midnight Cleanup → Run workflow → Run workflow
```

> Or trigger via GitHub CLI

```bash
gh workflow run midnight-cleanup.yml
```

> Watch the run live in the terminal

```bash
gh run watch
```

---

## Viewing Logs

After each run, logs are uploaded as workflow artifacts and kept for 30 days.

> Go to: `Actions → AWS Midnight Cleanup → click a run → Artifacts → cleanup-logs`

> Or download via GitHub CLI — list recent runs first

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
    - cron: "*/50 * * * *"   # every 50 minutes
    - cron: "0 0 * * *"      # once daily at midnight UTC
    - cron: "*/30 * * * *"   # every 30 minutes
```

---

## ⚠️ Important Warnings

> **This workflow is destructive and irreversible.**

- Only use this on **dev or sandbox AWS accounts** — never production
- S3 buckets are **permanently deleted** including all objects inside them
- RDS instances are deleted **with no final snapshot** — all data is lost
- EKS clusters are fully torn down including all running workloads
- VPCs are deleted including all networking dependencies
- Always confirm the correct account is targeted before running manually

> Confirm which AWS account will be affected

```bash
aws sts get-caller-identity
```

---

## Cost

| Resource | Cost |
|----------|------|
| GitHub Actions public repo | Free — unlimited minutes |
| GitHub Actions private repo | Free — uses ~2 min per run, well within 2,000 free minutes/month |
| AWS resources created by this workflow | None — it creates nothing |