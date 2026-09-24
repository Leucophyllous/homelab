FROM python:3.13-slim
ENV PYTHONUNBUFFERED=1 TZ=Asia/Tokyo
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/*
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
WORKDIR /opt/manmaru
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8090"]
