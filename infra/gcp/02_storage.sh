#!/usr/bin/env bash
# Two buckets: private uploads (raw videos, auto-deleted) and public media (HLS output). Safe to re-run.
source "$(dirname "$0")/_common.sh"
origins=$(printf '"%s",' ${WEB_ORIGINS//,/ }); origins=${origins%,}
tmp=$(mktemp -d)

step "Uploads bucket gs://$UPLOAD_BUCKET (private)"
gc storage buckets describe "gs://$UPLOAD_BUCKET" >/dev/null 2>&1 || \
  gc storage buckets create "gs://$UPLOAD_BUCKET" --location "$REGION" --uniform-bucket-level-access \
    --public-access-prevention
sed "s|__ORIGINS__|$origins|" "$HERE/cors-uploads.json.tmpl" > "$tmp/cors-uploads.json"
cat > "$tmp/lifecycle.json" <<JSON
{"rule": [{"action": {"type": "Delete"}, "condition": {"age": $RAW_RETENTION_DAYS, "matchesPrefix": ["raw/"]}}]}
JSON
gc storage buckets update "gs://$UPLOAD_BUCKET" --cors-file "$tmp/cors-uploads.json" --lifecycle-file "$tmp/lifecycle.json"

step "Media bucket gs://$MEDIA_BUCKET (public read)"
gc storage buckets describe "gs://$MEDIA_BUCKET" >/dev/null 2>&1 || \
  gc storage buckets create "gs://$MEDIA_BUCKET" --location "$REGION" --uniform-bucket-level-access
sed "s|__ORIGINS__|$origins|" "$HERE/cors-media.json.tmpl" > "$tmp/cors-media.json"
gc storage buckets update "gs://$MEDIA_BUCKET" --cors-file "$tmp/cors-media.json"
gc storage buckets add-iam-policy-binding "gs://$MEDIA_BUCKET" --member allUsers --role roles/storage.objectViewer \
  >/dev/null
rm -rf "$tmp"
