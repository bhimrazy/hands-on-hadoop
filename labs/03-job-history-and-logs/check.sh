#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

check_hdfs_exists /lab03/out-notes/_SUCCESS "the notes wordcount finished" \
  "run the wordcount job from step 1"

if hdfs dfs -ls -R /app-logs 2>/dev/null | grep -q "application_"; then
  pass "aggregated logs are stored in /app-logs"
else
  fail "aggregated logs are stored in /app-logs" \
    "start the history profile: docker compose --profile history up -d --wait"
fi

if hdfs dfs -ls -R /tmp/hadoop-yarn/staging/history/done 2>/dev/null | grep -q "\.jhist"; then
  pass "the history server has job history files"
else
  fail "the history server has job history files" \
    "wait a minute after a job ends, then check again"
fi

if yarn application -list -appStates ALL 2>/dev/null | grep -q "orders-bad.*FAILED"; then
  pass "the failing job orders-bad ran and failed"
else
  fail "the failing job orders-bad ran and failed" \
    "run the failing job from step 5 with -D mapreduce.job.name=orders-bad"
fi

if hdfs dfs -test -e /lab03/out-orders-bad; then
  fail "the failed job left no output folder" \
    "remove it: hdfs dfs -rm -r /lab03/out-orders-bad"
else
  pass "the failed job left no output folder"
fi

check_hdfs_contains /lab03/out-orders-fixed/part-00000 "pencil" "the fixed job wrote totals per product" \
  "run the fixed job from step 7"

summary
