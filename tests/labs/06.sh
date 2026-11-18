#!/usr/bin/env bash
# profiles: notebook
set -euo pipefail

for nb in file-formats small-files; do
  docker compose exec -T notebook jupyter nbconvert --to notebook --execute \
    --ExecutePreprocessor.timeout=900 --output-dir /tmp --output "out-06-$nb" \
    "/labs/06-file-formats-and-small-files/$nb.ipynb"
done

docker compose exec -T namenode hdfs dfs -du -h /user/lab/06/formats
docker compose exec -T namenode hdfs dfs -count /user/lab/06/small/many /user/lab/06/small/one /user/lab/06/small/compacted
docker compose exec -T namenode bash /labs/06-file-formats-and-small-files/check.sh
