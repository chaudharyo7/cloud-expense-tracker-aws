FROM python:3.12-slim

WORKDIR /app

RUN groupadd -r appuser && useradd -r -g appuser -d /app -s /sbin/nologin appuser

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8000

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "app.main:app"]
