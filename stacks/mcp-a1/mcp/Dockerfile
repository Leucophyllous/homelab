FROM python:3.12-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir mcp==1.27.2 paramiko httpx uvicorn starlette oci
COPY proton-cal /usr/local/bin/proton-cal
COPY server.py .
CMD ["python", "server.py"]
