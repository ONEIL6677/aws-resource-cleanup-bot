# Automated AWS Account Cleanup

This repository automates the removal of all active AWS cloud infrastructure resources daily at **10:00 PM UTC** while ensuring all core **IAM Users remain completely safe and untouched**.

## Architecture Components
1. `nuke-config.yaml`: Sets targets and specifies the global exclusion filter for IAM Users.
2. `scripts/cleanup.sh`: Bash script that provisions the open-source execution binary (`aws-nuke`).
3. `.github/workflows/aws-cleanup.yml`: Automated GitHub engine runner executed on a cron schedule.

## Setup Instructions

### Step 1: Update Configuration Targets
1. Open `nuke-config.yaml`.
2. Locate the line `"123456789012":` and replace it with your **actual 12-digit AWS Account ID**.
3. (Optional) Adjust your targeted `regions:` if you deploy architecture outside `us-east-1` or `us-west-2`.

### Step 2: Configure Github Secrets
To execute destructive calls against your cloud panel safely, you must provide API key credentials to GitHub.
1. Navigate to your GitHub repository dashboard.
2. Click **Settings** -> **Secrets and variables** -> **Actions**.
3. Click **New repository secret** and append the following variables:

| Secret Name | Value Origin |
| ----------- | ------------ |
| `AWS_ACCESS_KEY_ID` | Your Administrator IAM user Access Key ID |
| `AWS_SECRET_ACCESS_KEY` | Your Administrator IAM user Secret Access Key |

### Step 3: Set an AWS Account Alias (Mandatory Requirement)
`aws-nuke` strictly refuses to clean any account unless it has a text alias assigned to it. This design structure prevents users from accidentally deleting default root accounts.
1. Log into your AWS Console interface.
2. Navigate to the **IAM Dashboard**.
3. Under **AWS Account Details**, click **Create** next to "Account Alias".
4. Set any text name you prefer (e.g., `my-sandbox-account`).

## Manual Execution Trigger
If you do not want to wait until 10:00 PM UTC to run the script:
1. Navigate to the **Actions** tab inside your GitHub repository.
2. Click on **Daily AWS Resource Nuke** from the left navigation pane.
3. Select the **Run workflow** dropdown button and click execute.
