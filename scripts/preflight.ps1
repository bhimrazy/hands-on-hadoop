# Checks this machine is ready for the labs. Run from the repo root:
#   powershell -ExecutionPolicy Bypass -File scripts\preflight.ps1

$script:problems = 0
function Ok($msg) { Write-Host "  [ok]    $msg" -ForegroundColor Green }
function Warn($msg, [string[]]$more = @()) {
    Write-Host "  [warn]  $msg" -ForegroundColor Yellow
    foreach ($line in $more) { Write-Host "          $line" }
}
function Bad($msg, [string[]]$more = @()) {
    Write-Host "  [fail]  $msg" -ForegroundColor Red
    foreach ($line in $more) { Write-Host "          $line" }
    $script:problems++
}

Write-Host ""
Write-Host "hands-on-hadoop preflight"
Write-Host ""

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Bad "Docker is not installed." @("Install Docker Desktop: https://docs.docker.com/desktop/setup/install/windows-install/")
    Write-Host ""
    exit 1
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Bad "Docker is installed but not running." @("Start Docker Desktop, wait until it says 'Engine running', then run this again.")
    Write-Host ""
    exit 1
}
Ok "Docker is running"

$composeVersion = (docker compose version --short 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $composeVersion) {
    Bad "Docker Compose v2 is missing ('docker compose' does not work)." @("Update Docker Desktop.")
} else {
    $composeVersion = "$composeVersion".Trim().TrimStart('v')
    $parts = $composeVersion.Split('.')
    $major = [int]$parts[0]; $minor = [int]$parts[1]
    if ($major -gt 2 -or ($major -eq 2 -and $minor -ge 20)) {
        Ok "Docker Compose $composeVersion"
    } else {
        Bad "Docker Compose $composeVersion is too old (need 2.20 or newer)." @("Update Docker Desktop.")
    }
}

$memBytes = 0
[long]::TryParse("$(docker info --format '{{.MemTotal}}' 2>$null)".Trim(), [ref]$memBytes) | Out-Null
if ($memBytes -gt 0) {
    $memGb = [math]::Round($memBytes / 1GB, 1)
    # A "3 GB" setting in Docker Desktop shows up as about 2.8 GiB here.
    if ($memGb -lt 2.7) {
        Bad "Docker has $memGb GB of memory; the labs need about 3 GB." @(
            "WSL 2 backend: add these lines to $env:UserProfile\.wslconfig, then run 'wsl --shutdown' and restart Docker Desktop:",
            "    [wsl2]",
            "    memory=3GB",
            "Hyper-V backend: Docker Desktop > Settings > Resources > Memory, set 3 GB or more.")
    } elseif ($memGb -lt 3.8) {
        Ok "Docker has $memGb GB of memory"
        Warn "That fits the core stack plus ONE add-on at a time (history, cluster, notebook, hive or kafka)." @(
            'Stop one add-on before starting the next: docker compose --profile "*" down')
    } else {
        Ok "Docker has $memGb GB of memory (enough for the core stack plus two add-ons)"
    }
} else {
    Warn "Could not read Docker's memory size; make sure Docker has at least 3 GB."
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$ownProxy = (docker compose --project-directory "$repoRoot" ps --status running -q proxy 2>$null)
$listener = Get-NetTCPConnection -LocalPort 80 -State Listen -ErrorAction SilentlyContinue
if ($ownProxy) {
    Ok "Port 80 is used by this lab's proxy (the lab is already running)"
} elseif ($listener) {
    $owner = ($listener | Select-Object -First 1).OwningProcess
    $name = (Get-Process -Id $owner -ErrorAction SilentlyContinue).ProcessName
    Bad "Port 80 is already in use (process: $name, PID $owner)." @(
        "The lab serves its web UIs on http://*.localhost (port 80). Stop that program and try again.",
        "PID 4 ('System') usually means IIS or the World Wide Web Publishing Service: stop it in services.msc.")
} else {
    Ok "Port 80 is free"
}

Write-Host ""
if ($script:problems -eq 0) {
    Write-Host "Ready. Start the core stack with: docker compose up -d --wait"
    exit 0
} else {
    Write-Host "Fix the [fail] items above, then run this again."
    exit 1
}
