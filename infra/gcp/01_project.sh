#!/usr/bin/env bash
# Enable the APIs CraftStream uses. Safe to re-run.
source "$(dirname "$0")/_common.sh"

step "Enabling APIs in $PROJECT_ID"
gc services enable \
  run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  storage.googleapis.com firestore.googleapis.com transcoder.googleapis.com \
  eventarc.googleapis.com pubsub.googleapis.com iam.googleapis.com

step "Checking the Transcoder API is offered in $REGION"
gc transcoder jobs list --location "$REGION" --limit 1 >/dev/null || {
  echo "Transcoder is not available in $REGION: set REGION=asia-southeast1 in config.env and re-run." >&2; exit 1; }
echo "ok"
