#!/usr/bin/env bash
# Wire the pipeline: GCS upload finalized -> Eventarc -> API; Transcoder result -> Pub/Sub push -> API.
# Run after 05_deploy.sh (the service must exist). Safe to re-run.
# Names, paths, the event type and the retry policy come from resources.yml `eventarc` and `pubsub`.
source "$(dirname "$0")/_common.sh"
url=$(service_url)
UPLOAD_PATH=$(res get eventarc.path)
PUSH_PATH=$(res get pubsub.subscription.push_path)
sub() { res get "pubsub.subscription.$1"; }

step "Eventarc trigger $TRIGGER: gs://$UPLOAD_BUCKET finalized -> $UPLOAD_PATH"
gc eventarc triggers describe "$TRIGGER" --location "$REGION" >/dev/null 2>&1 || \
  gc eventarc triggers create "$TRIGGER" --location "$REGION" \
    --destination-run-service "$SERVICE" --destination-run-region "$REGION" \
    --destination-run-path "$UPLOAD_PATH" \
    --event-filters type="$(res get eventarc.event_type)" \
    --event-filters bucket="$(res get "buckets.$(res get eventarc.bucket).name")" \
    --service-account "$EVENTS_SA"

step "Pub/Sub push $SUBSCRIPTION: $TOPIC -> $PUSH_PATH (OIDC as $EVENTS_SA)"
if gc pubsub subscriptions describe "$SUBSCRIPTION" >/dev/null 2>&1; then
  gc pubsub subscriptions update "$SUBSCRIPTION" --push-endpoint "$url$PUSH_PATH" \
    --push-auth-service-account "$EVENTS_SA" --push-auth-token-audience "$url"
else
  gc pubsub subscriptions create "$SUBSCRIPTION" --topic "$TOPIC" \
    --push-endpoint "$url$PUSH_PATH" \
    --push-auth-service-account "$EVENTS_SA" --push-auth-token-audience "$url" \
    --ack-deadline "$(sub ack_deadline_seconds)" --min-retry-delay "$(sub min_retry_delay)" \
    --max-retry-delay "$(sub max_retry_delay)"
fi
