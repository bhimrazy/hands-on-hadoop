#!/usr/bin/env bash
# profiles: history
set -euo pipefail

docker compose exec -T namenode bash -euo pipefail -c '
cd /labs/03-job-history-and-logs
EX=/opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.2.jar

hdfs dfsadmin -safemode wait
hdfs dfs -rm -r -f /lab03
hdfs dfs -mkdir -p /lab03/notes /lab03/orders
hdfs dfs -put -f data/notes.txt /lab03/notes/
hdfs dfs -put -f data/orders.csv /lab03/orders/

hadoop jar $EX wordcount /lab03/notes /lab03/out-notes

APP=$(yarn application -list -appStates FINISHED 2>/dev/null | awk "/word count/ {print \$1}" | tail -1)
echo "wordcount app: $APP"

for i in $(seq 1 30); do
  yarn logs -applicationId "$APP" 2>/dev/null | grep -c "LogType:syslog" >/dev/null && break
  sleep 5
done
yarn logs -applicationId "$APP" 2>/dev/null | grep -c "LogType:syslog" >/dev/null

if mapred streaming -D mapreduce.job.name=orders-bad -D mapreduce.map.maxattempts=1 \
  -files /labs/03-job-history-and-logs/order-mapper.py,/labs/03-job-history-and-logs/sum-reducer.py \
  -mapper "python3 order-mapper.py" -reducer "python3 sum-reducer.py" \
  -input /lab03/orders -output /lab03/out-orders-bad; then
  echo "orders-bad should have failed" >&2
  exit 1
fi

BAD=$(yarn application -list -appStates ALL 2>/dev/null | awk "\$2==\"orders-bad\" {print \$1}" | tail -1)
echo "failed app: $BAD"

for i in $(seq 1 30); do
  yarn logs -applicationId "$BAD" 2>/dev/null | grep -c "ValueError" >/dev/null && break
  sleep 5
done
yarn logs -applicationId "$BAD" 2>/dev/null | grep "ValueError: could not convert string to float"

mapred streaming -D mapreduce.job.name=orders-fixed \
  -files /labs/03-job-history-and-logs/order-mapper-fixed.py,/labs/03-job-history-and-logs/sum-reducer.py \
  -mapper "python3 order-mapper-fixed.py" -reducer "python3 sum-reducer.py" \
  -input /lab03/orders -output /lab03/out-orders-fixed
hdfs dfs -cat /lab03/out-orders-fixed/part-00000
'

docker compose exec -T namenode curl -fsS http://history.localhost/jobhistory | grep -ci "jobhistory" >/dev/null
docker compose exec -T namenode bash /labs/03-job-history-and-logs/check.sh
