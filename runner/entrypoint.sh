#!/bin/bash
set -euo pipefail

echo "========================================"
echo " GitHub Actions Self-Hosted Runner"
echo "========================================"
echo "Runner Host: $(hostname)"
echo "Terraform:   $(terraform version -json | jq -r '.terraform_version')"
echo "Azure CLI:   $(az version --query '\"azure-cli\"' -o tsv)"
echo "========================================"

# Validate required environment variables
for var in GITHUB_PAT REPO_OWNER REPO_NAME; do
  if [ -z "${!var:-}" ]; then
    echo "ERROR: Required environment variable $var is not set."
    exit 1
  fi
done

RUNNER_NAME="aca-runner-$(hostname)"
RUNNER_LABELS="${RUNNER_LABELS:-aca-runner}"
REPO_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}"

# Log in to Azure using ACA managed identity (needed for Terraform to access storage + ARM)
if [ -n "${IDENTITY_ENDPOINT:-}" ]; then
  echo "Logging in to Azure with managed identity..."
  az login --identity ${MI_CLIENT_ID:+--username "$MI_CLIENT_ID"} --allow-no-subscriptions -o none
  az account set --subscription "${ARM_SUBSCRIPTION_ID:-$(az account show --query id -o tsv)}"
  echo "Azure login successful: $(az account show --query '{subscription:name, id:id}' -o json)"
else
  echo "WARNING: IDENTITY_ENDPOINT not set — not running on ACA. Skipping az login."
fi

# Cleanup: deregister runner on exit
cleanup() {
  echo "Removing runner registration..."
  ./config.sh remove --token "$RUNNER_TOKEN" 2>/dev/null || true
}
trap cleanup EXIT

# Generate a registration token using the GitHub PAT
echo "Requesting runner registration token..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Bearer ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "201" ]; then
  echo "ERROR: Failed to obtain registration token. HTTP $HTTP_CODE"
  echo "$BODY"
  exit 1
fi

RUNNER_TOKEN=$(echo "$BODY" | jq -r '.token')

if [ -z "$RUNNER_TOKEN" ] || [ "$RUNNER_TOKEN" = "null" ]; then
  echo "ERROR: Registration token is empty. Check GITHUB_PAT permissions (needs 'repo' scope)."
  exit 1
fi

echo "Registration token obtained successfully."

# Configure the runner
echo "Configuring runner: $RUNNER_NAME with labels: $RUNNER_LABELS"
./config.sh \
  --url "$REPO_URL" \
  --token "$RUNNER_TOKEN" \
  --labels "$RUNNER_LABELS" \
  --name "$RUNNER_NAME" \
  --work _work \
  --unattended \
  --ephemeral \
  --disableupdate \
  --replace

echo "Runner configured. Starting listener..."

# Run one job then exit (ephemeral mode)
./run.sh
