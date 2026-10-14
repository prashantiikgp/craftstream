#!/usr/bin/env bash
# Service accounts and the least permissions each part needs (resources.yml `service_accounts`, `iam`).
# Safe to re-run.
source "$(dirname "$0")/_common.sh"
PROJECT_NUMBER=$(project_number)
export PROJECT_NUMBER   # resources.py fills the Google service agent emails with it

# Google creates these service agents lazily; IAM bindings fail with "does not exist" until they are provisioned.
step "Google service agents"
for key in $(res get service_agents); do
  gc beta services identity create --service "$(res get "service_agents.$key.service")" >/dev/null
done
gc storage service-agent >/dev/null   # also provisions the GCS agent on older projects

step "Service accounts"
for key in $(res get service_accounts); do
  id=$(res get "service_accounts.$key.id")
  gc iam service-accounts describe "$id@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1 || \
    gc iam service-accounts create "$id" --display-name "$(res get "service_accounts.$key.display_name")"
done

step "Project roles"
while read -r project member role; do
  gc projects add-iam-policy-binding "$project" --member "$member" --role "$role" --condition None >/dev/null
done < <(res iam project)

step "Bucket roles (including public read on the media bucket)"
while read -r bucket member role; do
  gc storage buckets add-iam-policy-binding "$bucket" --member "$member" --role "$role" >/dev/null
done < <(res iam buckets)

step "Service account roles (Pub/Sub mints OIDC tokens for push)"
while read -r account member role; do
  gc iam service-accounts add-iam-policy-binding "$account" --member "$member" --role "$role" >/dev/null
done < <(res iam service_accounts)

step "Transcoder results topic: $TOPIC"
gc pubsub topics describe "$TOPIC" >/dev/null 2>&1 || gc pubsub topics create "$TOPIC"
while read -r topic member role; do
  gc pubsub topics add-iam-policy-binding "$topic" --member "$member" --role "$role" >/dev/null
done < <(res iam topics)
