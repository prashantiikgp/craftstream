#!/usr/bin/env bash
# Two buckets (resources.yml `buckets`): private uploads (raw videos, auto-deleted) and public media (HLS output).
# Safe to re-run.
source "$(dirname "$0")/_common.sh"
tmp=$(mktemp -d)

step "Uploads bucket gs://$UPLOAD_BUCKET (private)"
gc storage buckets describe "gs://$UPLOAD_BUCKET" >/dev/null 2>&1 || \
  gc storage buckets create "gs://$UPLOAD_BUCKET" --location "$REGION" --uniform-bucket-level-access \
    --public-access-prevention
res cors-json uploads > "$tmp/cors-uploads.json"
res lifecycle-json uploads > "$tmp/lifecycle.json"
gc storage buckets update "gs://$UPLOAD_BUCKET" --cors-file "$tmp/cors-uploads.json" --lifecycle-file "$tmp/lifecycle.json"

step "Media bucket gs://$MEDIA_BUCKET (public read)"
gc storage buckets describe "gs://$MEDIA_BUCKET" >/dev/null 2>&1 || \
  gc storage buckets create "gs://$MEDIA_BUCKET" --location "$REGION" --uniform-bucket-level-access
res cors-json media > "$tmp/cors-media.json"
gc storage buckets update "gs://$MEDIA_BUCKET" --cors-file "$tmp/cors-media.json"
# The public-read binding is in resources.yml iam.buckets (applied by 04_iam.sh).
rm -rf "$tmp"
