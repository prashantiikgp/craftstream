#!/usr/bin/env bash
# Build backend/ with Cloud Build and deploy it to Cloud Run (sizing: resources.yml `cloud_run`).
# Re-run to ship a new revision.
source "$(dirname "$0")/_common.sh"
url=$(service_url)
run() { res get "cloud_run.$1"; }
auth=--no-allow-unauthenticated; [[ "$(run allow_unauthenticated)" == "True" ]] && auth=--allow-unauthenticated
# Eventarc signs its tokens for the service's hash URL (status.url), which exists only after the first deploy.
hash_url() { gc run services describe "$SERVICE" --region "$REGION" --format 'value(status.url)' 2>/dev/null; }
audiences() { local h; h=$(hash_url); echo "$url${h:+,$h}"; }

step "Deploying $SERVICE to $REGION ($url)"
env_vars=(
  "CRAFTSTREAM_MODE=gcp" "GCP_PROJECT=$PROJECT_ID" "GCP_REGION=$REGION"
  "UPLOAD_BUCKET=$UPLOAD_BUCKET" "MEDIA_BUCKET=$MEDIA_BUCKET" "TRANSCODE_TOPIC=$TOPIC"
  "INTERNAL_AUDIENCE=$(audiences)" "INTERNAL_INVOKERS=$EVENTS_SA" "CORS_ORIGINS=$WEB_ORIGINS"
)
gc run deploy "$SERVICE" --source "$HERE/../../backend" --region "$REGION" \
  --service-account "$API_SA" "$auth" \
  --set-env-vars "^|^$(IFS="|"; echo "${env_vars[*]}")" \
  --cpu "$(run cpu)" --memory "$(run memory)" --min-instances "$(run min_instances)" \
  --max-instances "$(run max_instances)" --concurrency "$(run concurrency)"

# First deploy: the hash URL is known only now, so add it (a new revision, same image).
want=$(audiences)
have=$(gc run services describe "$SERVICE" --region "$REGION" --format json | python3 -c \
  'import json, sys; env = json.load(sys.stdin)["spec"]["template"]["spec"]["containers"][0].get("env", [])
print(next((e.get("value", "") for e in env if e["name"] == "INTERNAL_AUDIENCE"), ""))')
if [[ "$have" != *"$want"* ]]; then
  step "Adding the hash URL to INTERNAL_AUDIENCE"
  gc run services update "$SERVICE" --region "$REGION" --update-env-vars "^|^INTERNAL_AUDIENCE=$want"
fi

step "Smoke check"
curl -fsS "$url/health" && echo
