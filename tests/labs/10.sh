#!/usr/bin/env bash
# profiles:
set -euo pipefail

JAR=/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar
OVERRIDE=labs/10-tuning-yarn/compose.override-example.yaml
nn() { docker compose exec -T namenode "$@"; }

nn bash -c '
  hdfs dfs -rm -r -f -skipTrash /user/lab/10 >/dev/null
  hdfs dfs -mkdir -p /user/lab/10/input
  for i in 1 2 3 4 5 6; do
    echo "hadoop yarn container $i hadoop memory" | hdfs dfs -put - /user/lab/10/input/file-$i.txt
  done
'

nn curl -sf http://yarn.localhost/ws/v1/cluster/metrics | jq -e '.clusterMetrics.totalMB == 768'

# The AM is bigger than yarn.scheduler.maximum-allocation-mb (768), so the submit must fail.
toobig=$(nn hadoop jar "$JAR" wordcount -Dyarn.app.mapreduce.am.resource.mb=1024 \
  /user/lab/10/input /user/lab/10/out-toobig 2>&1 || true)
echo "$toobig" | tail -n 5
grep -qi "maximum allowed allocation" <<<"$toobig"

nn hadoop jar "$JAR" wordcount /user/lab/10/input /user/lab/10/out-baseline
nn hadoop jar "$JAR" wordcount \
  -Dmapreduce.map.memory.mb=128 -Dmapreduce.map.java.opts=-Xmx100m \
  -Dmapreduce.reduce.memory.mb=128 -Dmapreduce.reduce.java.opts=-Xmx100m \
  -Dmapreduce.task.io.sort.mb=32 \
  /user/lab/10/input /user/lab/10/out-tuned

docker compose -f compose.yaml -f "$OVERRIDE" up -d --no-deps --force-recreate resourcemanager
for _ in $(seq 1 60); do
  if nn curl -sf http://yarn.localhost/ws/v1/cluster/metrics | jq -e '.clusterMetrics.activeNodes == 1' >/dev/null 2>&1; then
    break
  fi
  sleep 5
done
nn curl -sf http://yarn.localhost/ws/v1/cluster/metrics | jq -e '.clusterMetrics.activeNodes == 1'

nn yarn queue -status batch
nn hadoop jar "$JAR" wordcount -Dmapreduce.job.queuename=batch \
  /user/lab/10/input /user/lab/10/out-queue

nn bash /labs/10-tuning-yarn/check.sh
