Param(
  [switch]$DryRun,
  [int]$BatchSize = 400
)

$ErrorActionPreference = "Stop"
Set-Location "$PSScriptRoot\.."

if ($BatchSize -lt 1 -or $BatchSize -gt 500) {
  Write-Error "BatchSize must be between 1 and 500"
  exit 1
}

$scriptArgs = @("scripts/migrate_legacy_roles_to_parent.js", "--batch-size=$BatchSize")
if ($DryRun) {
  $scriptArgs += "--dry-run"
}

Write-Host "Running legacy role migration..." -ForegroundColor Cyan
node @scriptArgs
if ($LASTEXITCODE -ne 0) {
  Write-Host "" 
  Write-Host "Migration requires Firebase Admin credentials." -ForegroundColor Yellow
  Write-Host "Option 1 (recommended):" -ForegroundColor Yellow
  Write-Host "  gcloud auth application-default login" -ForegroundColor Gray
  Write-Host "Option 2 (service account):" -ForegroundColor Yellow
  Write-Host "  `$env:GOOGLE_APPLICATION_CREDENTIALS='C:\path\service-account.json'" -ForegroundColor Gray
  exit $LASTEXITCODE
}
