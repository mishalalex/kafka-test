#!/usr/bin/env python3
import os
from kafka import KafkaConsumer

BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP", "localhost:9092")
TOPIC = os.getenv("KAFKA_TOPIC", "requests")

consumer = KafkaConsumer(
    TOPIC,
    bootstrap_servers=BOOTSTRAP,
    auto_offset_reset='earliest',
    enable_auto_commit=False,
    api_version=(2, 5, 0),
    key_deserializer=lambda k: k.decode("utf-8") if k else None,
    value_deserializer=lambda v: v.decode("utf-8") if v else None,
)

print(f"Monitoring topic: {TOPIC} on {BOOTSTRAP}")
print("=" * 60)

for msg in consumer:
    print(f"Key: {msg.key}")
    print(f"Value: {msg.value}")
    print(f"Partition: {msg.partition} | Offset: {msg.offset}")
    print("-" * 60)
