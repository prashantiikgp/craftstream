#!/usr/bin/env bash
# Everything, in order. Each step is idempotent, so re-running after a failure is safe.
set -euo pipefail
cd "$(dirname "$0")"
for s in 01_project.sh 02_storage.sh 03_firestore.sh 04_iam.sh 05_deploy.sh 06_events.sh; do bash "$s"; done
