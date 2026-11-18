#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

check_hdfs_exists /lab02/input/story.txt "story.txt is in /lab02/input" \
  "hdfs dfs -mkdir -p /lab02/input && hdfs dfs -put /labs/02-yarn-and-mapreduce/data/story.txt /lab02/input/"
check_hdfs_exists /lab02/out-java/_SUCCESS "the Java wordcount finished" \
  "run the wordcount job from step 2"
check_hdfs_contains /lab02/out-java/part-r-00000 "elephant" "Java output counts the word elephant" \
  "look at the job output: hdfs dfs -ls /lab02/out-java"
check_hdfs_exists /lab02/out-python/_SUCCESS "the Python streaming job finished" \
  "run the streaming job from step 5"
check_hdfs_contains /lab02/out-python/part-00000 "elephant" "Python output counts the word elephant" \
  "look at the job output: hdfs dfs -ls /lab02/out-python"

if diff <(hdfs dfs -cat /lab02/out-java/part-r-00000 2>/dev/null) \
        <(hdfs dfs -cat /lab02/out-python/part-00000 2>/dev/null) >/dev/null; then
  pass "Java and Python give the same counts"
else
  fail "Java and Python give the same counts" \
    "diff the two outputs and look for the first differing word"
fi

summary
