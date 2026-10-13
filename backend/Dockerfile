# Cloud Run image. Build context is backend/:  gcloud run deploy craftstream-api --source backend
FROM python:3.12-slim
WORKDIR /srv
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY config config
COPY app app
ENV CRAFTSTREAM_MODE=gcp PORT=8080
CMD exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT}
