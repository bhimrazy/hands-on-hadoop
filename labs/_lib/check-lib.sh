# Helpers for labs/NN-slug/check.sh. Source it, run checks, then call summary:
#   source /labs/_lib/check-lib.sh
#   check_hdfs_exists /input/sample.txt "sample.txt is in HDFS" "run step 2: hdfs dfs -put ..."
#   summary
# Checks never exit early, so every result is printed.

_checks_total=0
_checks_failed=0

# pass DESC
pass() {
  _checks_total=$((_checks_total + 1))
  printf 'PASS  %s\n' "$1"
}

# fail DESC HINT
fail() {
  _checks_total=$((_checks_total + 1))
  _checks_failed=$((_checks_failed + 1))
  printf 'FAIL  %s — hint: %s\n' "$1" "$2"
}

# check_hdfs_exists PATH DESC HINT  (PATH may be a file, a directory or a glob)
check_hdfs_exists() {
  if hdfs dfs -test -e "$1" 2>/dev/null; then
    pass "$2"
  else
    fail "$2" "$3"
  fi
}

# check_hdfs_contains PATH TEXT DESC HINT  (fixed-string match; PATH may be a glob like /out/part-*)
check_hdfs_contains() {
  # grep reads all input (no -q) so hdfs never sees a broken pipe under pipefail.
  if hdfs dfs -cat "$1" 2>/dev/null | grep -F -- "$2" >/dev/null; then
    pass "$3"
  else
    fail "$3" "$4"
  fi
}

# summary: prints the totals and exits 0 only if every check passed.
summary() {
  echo
  if [ "$_checks_total" -eq 0 ]; then
    echo "No checks ran"
    exit 1
  elif [ "$_checks_failed" -eq 0 ]; then
    echo "All $_checks_total checks passed"
    exit 0
  else
    echo "$_checks_failed of $_checks_total checks failed"
    exit 1
  fi
}
