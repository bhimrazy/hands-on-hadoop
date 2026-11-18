#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

T=/user/lab/08/warehouse/shop/orders
HINT="run every cell of /labs/08-iceberg-tables/iceberg-orders.ipynb"

check_hdfs_exists $T/metadata/version-hint.text "the table has a version-hint.text" "$HINT"

versions=$(hdfs dfs -ls "$T/metadata/*.metadata.json" 2>/dev/null | grep -c 'metadata.json$')
if [ "${versions:-0}" -ge 6 ]; then
  pass "metadata/ holds $versions vN.metadata.json files (one per table change)"
else
  fail "metadata/ holds at least 6 metadata.json files (found ${versions:-0})" "$HINT"
fi

if hdfs dfs -ls "$T/data/*.parquet" >/dev/null 2>&1; then
  pass "data/ holds Parquet files"
else
  fail "data/ holds Parquet files" "$HINT"
fi

if hdfs dfs -cat "$T/metadata/*.metadata.json" 2>/dev/null | grep -q '"name" *: *"coupon"'; then
  pass "the schema in metadata includes the coupon column (schema evolution)"
else
  fail "the schema in metadata includes the coupon column" "run the Schema evolution cells"
fi

summary
