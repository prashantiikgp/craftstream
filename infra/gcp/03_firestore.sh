#!/usr/bin/env bash
# Firestore (Native mode) + the composite indexes product search needs. Safe to re-run.
source "$(dirname "$0")/_common.sh"

step "Firestore database (default) in $REGION"
gc firestore databases describe --database='(default)' >/dev/null 2>&1 || \
  gc firestore databases create --location "$REGION" --type firestore-native

step "Indexes for products (see backend/app/db/repositories/product_repo.py)"
create_index() {
  gc firestore indexes composite create --collection-group products "$@" --async 2>&1 | grep -v "already exists" || true
}
create_index --field-config field-path=video_status,order=ascending \
             --field-config field-path=created_at,order=descending
create_index --field-config field-path=video_status,order=ascending \
             --field-config field-path=keywords,array-config=contains \
             --field-config field-path=created_at,order=descending
echo "Indexes build in the background: gcloud firestore indexes composite list --project $PROJECT_ID"
