#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Contact Portal (rcportal) — Terraform Runner
#
# Loads credentials from .env and runs terraform. Uses a static admin API key
# (fixed Bearer token) — DATAVERSE_CONTACT_API_KEY — for the admin endpoints.
#
# Usage:
#   bash run.sh plan
#   bash run.sh apply
#   bash run.sh destroy
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE not found. Copy .env.example and fill in values."
  exit 1
fi

set -a
source "$ENV_FILE"
set +a

export TF_VAR_api_url="${DATAVERSE_CONTACT_API_URL}"
export TF_VAR_connection_key="${DATAVERSE_CONTACT_CONNECTION_KEY}"
[[ -n "${SCOPE:-}" ]] && export TF_VAR_scope="${SCOPE}"

# Skip init if dev_overrides are active (provider resolved from local binary).
TF_RC="${APPDATA:-$HOME}/terraform.rc"
TF_RC_UNIX="$HOME/.terraformrc"
if grep -qs "dev_overrides" "$TF_RC" 2>/dev/null || grep -qs "dev_overrides" "$TF_RC_UNIX" 2>/dev/null; then
  echo "  (skipping init — dev_overrides detected)"
else
  echo "▸ Initializing Terraform..."
  terraform -chdir="$SCRIPT_DIR" init -input=false
fi

if [[ $# -eq 0 ]]; then
  echo "Usage: bash run.sh <plan|apply|destroy|...>"
  exit 1
fi

echo ""
echo "▸ terraform $*"
terraform -chdir="$SCRIPT_DIR" "$@" -input=false
