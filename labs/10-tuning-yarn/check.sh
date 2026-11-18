#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

BASE=/user/lab/10
RM=http://yarn.localhost
curl -sf "$RM/ws/v1/cluster/info" >/dev/null 2>&1 || RM=http://resourcemanager:8088

check_hdfs_exists "$BASE/out-baseline/_SUCCESS" "Baseline job finished (out-baseline)" "Run step 3 (wordcount with the default container sizes)."
check_hdfs_contains "$BASE/out-baseline/part-r-00000" "hadoop" "Baseline wordcount output" "Open the part file; it should list words and counts."
check_hdfs_exists "$BASE/out-tuned/_SUCCESS" "Tuned job finished (out-tuned)" "Run step 5 (wordcount with 128 MB map containers)."
check_hdfs_exists "$BASE/out-queue/_SUCCESS" "Job in the batch queue finished (out-queue)" "Run step 7 with -Dmapreduce.job.queuename=batch."

if curl -sf "$RM/ws/v1/cluster/scheduler" | jq -e '[.. | .queueName? // empty] | index("batch")' >/dev/null 2>&1; then
  pass "Scheduler has a queue named batch"
else
  fail "Scheduler has a queue named batch" "Recreate the resourcemanager with the override file (step 6)."
fi

finished=$(curl -sf "$RM/ws/v1/cluster/apps?queue=batch&states=FINISHED" | jq '.apps.app | length' 2>/dev/null || echo 0)
if [ "${finished:-0}" -ge 1 ] 2>/dev/null; then
  pass "A finished application ran in queue batch"
else
  fail "A finished application ran in queue batch" "Submit with -Dmapreduce.job.queuename=batch before the queue config is reset."
fi

summary
