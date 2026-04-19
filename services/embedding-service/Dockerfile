FROM python:3.11-slim

WORKDIR /app

# System deps for psycopg2 and numpy
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev gcc g++ \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

# Data and model directories are mounted at runtime; create stubs so the
# service starts cleanly even before training.
RUN mkdir -p data/nyc_taxi models

EXPOSE 3010

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "3010"]
