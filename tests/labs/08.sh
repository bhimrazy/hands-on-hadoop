#!/usr/bin/env bash
# profiles: notebook
set -euo pipefail

docker compose exec -T notebook jupyter nbconvert --to notebook --execute \
  --ExecutePreprocessor.timeout=900 --output-dir /tmp --output out-08 \
  /labs/08-iceberg-tables/iceberg-orders.ipynb

docker compose exec -T namenode hdfs dfs -ls -R /user/lab/08/warehouse/shop/orders
docker compose exec -T namenode bash /labs/08-iceberg-tables/check.sh
