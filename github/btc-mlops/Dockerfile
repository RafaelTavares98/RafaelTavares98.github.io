FROM python:3.12-slim

WORKDIR /app

# Install first, copy after, so a code change does not rebuild the layer.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY src/ src/
COPY pyproject.toml .
ENV PYTHONPATH=/app/src
ENV MLFLOW_TRACKING_URI=sqlite:////app/mlflow.db

EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import httpx; httpx.get('http://localhost:8000/health').raise_for_status()"

CMD ["uvicorn", "btc.serve.api:app", "--host", "0.0.0.0", "--port", "8000"]
