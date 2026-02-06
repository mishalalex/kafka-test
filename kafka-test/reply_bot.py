#!/usr/bin/env python3
import json
import os
import time
from datetime import datetime, timezone

from kafka import KafkaConsumer, KafkaProducer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "localhost:9092")
REQUEST_TOPIC = os.getenv("KAFKA_REQUEST_TOPIC", "requests")
REPLY_TOPIC = os.getenv("KAFKA_REPLY_TOPIC", "replies")
GROUP_ID = os.getenv("KAFKA_GROUP_ID", "python-rr")
AUTO_OFFSET_RESET = os.getenv("KAFKA_AUTO_OFFSET_RESET", "earliest")
REPLY_DELAY_SEC = float(os.getenv("KAFKA_REPLY_DELAY_SEC", "5"))

consumer = KafkaConsumer(
    REQUEST_TOPIC,
    bootstrap_servers=BOOTSTRAP,
    group_id=GROUP_ID,
    auto_offset_reset=AUTO_OFFSET_RESET,
    enable_auto_commit=True,
    api_version=(2, 5, 0),
    key_deserializer=lambda k: k.decode("utf-8") if k else None,
    value_deserializer=lambda v: v.decode("utf-8") if v else None,
)

producer = KafkaProducer(
    bootstrap_servers=BOOTSTRAP,
    api_version=(2, 5, 0),
    key_serializer=lambda k: k.encode("utf-8") if k else None,
    value_serializer=lambda v: v.encode("utf-8"),
)

print(f"Listening on {REQUEST_TOPIC}, replying to {REPLY_TOPIC}...")
print(f"Bootstrap: {BOOTSTRAP}, Group: {GROUP_ID}, Offset: {AUTO_OFFSET_RESET}, Delay: {REPLY_DELAY_SEC}s")
print("Waiting for messages...")

for msg in consumer:
    print(f"Received message - Key: {msg.key}, Partition: {msg.partition}, Offset: {msg.offset}")
    key = msg.key
    if REPLY_DELAY_SEC > 0:
        print(f"Waiting {REPLY_DELAY_SEC}s before replying...")
        time.sleep(REPLY_DELAY_SEC)

    now = datetime.now(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
    reply = {
        "id": key,
        "reply": "ok",
        "repliedAt": now,
    }
    producer.send(REPLY_TOPIC, key=key, value=json.dumps(reply))
    producer.flush()
    print(f"Replied to key={key} at {now}")
