#!/usr/bin/env bash
# Enable the APIs CraftStream uses (resources.yml `apis`). Safe to re-run.
source "$(dirname "$0")/_common.sh"

step "Enabling APIs in $PROJECT_ID"
# shellcheck disable=SC2046  # one argument per API
gc services enable $(res get apis)

step "Checking the Transcoder API is offered in $REGION"
gc transcoder jobs list --location "$REGION" --limit 1 >/dev/null || {
  echo "Transcoder is not available in $REGION: set REGION=asia-southeast1 in config.env and re-run." >&2; exit 1; }
echo "ok"
