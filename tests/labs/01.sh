#!/usr/bin/env bash
# profiles:
set -euo pipefail

scratch=$(mktemp -d)
echo "Written on my laptop" > "$scratch/mine.txt"
docker compose cp "$scratch/mine.txt" namenode:/tmp/mine.txt

docker compose exec -T namenode bash -euo pipefail -c '
hdfs dfsadmin -safemode wait
hdfs dfs -mkdir -p /lab01
hdfs dfs -put -f /labs/01-hdfs-basics/data/sample.txt /lab01/
hdfs dfs -cat /lab01/sample.txt
echo "This is a sample file" > /workspace/localfile.txt
echo "A second line, added later" > /workspace/more.txt
hdfs dfs -put -f /workspace/localfile.txt /lab01/
hdfs dfs -appendToFile /workspace/more.txt /lab01/localfile.txt
hdfs dfs -cat /lab01/localfile.txt
hdfs dfs -put -f /tmp/mine.txt /lab01/
hdfs dfs -get -f /lab01/mine.txt /tmp/mine-from-hdfs.txt
seq 1 400000 > /workspace/numbers.txt
hdfs dfs -D dfs.blocksize=1m -put -f /workspace/numbers.txt /lab01/
hdfs dfs -ls -R /lab01
hdfs fsck /lab01/numbers.txt -files -blocks
hdfs dfs -get -f /lab01/sample.txt /workspace/sample-copy.txt
hdfs dfs -du -h /lab01
hdfs dfs -df -h /
reput=$(hdfs dfs -put /labs/01-hdfs-basics/data/sample.txt /lab01/ 2>&1 || true)
if grep -q "File exists" <<<"$reput"; then
  echo "second put failed as expected"
else
  echo "expected File exists error" >&2
  exit 1
fi
'

docker compose cp namenode:/tmp/mine-from-hdfs.txt "$scratch/"
grep -q "Written on my laptop" "$scratch/mine-from-hdfs.txt"

docker compose exec -T namenode bash /labs/01-hdfs-basics/check.sh
