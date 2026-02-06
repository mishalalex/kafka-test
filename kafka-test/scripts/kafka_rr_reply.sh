#!/usr/bin/env bash

set -euo pipefail

# Helper to publish a Kafka reply after a delay using kcat.
# It can capture the next request key (and try to auto-detect a correlation header)
# and then publish a reply with the same key (and header if detected).
#
# Usage examples:
#  - With known corrId:
#    scripts/kafka_rr_reply.sh --bootstrap localhost:9092 --reply-topic replies --corr-id <id> --delay 3 --value '{"status":"ok"}' --verbose
#  - Capture from request topic:
#    scripts/kafka_rr_reply.sh --bootstrap localhost:9092 --request-topic requests --reply-topic replies --delay 3 --value '{"status":"ok"}' --verbose

BOOTSTRAP=""
REPLY_TOPIC=""
REQUEST_TOPIC=""
DELAY="1"
VALUE='{"status":"ok"}'
CORR_ID=""
KEY_SEP="::"
VERBOSE=0
DRY_RUN=0
KCAT_OPTS=""
declare -a HEADERS

function usage() {
  cat <<USAGE
Usage:
  $0 --bootstrap <host:port> --reply-topic <topic> [--corr-id <id> | --request-topic <topic>] \
     [--delay <seconds>] [--value <json>] [--header name=value]... [--key-sep <sep>] [--kcat-opts '...'] [--verbose] [--dry-run]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bootstrap) BOOTSTRAP="$2"; shift 2;;
    --reply-topic) REPLY_TOPIC="$2"; shift 2;;
    --request-topic) REQUEST_TOPIC="$2"; shift 2;;
    --corr-id) CORR_ID="$2"; shift 2;;
    --delay) DELAY="$2"; shift 2;;
    --value) VALUE="$2"; shift 2;;
    --header) HEADERS+=("$2"); shift 2;;
    --key-sep) KEY_SEP="$2"; shift 2;;
    --kcat-opts) KCAT_OPTS="$2"; shift 2;;
    --verbose) VERBOSE=1; shift;;
    --dry-run) DRY_RUN=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage; exit 1;;
  esac
done

if ! command -v kcat >/dev/null 2>&1; then
  echo "Error: kcat (kafkacat) is not installed or not in PATH" >&2
  exit 1
fi

if [[ -z "$BOOTSTRAP" || -z "$REPLY_TOPIC" ]]; then
  echo "Error: --bootstrap and --reply-topic are required" >&2
  usage
  exit 1
fi

if [[ -z "$CORR_ID" && -z "$REQUEST_TOPIC" ]]; then
  echo "Error: provide --corr-id or --request-topic" >&2
  usage
  exit 1
fi

KEY="$CORR_ID"

if [[ -z "$KEY" ]]; then
  [[ $VERBOSE -eq 1 ]] && echo "Waiting for next request on '$REQUEST_TOPIC' to capture key and headers ..."
  set +e
  LINE=$(kcat -b "$BOOTSTRAP" -t "$REQUEST_TOPIC" -C -o end -c 1 -q -f 'KEY=%k H=%h\n' ${KCAT_OPTS})
  STATUS=$?
  set -e
  if [[ $STATUS -ne 0 || -z "$LINE" ]]; then
    echo "Error: failed to capture message from '$REQUEST_TOPIC'" >&2
    exit 1
  fi
  KEY=$(sed -n 's/^KEY=\(.*\) H=.*/\1/p' <<<"$LINE")
  HDRS=$(sed -n 's/^KEY=.* H=\(.*\)$/\1/p' <<<"$LINE")
  if [[ -z "$KEY" ]]; then
    echo "Error: failed to parse key from captured line: $LINE" >&2
    exit 1
  fi
  [[ $VERBOSE -eq 1 ]] && echo "Captured corrId (key): $KEY" && echo "Captured headers: $HDRS"

  if [[ -n "$HDRS" ]]; then
    IFS=',' read -r -a HDR_PAIRS <<< "$HDRS"
    for pair in "${HDR_PAIRS[@]}"; do
      p=$(echo "$pair" | sed 's/^ *//;s/ *$//')
      name=$(echo "$p" | awk -F'=' '{print $1}')
      value=$(echo "$p" | awk -F'=' '{print substr($0, index($0,$2))}')
      if [[ -n "$name" && -n "$value" ]]; then
        lname=$(echo "$name" | tr '[:upper:]' '[:lower:]')
        if [[ "$lname" == *corr* || "$lname" == *correlation* ]]; then
          [[ $VERBOSE -eq 1 ]] && echo "Auto-detected correlation header: $name=$value"
          HEADERS+=("$name=$value")
          break
        fi
      fi
    done
  fi
fi

[[ $VERBOSE -eq 1 ]] && echo "Sleeping for $DELAY second(s) before replying ..."
sleep "$DELAY"

declare -a KCAT_HEADERS_ARGS
for h in "${HEADERS[@]:-}"; do
  [[ -n "$h" ]] && KCAT_HEADERS_ARGS+=( -H "$h" )
done

[[ $VERBOSE -eq 1 ]] && echo "Publishing reply to '$REPLY_TOPIC' with key '$KEY' value '$VALUE' headers: ${HEADERS[*]:-<none>}"

if [[ $DRY_RUN -eq 1 ]]; then
  echo "DRY RUN: echo '${KEY}${KEY_SEP}${VALUE}' | kcat -b '$BOOTSTRAP' -t '$REPLY_TOPIC' -K '$KEY_SEP' -P ${KCAT_HEADERS_ARGS[*]:-} ${KCAT_OPTS}"
  exit 0
fi

printf '%s%s%s\n' "$KEY" "$KEY_SEP" "$VALUE" | \
  kcat -b "$BOOTSTRAP" -t "$REPLY_TOPIC" -K "$KEY_SEP" -P ${KCAT_HEADERS_ARGS[@]:-} ${KCAT_OPTS}

[[ $VERBOSE -eq 1 ]] && echo "Reply published."

