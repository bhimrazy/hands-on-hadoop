#!/usr/bin/env bash
# profiles: notebook
set -euo pipefail

docker compose exec -T notebook jupyter nbconvert --to notebook --execute \
  --ExecutePreprocessor.timeout=600 --output-dir /tmp --output out-05 \
  /labs/05-spark-and-jupyter/word-count-with-spark.ipynb

docker compose exec -T namenode hdfs dfs -ls -R /user/lab/05
docker compose exec -T namenode bash /labs/05-spark-and-jupyter/check.sh
