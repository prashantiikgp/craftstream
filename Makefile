# Run `make help` to see everything.
VENV     ?= backend/.venv
PY       ?= $(VENV)/bin/python
API_HOST ?= http://localhost:8000

help:            ## Show this list
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/\t/'

setup:           ## Create backend/.venv and install backend + dev dependencies
	python3 -m venv $(VENV) && $(PY) -m pip install -U pip && $(PY) -m pip install -r backend/requirements-dev.txt

gen:             ## Regenerate Python + Dart code from models/*.yml
	$(PY) tools/codegen.py

test:            ## Run all backend tests
	cd backend && .venv/bin/python -m pytest -q

lint:            ## Ruff on backend + tools
	$(PY) -m ruff check backend tools

api:             ## Run the API locally (in-memory, no GCP) on :8000
	cd backend && .venv/bin/python -m uvicorn app.main:app --reload --port 8000

hls:             ## Make a local HLS ladder: make hls SRC=video.mp4
	$(PY) tools/local_hls.py $(SRC) media_out/

flutter-init:    ## One-time: generate Flutter android/web folders and add hls.js
	bash tools/setup_flutter.sh

web:             ## Serve the Flutter web app on :8080 (open it in Windows Chrome)
	cd frontend && flutter run -d web-server --web-port 8080 --dart-define=API_HOST=$(API_HOST)

apk:             ## Build the Android APK (set API_HOST=https://<cloud-run-url> for the real backend)
	cd frontend && flutter build apk --dart-define=API_HOST=$(API_HOST)

.PHONY: help setup gen test lint api hls flutter-init web apk
