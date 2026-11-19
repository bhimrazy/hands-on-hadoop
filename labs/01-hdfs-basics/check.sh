#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

check_hdfs_exists /lab01/sample.txt "sample.txt is in /lab01" \
  "hdfs dfs -mkdir -p /lab01 && hdfs dfs -put /labs/01-hdfs-basics/data/sample.txt /lab01/"
check_hdfs_contains /lab01/sample.txt "namenode" "/lab01/sample.txt has the sample text" \
  "put the file again: hdfs dfs -put -f /labs/01-hdfs-basics/data/sample.txt /lab01/"
check_hdfs_contains /lab01/localfile.txt "added later" "localfile.txt has the appended line" \
  "step 4: hdfs dfs -put /workspace/localfile.txt /lab01/, then -appendToFile /workspace/more.txt"
check_hdfs_exists /lab01/numbers.txt "numbers.txt is in /lab01" \
  "hdfs dfs -D dfs.blocksize=1m -put /workspace/numbers.txt /lab01/"

blocks=$(hdfs fsck /lab01/numbers.txt 2>/dev/null |
  sed -n 's/.*Total blocks (validated):[[:space:]]*\([0-9]*\).*/\1/p')
if [ "${blocks:-0}" -ge 2 ]; then
  pass "numbers.txt is split into $blocks blocks"
else
  fail "numbers.txt is split into more than one block" \
    "upload with -D dfs.blocksize=1m (use -f to replace the old copy)"
fi

summary
