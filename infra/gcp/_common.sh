# Shared by every infra/gcp script. Idempotent helpers: each step checks before it creates.
# Resource names and settings come from resources.yml (read through resources.py); config.env holds only
# the per-environment values. Dry run first: `python3 resources.py --print` lists every gcloud command.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$HERE/config.env" ]] || { echo "Create $HERE/config.env from config.env.example first." >&2; exit 1; }
# shellcheck disable=SC1091
source "$HERE/config.env"
: "${PROJECT_ID:?}" "${REGION:?}" "${SERVICE:?}" "${WEB_ORIGINS:?}" "${RAW_RETENTION_DAYS:?}"

# The reader needs PyYAML: use the backend venv when it exists.
PY="$HERE/../../backend/.venv/bin/python"; [[ -x "$PY" ]] || PY=python3
res() { "$PY" "$HERE/resources.py" "$@"; }

UPLOAD_BUCKET=$(res get buckets.uploads.name)
MEDIA_BUCKET=$(res get buckets.media.name)
TOPIC=$(res get pubsub.topic)
SUBSCRIPTION=$(res get pubsub.subscription.name)
TRIGGER=$(res get eventarc.trigger)
API_SA=$(res member sa:api); API_SA=${API_SA#serviceAccount:}            # the Cloud Run service runs as this
EVENTS_SA=$(res member sa:events); EVENTS_SA=${EVENTS_SA#serviceAccount:}  # Eventarc + Pub/Sub sign OIDC tokens as this

gc() { gcloud --project "$PROJECT_ID" --quiet "$@"; }
step() { printf '\n== %s\n' "$*"; }
project_number() { gcloud projects describe "$PROJECT_ID" --format='value(projectNumber)'; }
# Cloud Run's deterministic URL: https://<service>-<project number>.<region>.run.app
service_url() { echo "https://${SERVICE}-$(project_number).${REGION}.run.app"; }
