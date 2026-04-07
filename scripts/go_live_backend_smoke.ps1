Param(
  [string]$EtaBaseUrl = "http://localhost:8081",
  [switch]$SkipFirebase
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

Write-Host "Running backend smoke checks..." -ForegroundColor Cyan

try {
  $health = Invoke-WebRequest -Uri "$EtaBaseUrl/health" -UseBasicParsing -TimeoutSec 8
  if ($health.StatusCode -eq 200) {
    Write-Ok "ETA /health responded 200"
  }
  else {
    Write-Err "ETA /health returned status $($health.StatusCode)"
    exit 1
  }
} catch {
  Write-Err "ETA /health failed: $($_.Exception.Message)"
  exit 1
}

$predictBody = '{"busLat":30.0444,"busLng":31.2357,"passengerLat":30.05,"passengerLng":31.24,"speedMetersPerSecond":8.33}'
try {
  $predict = Invoke-WebRequest -Method Post -Uri "$EtaBaseUrl/predict" -UseBasicParsing -TimeoutSec 8 -ContentType "application/json" -Body $predictBody
  if ($predict.StatusCode -eq 200 -and $predict.Content -match 'etaMinutes') {
    Write-Ok "ETA /predict responded with etaMinutes"
  }
  else {
    Write-Err "ETA /predict returned unexpected response"
    exit 1
  }
} catch {
  Write-Err "ETA /predict failed: $($_.Exception.Message)"
  exit 1
}

if (-not $SkipFirebase) {
  try {
    firebase functions:list --json | Out-Null
    Write-Ok "Firebase functions:list succeeded"
  } catch {
    Write-Err "firebase functions:list failed"
    exit 1
  }

  try {
    firebase firestore:indexes | Out-Host
    Write-Ok "firebase firestore:indexes succeeded"
  } catch {
    Write-Err "firebase firestore:indexes failed"
    exit 1
  }
} else {
  Write-Warn "Skipped Firebase checks by request"
}

Write-Host "Backend smoke checks passed." -ForegroundColor Cyan
