#!/usr/bin/env bash
# Checks this machine is ready for the labs. Run from the repo root: bash scripts/preflight.sh
set -u

problems=0
ok()   { printf '  [ok]    %s\n' "$1"; }
warn() { printf '  [warn]  %s\n' "$1"; [ $# -gt 1 ] && printf '          %s\n' "${@:2}"; return 0; }
bad()  { printf '  [fail]  %s\n' "$1"; [ $# -gt 1 ] && printf '          %s\n' "${@:2}"; problems=$((problems + 1)); }

echo
echo "hands-on-hadoop preflight"
echo

if ! command -v docker >/dev/null 2>&1; then
  bad "Docker is not installed." "Install Docker Desktop (Mac/Windows) or Docker Engine (Linux): https://docs.docker.com/get-started/get-docker/"
  echo
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  bad "Docker is installed but not running." "Start Docker Desktop (or 'sudo systemctl start docker' on Linux), wait for it to be ready, then run this again."
  echo
  exit 1
fi
ok "Docker is running"

compose_version=$(docker compose version --short 2>/dev/null | sed 's/^v//')
if [ -z "$compose_version" ]; then
  bad "Docker Compose v2 is missing ('docker compose' does not work)." "Update Docker Desktop, or install the compose plugin: https://docs.docker.com/compose/install/"
else
  major=${compose_version%%.*}
  rest=${compose_version#*.}
  minor=${rest%%.*}
  if [ "$major" -gt 2 ] 2>/dev/null || { [ "$major" -eq 2 ] && [ "$minor" -ge 20 ]; } 2>/dev/null; then
    ok "Docker Compose $compose_version"
  else
    bad "Docker Compose $compose_version is too old (need 2.20 or newer)." "Update Docker Desktop or the compose plugin."
  fi
fi

mem_bytes=$(docker info --format '{{.MemTotal}}' 2>/dev/null)
if [ -n "$mem_bytes" ] && [ "$mem_bytes" -gt 0 ] 2>/dev/null; then
  # Tenths of a GiB, so plain integer maths works in any shell.
  mem_tenths=$((mem_bytes * 10 / 1073741824))
  mem_gb="$((mem_tenths / 10)).$((mem_tenths % 10)) GB"
  # A "3 GB" setting in Docker Desktop shows up as about 2.8 GiB here.
  if [ "$mem_tenths" -lt 27 ]; then
    bad "Docker has $mem_gb of memory; the labs need about 3 GB." \
      "Docker Desktop: Settings > Resources > Memory, set 3 GB or more, then Apply & restart." \
      "Windows (WSL 2): set memory=3GB under [wsl2] in %UserProfile%\\.wslconfig, then run 'wsl --shutdown'."
  elif [ "$mem_tenths" -lt 38 ]; then
    ok "Docker has $mem_gb of memory"
    warn "That fits the core stack plus ONE add-on at a time (history, cluster, notebook, hive or kafka)." \
      "Stop one add-on before starting the next: docker compose --profile \"*\" down"
  else
    ok "Docker has $mem_gb of memory (enough for the core stack plus two add-ons)"
  fi
else
  warn "Could not read Docker's memory size; make sure Docker has at least 3 GB."
fi

if [ "$(docker info --format '{{.Architecture}}' 2>/dev/null)" = "aarch64" ]; then
  warn "ARM machine: the Hadoop images are amd64-only and run under emulation, so they start slower." \
    "On a Mac, turn on Settings > General > 'Use Rosetta for x86_64/amd64 emulation' in Docker Desktop."
fi

script_dir=$(cd "$(dirname "$0")" && pwd)
own_proxy=$(docker compose --project-directory "$script_dir/.." ps --status running -q proxy 2>/dev/null)
if [ -n "$own_proxy" ]; then
  ok "Port 80 is used by this lab's proxy (the lab is already running)"
elif (exec 3<>/dev/tcp/127.0.0.1/80) 2>/dev/null; then
  bad "Port 80 is already in use by another program." \
    "The lab serves its web UIs on http://*.localhost (port 80). Stop the other web server or container and try again." \
    "To see what holds it: sudo lsof -nP -iTCP:80 -sTCP:LISTEN (Mac/Linux)"
else
  ok "Port 80 is free"
fi

echo
if [ "$problems" -eq 0 ]; then
  echo "Ready. Start the core stack with: docker compose up -d --wait"
  exit 0
else
  echo "Fix the [fail] items above, then run this again."
  exit 1
fi
