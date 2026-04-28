FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1

# lua5.4 + headers (lupa bridge), luarocks for busted (test runner) and luacheck (linter)
RUN apt-get update && apt-get install -y --no-install-recommends \
    lua5.4 \
    liblua5.4-dev \
    luarocks \
    build-essential \
    && rm -rf /var/lib/apt/lists/* \
    && luarocks install busted \
    && luarocks install luacheck

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["python", "-m", "ingestion.src.main"]
