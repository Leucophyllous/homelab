FROM python:3.13-slim
RUN pip install --no-cache-dir aiohttp
WORKDIR /app
COPY app/exporter.py /app/exporter.py
CMD ["python", "/app/exporter.py"]
