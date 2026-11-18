#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

check_hdfs_exists /lab04/big-numbers.txt "big-numbers.txt is in /lab04" \
  "hdfs dfs -D dfs.blocksize=1m -D dfs.replication=2 -put /workspace/big-numbers.txt /lab04/"

rep=$(hdfs dfs -stat %r /lab04/big-numbers.txt 2>/dev/null || echo 0)
if [ "$rep" = "2" ]; then
  pass "big-numbers.txt has replication 2"
else
  fail "big-numbers.txt has replication 2 (found $rep)" \
    "hdfs dfs -setrep -w 2 /lab04/big-numbers.txt"
fi

live=$(hdfs dfsadmin -report 2>/dev/null | sed -n 's/^Live datanodes (\([0-9]*\)).*/\1/p')
if [ "${live:-0}" = "3" ]; then
  pass "all 3 DataNodes are live"
else
  fail "all 3 DataNodes are live (found ${live:-0})" \
    "docker compose --profile cluster start datanode2 datanode3"
fi

fsck=$(hdfs fsck /lab04 2>/dev/null)
if echo "$fsck" | grep -q "is HEALTHY" &&
   ! echo "$fsck" | grep -Eq "(Under|Over)-replicated blocks:[[:space:]]*[1-9]"; then
  pass "every block has exactly the replicas it should"
else
  fail "every block has exactly the replicas it should" \
    "wait a minute and run: hdfs fsck /lab04"
fi

summary
