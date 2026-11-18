#!/usr/bin/env bash
source /labs/_lib/check-lib.sh

check_hdfs_exists /user/lab/07/sales/sales.csv "sales.csv is in /user/lab/07/sales" \
  "hdfs dfs -put -f /labs/07-sql-with-hive/data/sales.csv /user/lab/07/sales/"
check_hdfs_exists /user/lab/07/customers/customers.csv "customers.csv is in /user/lab/07/customers" \
  "hdfs dfs -put -f /labs/07-sql-with-hive/data/customers.csv /user/lab/07/customers/"

has_files() {
  hdfs dfs -ls -R "$1" 2>/dev/null | grep -q '^-'
}

check_table_files() {
  if has_files "$1"; then
    pass "$2"
  else
    fail "$2" "$3"
  fi
}

check_table_files /user/hive/warehouse/sales_orc "sales_orc has ORC files in the warehouse" \
  "run sql/02-ctas-orc.sql in beeline"
check_table_files /user/hive/warehouse/sales_by_country/country=Nepal \
  "sales_by_country has a country=Nepal partition folder" "run sql/03-partitions.sql in beeline"
check_table_files /user/hive/warehouse/top_products "top_products has files in the warehouse" \
  "run sql/04-group-by-and-join.sql in beeline"

summary
