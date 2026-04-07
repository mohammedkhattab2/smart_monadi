Param(
  [switch]$WithFunctions
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\.."

Write-Host "Deploying Firestore indexes + rules..." -ForegroundColor Cyan
firebase deploy --only firestore:indexes,firestore:rules

if ($WithFunctions) {
  Write-Host "Deploying Functions..." -ForegroundColor Cyan
  firebase deploy --only functions
}

Write-Host "Deploy complete." -ForegroundColor Green
