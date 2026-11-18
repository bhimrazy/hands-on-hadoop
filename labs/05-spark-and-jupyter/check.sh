#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

B=/user/lab/05
HINT="run every cell of /labs/05-spark-and-jupyter/word-count-with-spark.ipynb"

check_hdfs_exists $B/input/_SUCCESS "input text is in $B/input" "$HINT"
check_hdfs_exists $B/word-counts-parquet/_SUCCESS "word counts were written as Parquet" "$HINT"

if hdfs dfs -ls "$B/word-counts-parquet/*.parquet" >/dev/null 2>&1; then
  pass "Parquet data files exist in $B/word-counts-parquet"
else
  fail "Parquet data files exist in $B/word-counts-parquet" "$HINT"
fi

if hdfs dfs -cat "$B/top-words/*.csv" 2>/dev/null | grep -q '^data,'; then
  pass "top-words CSV lists 'data' as a top word"
else
  fail "top-words CSV lists 'data' as a top word" "$HINT (step 5 writes it)"
fi

summary
