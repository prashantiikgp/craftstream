# Run `make help` to see everything.
VENV     ?= backend/.venv
PY       ?= $(VENV)/bin/python
ENV      ?= dev
# ENV selects frontend/env/$(ENV).json: dev | staging | prod
FLUTTER  ?= $(HOME)/development/flutter/bin/flutter

help:            ## Show this list
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/\t/'

setup:           ## Create backend/.venv and install backend + dev dependencies
	python3 -m venv $(VENV) && $(PY) -m pip install -U pip && $(PY) -m pip install -r backend/requirements-dev.txt

gen:             ## Regenerate code from models/*.yml + JSON Schemas for backend/config/*.yml
	$(PY) tools/codegen.py
	$(PY) tools/export_rule_schemas.py

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

web:             ## Serve the Flutter web app on :8080 (ENV=dev|staging|prod; open in Windows Chrome)
	cd frontend && $(FLUTTER) run -d web-server --web-port 8080 --dart-define-from-file=env/$(ENV).json

apk:             ## Build the Android APK (ENV=prod for the deployed backend)
	cd frontend && $(FLUTTER) build apk --release --dart-define-from-file=env/$(ENV).json

web-build:       ## Build the web app for hosting (ENV=prod)
	cd frontend && $(FLUTTER) build web --release --dart-define-from-file=env/$(ENV).json

flutter-test:    ## Flutter analyze + tests
	cd frontend && $(FLUTTER) analyze && $(FLUTTER) test

flutter-gen:     ## Regenerate Dart schema code (json_serializable)
	cd frontend && $(FLUTTER) pub run build_runner build --delete-conflicting-outputs

.PHONY: help setup gen test lint api hls flutter-init web apk web-build flutter-test flutter-gen
