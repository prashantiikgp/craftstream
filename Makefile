# Run `make help` to see everything.
VENV     ?= backend/.venv
PY       ?= $(VENV)/bin/python
ENV      ?= dev
# ENV selects frontend/env/$(ENV).json: dev | staging | prod
# MOCK=false runs the dev app against the API at API_HOST (start it with `make api`) instead of in-app mock data
MOCK     ?=
DEFINES   = --dart-define-from-file=env/$(ENV).json $(if $(MOCK),--dart-define=MOCK_DATA=$(MOCK))
FLUTTER  ?= $(HOME)/development/flutter/bin/flutter

help:            ## Show this list
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/\t/'

setup:           ## Create backend/.venv and install backend + dev dependencies
	python3 -m venv $(VENV) && $(PY) -m pip install -U pip && $(PY) -m pip install -r backend/requirements-dev.txt

gen:             ## Regenerate code from models/*.yml + JSON Schemas (and modelines) for every rule YAML, both sides
	$(PY) tools/codegen.py
	$(PY) tools/export_rule_schemas.py
	cd frontend && $(dir $(FLUTTER))dart run tool/export_rule_schemas.dart

test:            ## Run all backend tests
	cd backend && .venv/bin/python -m pytest -q

lint:            ## Ruff on backend + tools + the infra reader
	$(PY) -m ruff check backend tools infra/gcp/resources.py

infra-print:     ## Dry run: print the gcloud commands infra/gcp/setup.sh would run (calls nothing)
	$(PY) infra/gcp/resources.py --print

api:             ## Run the API locally (in-memory, no GCP) on :8000
	cd backend && .venv/bin/python -m uvicorn app.main:app --reload --port 8000

hls:             ## Make a local HLS ladder: make hls SRC=video.mp4
	$(PY) tools/local_hls.py $(SRC) media_out/

flutter-init:    ## One-time: generate Flutter android/web folders and add hls.js
	bash tools/setup_flutter.sh

web:             ## Serve the Flutter web app on :8080 (ENV=dev|staging|prod, MOCK=false for `make api`; open in Windows Chrome)
	cd frontend && $(FLUTTER) run -d web-server --web-port 8080 $(DEFINES)

apk:             ## Build the Android APK (ENV=prod for the deployed backend)
	cd frontend && $(FLUTTER) build apk --release $(DEFINES)

web-build:       ## Build the web app for hosting (ENV=prod)
	cd frontend && $(FLUTTER) build web --release --dart-define-from-file=env/$(ENV).json
	$(PY) tools/web_bundle.py frontend/build/web   # hashed names + one config bundle (see the tool)

flutter-test:    ## Flutter analyze + tests
	cd frontend && $(FLUTTER) analyze && $(FLUTTER) test

flutter-gen:     ## Regenerate Dart schema code (json_serializable)
	cd frontend && $(FLUTTER) pub run build_runner build --delete-conflicting-outputs

.PHONY: help setup gen test lint infra-print api hls flutter-init web apk web-build flutter-test flutter-gen
