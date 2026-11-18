#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

check_hdfs_exists /lab03/out-notes/_SUCCESS "the notes wordcount finished" \
  "run the wordcount job from step 1"

if hdfs dfs -ls -R /app-logs 2>/dev/null | grep -q "application_"; then
  pass "aggregated logs are stored in /app-logs"
else
  fail "aggregated logs are stored in /app-logs" \
    "run the wordcount in step 1 and wait for it to finish; logs are collected when a job ends"
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

if hdfs dfs -ls '/lab03/out-orders-bad/part-*' >/dev/null 2>&1; then
  fail "the failed job wrote no result files" \
    "the orders-bad job should fail; run it with order-mapper.py, not the fixed one"
else
  pass "the failed job wrote no result files"
fi

check_hdfs_contains /lab03/out-orders-fixed/part-00000 "pencil" "the fixed job wrote totals per product" \
  "run the fixed job from step 7"

summary
