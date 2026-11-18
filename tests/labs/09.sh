#!/usr/bin/env bash
# profiles: kafka notebook
set -euo pipefail

KAFKA_BIN=/opt/kafka/bin
LAB=labs/09-kafka-streaming

docker compose exec -T kafka "$KAFKA_BIN/kafka-topics.sh" \
  --bootstrap-server kafka:9092 --create --if-not-exists --topic lines --partitions 1 --replication-factor 1

docker compose exec -T kafka "$KAFKA_BIN/kafka-console-producer.sh" \
  --bootstrap-server kafka:9092 --topic lines < "$LAB/sample-lines.txt"

offsets=$(docker compose exec -T kafka "$KAFKA_BIN/kafka-get-offsets.sh" --bootstrap-server kafka:9092 --topic lines | tr -d '\r')
echo "$offsets"
[ "${offsets##*:}" -ge 6 ]

docker compose exec -T notebook jupyter nbconvert --to notebook --execute \
  --ExecutePreprocessor.timeout=600 \
  --output-dir /tmp --output out.ipynb /labs/09-kafka-streaming/streaming.ipynb

docker compose exec -T namenode bash /labs/09-kafka-streaming/check.sh
