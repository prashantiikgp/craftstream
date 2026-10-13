# Shared by every infra/gcp script. Idempotent helpers: each step checks before it creates.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$HERE/config.env" ]] || { echo "Create $HERE/config.env from config.env.example first." >&2; exit 1; }
# shellcheck disable=SC1091
source "$HERE/config.env"
: "${PROJECT_ID:?}" "${REGION:?}" "${SERVICE:?}" "${WEB_ORIGINS:?}" "${RAW_RETENTION_DAYS:?}"

UPLOAD_BUCKET="${PROJECT_ID}-uploads"
MEDIA_BUCKET="${PROJECT_ID}-media"
TOPIC="transcode-done"
SUBSCRIPTION="transcode-done-push"
TRIGGER="upload-finalized"
API_SA="craftstream-api@${PROJECT_ID}.iam.gserviceaccount.com"        # the Cloud Run service runs as this
EVENTS_SA="craftstream-events@${PROJECT_ID}.iam.gserviceaccount.com"  # Eventarc + Pub/Sub sign OIDC tokens as this

gc() { gcloud --project "$PROJECT_ID" --quiet "$@"; }
step() { printf '\n== %s\n' "$*"; }
project_number() { gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)'; }
# Cloud Run's deterministic URL: https://<service>-<project number>.<region>.run.app
service_url() { echo "https://${SERVICE}-$(project_number).${REGION}.run.app"; }
