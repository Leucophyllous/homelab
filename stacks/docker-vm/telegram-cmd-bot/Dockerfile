FROM python:3.13-slim
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client tzdata && rm -rf /var/lib/apt/lists/* && useradd -u 1000 -m bot
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
ENV PYTHONUNBUFFERED=1 TZ=Asia/Tokyo
USER bot
WORKDIR /opt/telegram-cmd-bot
CMD ["python", "-u", "/opt/telegram-cmd-bot/bot.py"]
