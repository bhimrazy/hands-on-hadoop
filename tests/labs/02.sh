#!/usr/bin/env bash
# profiles:
set -euo pipefail

docker compose exec -T namenode bash -euo pipefail -c '
cd /labs/02-yarn-and-mapreduce
cat data/story.txt | python3 mapper.py | sort | python3 reducer.py | head -3

hdfs dfsadmin -safemode wait
hdfs dfs -mkdir -p /lab02/input
hdfs dfs -put -f data/story.txt /lab02/input/
hdfs dfs -rm -r -f /lab02/out-java /lab02/out-python

hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar \
  wordcount /lab02/input /lab02/out-java

rerun=$(hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar \
  wordcount /lab02/input /lab02/out-java 2>&1 || true)
if grep -q "already exists" <<<"$rerun"; then
  echo "rerun failed as expected"
else
  echo "expected output-exists error" >&2
  exit 1
fi

mapred streaming \
  -files /labs/02-yarn-and-mapreduce/mapper.py,/labs/02-yarn-and-mapreduce/reducer.py \
  -mapper "python3 mapper.py" -reducer "python3 reducer.py" \
  -input /lab02/input -output /lab02/out-python
'

docker compose exec -T namenode bash /labs/02-yarn-and-mapreduce/check.sh
