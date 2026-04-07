Param(
  [switch]$SkipTests,
  [string]$EtaHealthUrl = "http://localhost:8081/health"
)

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

function Write-Ok([string]$Text) {
  Write-Host "[OK] $Text" -ForegroundColor Green
}

function Write-Warn([string]$Text) {
  Write-Host "[WARN] $Text" -ForegroundColor Yellow
}

function Write-Err([string]$Text) {
  Write-Host "[ERR] $Text" -ForegroundColor Red
}

Write-Host "Running Smart Monadi precheck..." -ForegroundColor Cyan

try {
  flutter --version | Out-Null
  Write-Ok "Flutter is installed"
} catch {
  Write-Err "Flutter is not available in PATH"
  exit 1
}

try {
  python --version | Out-Null
  Write-Ok "Python is installed"
} catch {
  Write-Err "Python is not available in PATH"
  exit 1
}

try {
  firebase --version | Out-Null
  Write-Ok "Firebase CLI is installed"
} catch {
  Write-Warn "Firebase CLI is not available in PATH"
}

if (-not (Test-Path "firestore.indexes.json")) {
  Write-Err "firestore.indexes.json not found"
  exit 1
}
Write-Ok "firestore.indexes.json exists"

if (-not (Test-Path "firestore.rules")) {
  Write-Err "firestore.rules not found"
  exit 1
}
Write-Ok "firestore.rules exists"

if (-not (Test-Path "functions\index.js")) {
  Write-Err "functions/index.js not found"
  exit 1
}
Write-Ok "functions/index.js exists"

Write-Host "Running flutter pub get..." -ForegroundColor Cyan
flutter pub get | Out-Host

Write-Host "Running flutter analyze..." -ForegroundColor Cyan
flutter analyze | Out-Host

if (-not $SkipTests) {
  Write-Host "Running flutter test..." -ForegroundColor Cyan
  flutter test | Out-Host
} else {
  Write-Warn "Skipped tests by request"
}

try {
  $resp = Invoke-WebRequest -Uri $EtaHealthUrl -UseBasicParsing -TimeoutSec 3
  if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) {
    Write-Ok "ETA service health endpoint reachable: $EtaHealthUrl"
  } else {
    Write-Warn "ETA service returned unexpected status: $($resp.StatusCode)"
  }
} catch {
  Write-Warn "ETA service is not reachable now at $EtaHealthUrl"
}

Write-Host "Precheck finished." -ForegroundColor Cyan
