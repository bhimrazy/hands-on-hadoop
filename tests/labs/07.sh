#!/usr/bin/env bash
# profiles: hive
set -euo pipefail

JDBC=jdbc:hive2://localhost:10000
SQL_DIR=labs/07-sql-with-hive/sql

# beeline needs a terminal even for -e; `script` provides one on a CI runner.
# Every statement of a file goes through one beeline session, so SET lines apply to what follows.
run_sql() {
  local statements=() args=() cmd stmt
  mapfile -d '' statements < <(python3 -I - "$1" <<'PY'
import sys
lines = [l for l in open(sys.argv[1]) if not l.lstrip().startswith("--")]
for stmt in "".join(lines).split(";"):
    if stmt.strip():
        sys.stdout.write(stmt.strip() + "\0")
PY
  )
  for stmt in "${statements[@]}"; do
    args+=(-e "$stmt")
  done
  cmd=$(printf '%q ' docker compose exec hiveserver2 beeline -u "$JDBC" -n hive "${args[@]}")
  script -qec "$cmd" /dev/null
}

docker compose exec -T namenode bash -euo pipefail -c '
hdfs dfs -mkdir -p /user/lab/07/sales /user/lab/07/customers
hdfs dfs -put -f /labs/07-sql-with-hive/data/sales.csv /user/lab/07/sales/
hdfs dfs -put -f /labs/07-sql-with-hive/data/customers.csv /user/lab/07/customers/
hdfs dfs -chmod -R a+rwx /user/lab
'

for f in 01-external-table 02-ctas-orc 03-partitions 04-group-by-and-join 05-find-the-files; do
  echo "=== $f.sql"
  run_sql "$SQL_DIR/$f.sql"
done

docker compose exec -T namenode hdfs dfs -ls -R /user/hive/warehouse/sales_orc
docker compose exec -T namenode bash /labs/07-sql-with-hive/check.sh
