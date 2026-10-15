#!/usr/bin/env bash
# Firestore (Native mode) + the composite indexes product search and the activity log need, and the activity log's
# TTL policy (resources.yml `firestore`). Safe to re-run.
source "$(dirname "$0")/_common.sh"
DATABASE=$(res get firestore.database)

step "Firestore database $DATABASE in $REGION"
gc firestore databases describe --database="$DATABASE" >/dev/null 2>&1 || \
  gc firestore databases create --location "$REGION" --type "$(res get firestore.type)"

step "Composite indexes (see backend/app/db/repositories/product_repo.py and log_repo.py)"
while read -r args; do
  # shellcheck disable=SC2086  # $args is a list of flags
  gc firestore indexes composite create $args --async 2>&1 | grep -v "already exists" || true
done < <(res index-args)
echo "Indexes build in the background: gcloud firestore indexes composite list --project $PROJECT_ID"

step "TTL policies (old activity log entries are deleted after keep_days, platform/activity_log.yml)"
while read -r args; do
  [ -n "$args" ] || continue
  # shellcheck disable=SC2086  # $args is a field and a flag
  gc firestore fields ttls update $args --enable-ttl --async
done < <(res ttl-args)
