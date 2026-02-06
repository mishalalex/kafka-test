#!/usr/bin/env bash

set -euo pipefail

# Minimal helper to send a Kafka reply with the same key and partition.
# Defaults: bootstrap=localhost:9092, request topic=requests, reply topic=replies, delay=2s, value={"status":"ok"}
#
# Usage:
#  - With a known corrId:  scripts/kafka_rr_reply_simple.sh <corrId> [delaySeconds]
#  - Capture next request key: scripts/kafka_rr_reply_simple.sh [delaySeconds]

BOOTSTRAP=${KAFKA_BOOTSTRAP:-localhost:9092}
REQUEST_TOPIC=${REQUEST_TOPIC:-requests}
REPLY_TOPIC=${REPLY_TOPIC:-replies}
PARTITION=${PARTITION:-}
DEFAULT_DELAY=${DELAY:-20}
VALUE=${VALUE:-'{"status":"ok"}'}

if ! command -v kcat >/dev/null 2>&1; then
  echo "Error: kcat (kafkacat) is not installed or not in PATH" >&2
  exit 1
fi

corrId=""
partition="${PARTITION}"
delay="$DEFAULT_DELAY"

if [[ $# -ge 1 ]]; then
  if [[ $# -ge 2 ]]; then
    corrId="$1"
    delay="$2"
  else
    # Single arg can be either corrId or delay; if it's a number, treat as delay
    if [[ "$1" =~ ^[0-9]+$ ]]; then
      delay="$1"
    else
      corrId="$1"
    fi
  fi
fi

if [[ -z "$corrId" ]]; then
  echo "Waiting for next request on '$REQUEST_TOPIC' to capture key and partition..."
  line=$(kcat -b "$BOOTSTRAP" -t "$REQUEST_TOPIC" -C -o end -c 1 -q -f '%p|%k\n')
  partition="${line%%|*}"
  corrId="${line#*|}"
  if [[ -z "$corrId" ]]; then
    echo "Error: failed to capture key from '$REQUEST_TOPIC'" >&2
    exit 1
  fi
  echo "Captured corrId: $corrId (partition: ${partition})"
fi

echo "Sleeping ${delay}s before replying..."
sleep "$delay"

echo "Replying on '$REPLY_TOPIC' with key '$corrId'${partition:+, partition $partition}"
if [[ -n "$partition" ]]; then
  printf '%s::%s\n' "$corrId" "$VALUE" | kcat -b "$BOOTSTRAP" -t "$REPLY_TOPIC" -p "$partition" -K '::' -P
else
  printf '%s::%s\n' "$corrId" "$VALUE" | kcat -b "$BOOTSTRAP" -t "$REPLY_TOPIC" -K '::' -P
fi
echo "Done."
