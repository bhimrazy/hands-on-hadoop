#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

BASE=/user/lab/09

check_hdfs_exists "$BASE/lines" "Parquet output folder $BASE/lines" "Run the 'Land the raw lines in HDFS' cell in streaming.ipynb."
check_hdfs_exists "$BASE/lines/_spark_metadata" "Sink log $BASE/lines/_spark_metadata" "The streaming query must finish a batch; re-run the Parquet cell."
if hdfs dfs -ls "$BASE/lines/part-*.parquet" >/dev/null 2>&1; then
  pass "Parquet part files exist in $BASE/lines"
else
  fail "Parquet part files exist in $BASE/lines" "Produce some lines into the topic, then re-run the Parquet cell."
fi
check_hdfs_exists "$BASE/checkpoints/lines/offsets" "Checkpoint offsets log" "The query needs checkpointLocation set to $BASE/checkpoints/lines."
check_hdfs_exists "$BASE/checkpoints/lines/commits" "Checkpoint commit log" "A batch is only committed once it has finished; wait for the cell to return."

summary
