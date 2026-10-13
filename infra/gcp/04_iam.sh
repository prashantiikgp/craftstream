#!/usr/bin/env bash
# Service accounts and the least permissions each part needs. Safe to re-run.
source "$(dirname "$0")/_common.sh"
num=$(project_number)
TRANSCODER_AGENT="service-${num}@gcp-sa-transcoder.iam.gserviceaccount.com"
PUBSUB_AGENT="service-${num}@gcp-sa-pubsub.iam.gserviceaccount.com"
GCS_AGENT=$(gc storage service-agent)

ensure_sa() { gc iam service-accounts describe "$1@${PROJECT_ID}.iam.gserviceaccount.com" >/dev/null 2>&1 || \
  gc iam service-accounts create "$1" --display-name "$2"; }
project_role() { gc projects add-iam-policy-binding "$PROJECT_ID" --member "$1" --role "$2" --condition None >/dev/null; }
bucket_role() { gc storage buckets add-iam-policy-binding "gs://$1" --member "$2" --role "$3" >/dev/null; }

step "Service accounts"
ensure_sa craftstream-api "CraftStream API (Cloud Run)"
ensure_sa craftstream-events "CraftStream Eventarc + Pub/Sub invoker"
gc beta services identity create --service transcoder.googleapis.com >/dev/null 2>&1 || true

step "API: Firestore, start/read Transcoder jobs, create upload sessions"
project_role "serviceAccount:$API_SA" roles/datastore.user
project_role "serviceAccount:$API_SA" roles/transcoder.admin
bucket_role "$UPLOAD_BUCKET" "serviceAccount:$API_SA" roles/storage.objectCreator

step "Transcoder service agent: read raw uploads, write HLS, publish results"
bucket_role "$UPLOAD_BUCKET" "serviceAccount:$TRANSCODER_AGENT" roles/storage.objectViewer
bucket_role "$MEDIA_BUCKET" "serviceAccount:$TRANSCODER_AGENT" roles/storage.objectAdmin

step "Events SA: receive Eventarc events, invoke Cloud Run"
project_role "serviceAccount:$EVENTS_SA" roles/eventarc.eventReceiver
project_role "serviceAccount:$EVENTS_SA" roles/run.invoker

step "Google agents: GCS publishes events; Pub/Sub mints OIDC tokens for push"
project_role "serviceAccount:$GCS_AGENT" roles/pubsub.publisher
gc iam service-accounts add-iam-policy-binding "$EVENTS_SA" --member "serviceAccount:$PUBSUB_AGENT" \
  --role roles/iam.serviceAccountTokenCreator >/dev/null

step "Transcoder results topic: $TOPIC"
gc pubsub topics describe "$TOPIC" >/dev/null 2>&1 || gc pubsub topics create "$TOPIC"
gc pubsub topics add-iam-policy-binding "$TOPIC" --member "serviceAccount:$TRANSCODER_AGENT" \
  --role roles/pubsub.publisher >/dev/null
