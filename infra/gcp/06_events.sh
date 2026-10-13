#!/usr/bin/env bash
# Wire the pipeline: GCS upload finalized -> Eventarc -> API; Transcoder result -> Pub/Sub push -> API.
# Run after 05_deploy.sh (the service must exist). Safe to re-run.
source "$(dirname "$0")/_common.sh"
url=$(service_url)

step "Eventarc trigger $TRIGGER: gs://$UPLOAD_BUCKET finalized -> /internal/media/uploaded"
gc eventarc triggers describe "$TRIGGER" --location "$REGION" >/dev/null 2>&1 || \
  gc eventarc triggers create "$TRIGGER" --location "$REGION" \
    --destination-run-service "$SERVICE" --destination-run-region "$REGION" \
    --destination-run-path /internal/media/uploaded \
    --event-filters type=google.cloud.storage.object.v1.finalized \
    --event-filters bucket="$UPLOAD_BUCKET" \
    --service-account "$EVENTS_SA"

step "Pub/Sub push $SUBSCRIPTION: $TOPIC -> /internal/media/transcoded (OIDC as $EVENTS_SA)"
if gc pubsub subscriptions describe "$SUBSCRIPTION" >/dev/null 2>&1; then
  gc pubsub subscriptions update "$SUBSCRIPTION" --push-endpoint "$url/internal/media/transcoded" \
    --push-auth-service-account "$EVENTS_SA" --push-auth-token-audience "$url"
else
  gc pubsub subscriptions create "$SUBSCRIPTION" --topic "$TOPIC" \
    --push-endpoint "$url/internal/media/transcoded" \
    --push-auth-service-account "$EVENTS_SA" --push-auth-token-audience "$url" \
    --ack-deadline 30 --min-retry-delay 10s --max-retry-delay 600s
fi
