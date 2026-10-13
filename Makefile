# Run `make help` to see everything.
PY ?= .venv/bin/python

help:            ## Show this list
	@grep -E '^[a-z-]+:.*##' Makefile | sed 's/:.*##/\t/'

setup:           ## Create the Python venv and install everything
	python3 -m venv .venv && .venv/bin/pip install -U pip && .venv/bin/pip install -r requirements-dev.txt

gen:             ## Regenerate Python + Dart code from specs/*.yaml
	$(PY) tools/codegen.py

test:            ## Run backend + ladder tests
	$(PY) -m pytest -q

api:             ## Run the API locally (in-memory, no GCP) on :8000
	$(PY) -m uvicorn backend.app.main:app --reload --port 8000

hls:             ## Make a local HLS ladder: make hls SRC=video.mp4
	$(PY) -m transcoder.local_hls $(SRC) media_out/

flutter-init:    ## One-time: generate Flutter android/web folders and add hls.js
	bash tools/setup_flutter.sh

web:             ## Run the Flutter app in Chrome
	cd app && flutter run -d chrome --dart-define=API_HOST=http://localhost:8000

.PHONY: help setup gen test api hls flutter-init web
