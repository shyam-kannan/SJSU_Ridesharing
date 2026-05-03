FROM python:3.10-slim

WORKDIR /app

COPY services/routing-service/requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

COPY services/routing-service ./

EXPOSE 8002

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${ROUTING_SERVICE_PORT:-8002}"]
