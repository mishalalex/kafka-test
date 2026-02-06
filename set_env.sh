#!/bin/bash
# Environment variables for reply_bot.py

export KAFKA_BOOTSTRAP="localhost:9092"
export KAFKA_REQUEST_TOPIC="requests"
export KAFKA_REPLY_TOPIC="replies"
export KAFKA_GROUP_ID="python-rr"
export KAFKA_AUTO_OFFSET_RESET="earliest"
export KAFKA_REPLY_DELAY_SEC="5"

echo "Environment variables set:"
echo "  KAFKA_BOOTSTRAP=$KAFKA_BOOTSTRAP"
echo "  KAFKA_REQUEST_TOPIC=$KAFKA_REQUEST_TOPIC"
echo "  KAFKA_REPLY_TOPIC=$KAFKA_REPLY_TOPIC"
echo "  KAFKA_GROUP_ID=$KAFKA_GROUP_ID"
echo "  KAFKA_AUTO_OFFSET_RESET=$KAFKA_AUTO_OFFSET_RESET"
echo "  KAFKA_REPLY_DELAY_SEC=$KAFKA_REPLY_DELAY_SEC"
