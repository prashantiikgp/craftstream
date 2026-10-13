# Cloud Run image. Build from the repo root:  docker build -f backend/Dockerfile -t craftstream-api .
FROM python:3.12-slim
WORKDIR /srv
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt
COPY specs specs
COPY transcoder transcoder
COPY backend backend
ENV CRAFTSTREAM_MODE=gcp PORT=8080
CMD exec uvicorn backend.app.main:app --host 0.0.0.0 --port ${PORT}
