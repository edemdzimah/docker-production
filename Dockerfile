# STAGE 1: Builder — the messy workshop
FROM python:3.11-slim AS builder

WORKDIR /app

COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt


# STAGE 2: Runtime — the clean living room
FROM python:3.11-slim AS runtime

WORKDIR /app

COPY --from=builder /opt/venv /opt/venv

COPY app.py .

RUN adduser --disabled-password --gecos "" appuser && \
    chown -R appuser /app
USER appuser

ENV PATH=/opt/venv/bin:$PATH

EXPOSE 5000

CMD ["python", "app.py"]