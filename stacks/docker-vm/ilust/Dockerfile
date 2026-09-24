FROM python:3.13-slim
ENV PYTHONUNBUFFERED=1 TZ=Asia/Tokyo
RUN apt-get update && apt-get install -y --no-install-recommends tzdata && rm -rf /var/lib/apt/lists/* && pip install --no-cache-dir gallery-dl==1.32.12
WORKDIR /opt/ilust
CMD ["bash", "-c", "while true; do /opt/ilust/x_likes_download.sh; sleep 1800; done"]
