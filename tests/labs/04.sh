#!/usr/bin/env bash
# services: namenode datanode datanode2 datanode3 proxy
# profiles: cluster
set -euo pipefail

nn() { docker compose exec -T namenode "$@"; }

wait_for() {
  local desc=$1 timeout=$2
  shift 2
  local end=$((SECONDS + timeout))
  until "$@"; do
    if [ "$SECONDS" -ge "$end" ]; then
      echo "timed out waiting for: $desc" >&2
      return 1
    fi
    sleep 5
  done
  echo "ok: $desc"
}

report_has() { nn hdfs dfsadmin -report 2>/dev/null | grep -q "$1"; }
fsck_has() { nn hdfs fsck /lab04 2>/dev/null | grep -Eq "$1"; }

nn hdfs dfsadmin -safemode wait
nn hdfs dfs -rm -r -f /lab04
nn hdfs dfs -mkdir -p /lab04
nn bash -c 'seq 1 1000000 > /workspace/big-numbers.txt'
nn hdfs dfs -D dfs.blocksize=1m -D dfs.replication=2 -put /workspace/big-numbers.txt /lab04/
nn hdfs dfs -setrep -w 2 /lab04/big-numbers.txt
# fsck exits non-zero after a HEALTHY report for a single file; the waits below grep the report instead.
nn hdfs fsck /lab04/big-numbers.txt -files -blocks -locations || true
report_has "^Live datanodes (3)"

docker compose stop datanode2
wait_for "datanode2 declared dead" 240 report_has "^Dead datanodes (1)"
wait_for "blocks re-replicated" 180 fsck_has "Under-replicated blocks:[[:space:]]*0"
nn hdfs fsck /lab04 || true

docker compose start datanode2
wait_for "datanode2 live again" 180 report_has "^Live datanodes (3)"
wait_for "extra replicas removed" 180 fsck_has "Over-replicated blocks:[[:space:]]*0"

nn bash /labs/04-replication-and-failure/check.sh
