FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends arp-scan tzdata && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
ENV PYTHONUNBUFFERED=1 TZ=Asia/Tokyo
WORKDIR /app
CMD ["python", "/app/bot.py"]
