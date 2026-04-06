Param(
  [Parameter(Mandatory = $true)]
  [string]$DirectionsApiKey,
  [string]$EtaPort = "8081"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path "$PSScriptRoot\.."

Write-Host "Starting ETA service in a separate PowerShell window..." -ForegroundColor Cyan
$etaScript = Join-Path $root "scripts\run_eta_service.ps1"
Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$etaScript`"", "-Port", $EtaPort

Start-Sleep -Seconds 2

Write-Host "Starting Flutter app on emulator..." -ForegroundColor Cyan
Set-Location $root
flutter pub get
flutter run --dart-define=ETA_SERVICE_URL=http://10.0.2.2:$EtaPort --dart-define=DIRECTIONS_API_KEY=$DirectionsApiKey
