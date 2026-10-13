#!/usr/bin/env bash
# Build backend/ with Cloud Build and deploy it to Cloud Run. Re-run to ship a new revision.
source "$(dirname "$0")/_common.sh"
url=$(service_url)

step "Deploying $SERVICE to $REGION ($url)"
env_vars=(
  "CRAFTSTREAM_MODE=gcp" "GCP_PROJECT=$PROJECT_ID" "GCP_REGION=$REGION"
  "UPLOAD_BUCKET=$UPLOAD_BUCKET" "MEDIA_BUCKET=$MEDIA_BUCKET" "TRANSCODE_TOPIC=$TOPIC"
  "INTERNAL_AUDIENCE=$url" "INTERNAL_INVOKERS=$EVENTS_SA" "CORS_ORIGINS=$WEB_ORIGINS"
)
gc run deploy "$SERVICE" --source "$HERE/../../backend" --region "$REGION" \
  --service-account "$API_SA" --allow-unauthenticated \
  --set-env-vars "^@^$(IFS=@; echo "${env_vars[*]}")" \
  --cpu 1 --memory 512Mi --min-instances 0 --max-instances 3 --concurrency 40

step "Smoke check"
curl -fsS "$url/healthz" && echo
