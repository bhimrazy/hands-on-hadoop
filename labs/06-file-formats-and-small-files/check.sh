#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

B=/user/lab/06

for fmt in csv json parquet orc; do
  check_hdfs_exists $B/formats/$fmt/_SUCCESS "$fmt copy is in $B/formats/$fmt" \
    "run every cell of /labs/06-file-formats-and-small-files/file-formats.ipynb"
done

count_parts() {
  hdfs dfs -ls "$1" 2>/dev/null | grep -c 'part-.*\.parquet$'
}

many=$(count_parts $B/small/many)
if [ "${many:-0}" -ge 400 ]; then
  pass "small/many holds $many tiny files"
else
  fail "small/many holds hundreds of tiny files (found ${many:-0})" \
    "run /labs/06-file-formats-and-small-files/small-files.ipynb"
fi

one=$(count_parts $B/small/one)
if [ "${one:-0}" -eq 1 ]; then
  pass "small/one holds a single file"
else
  fail "small/one holds a single file (found ${one:-0})" "the coalesce(1) write in small-files.ipynb"
fi

compacted=$(count_parts $B/small/compacted)
if [ "${compacted:-0}" -eq 1 ]; then
  pass "small/compacted holds a single file after compaction"
else
  fail "small/compacted holds a single file (found ${compacted:-0})" "run the Compact cell in small-files.ipynb"
fi

summary
