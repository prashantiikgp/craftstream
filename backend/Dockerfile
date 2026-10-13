# Cloud Run image. Build context is backend/:  gcloud run deploy craftstream-api --source backend
FROM python:3.12-slim
WORKDIR /srv
# ffprobe measures each upload before transcoding (app/infra/ffprobe.py).
RUN apt-get update && apt-get install -y --no-install-recommends ffmpeg && rm -rf /var/lib/apt/lists/*
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY config config
COPY app app
ENV CRAFTSTREAM_MODE=gcp PORT=8080
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
