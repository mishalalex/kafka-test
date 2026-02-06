
# Kafka Load Tests

This is a demo project for Kafka load testing using the [galax-io/gatling-kafka-plugin](https://github.com/galax-io/gatling-kafka-plugin/releases).

## How it works

This project demonstrates request-reply patterns in Kafka:
- The scenario is set as a Request-Reply scenario, requiring a requestTopic and a replyTopic.
- The test acts as a Producer, generating messages with correlation IDs.
- The test waits for a response by creating a consumer on the replyTopic.
- Messages are matched by checking the correlation IDs of both request and response messages.

## How to run it

```bash
mvn gatling:test -Dgatling.simulationClass=simulations.KafkaRequestReplyJavaSimulation -Dkafka.bootstrap=localhost:9092
```

## Request-Reply Testing with reply_bot.py

This project includes a Python-based reply bot (`reply_bot.py`) for testing Kafka request-reply patterns.

### Prerequisites
- Kafka broker running (Docker or local installation)
- Python 3 with `kafka-python` library: `pip3 install kafka-python`

### Setup and Run

1. **Start Kafka broker** (Docker example):
```bash
docker run -d \
  --name kafka-test \
  -p 9092:9092 \
  -e KAFKA_LISTENERS=PLAINTEXT://0.0.0.0:9092 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  apache/kafka:latest
```

2. **Create topics** (if auto-create is disabled):
```bash
docker exec -it kafka-test kafka-topics --create --topic requests --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
docker exec -it kafka-test kafka-topics --create --topic replies --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1
```

3. **Run the reply bot**:
```bash
# With 5 second delay (for testing consumer timing)
KAFKA_REPLY_DELAY_SEC="5" python3 reply_bot.py

# Or use the environment setup script
source set_env.sh
python3 reply_bot.py
```

4. **Monitor topics** (optional, in separate terminals):
```bash
# Monitor requests
KAFKA_TOPIC=requests python3 monitor_topics.py

# Monitor replies
KAFKA_TOPIC=replies python3 monitor_topics.py
```

5. **Run Gatling test**:
```bash
mvn gatling:test -Dgatling.simulationClass=simulations.KafkaRequestReplyJavaSimulation -Dkafka.bootstrap=localhost:9092
```

### Configuration

Environment variables for `reply_bot.py`:
- `KAFKA_BOOTSTRAP` - Kafka broker address (default: `localhost:9092`)
- `KAFKA_REQUEST_TOPIC` - Topic to consume requests from (default: `requests`)
- `KAFKA_REPLY_TOPIC` - Topic to send replies to (default: `replies`)
- `KAFKA_GROUP_ID` - Consumer group ID (default: `python-rr`)
- `KAFKA_AUTO_OFFSET_RESET` - Offset reset strategy (default: `earliest`)
- `KAFKA_REPLY_DELAY_SEC` - Delay before sending reply in seconds (default: `5`)
