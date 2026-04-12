Param(
  [string]$DirectionsApiKey = "",
  [string]$EtaServiceUrl = "http://10.0.2.2:8081",
  [string]$DirectionsBackendUrl = "http://10.0.2.2:8081"
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\.."
flutter pub get

$args = @("--dart-define=ETA_SERVICE_URL=$EtaServiceUrl")
if (-not [string]::IsNullOrWhiteSpace($DirectionsBackendUrl)) {
  $args += "--dart-define=DIRECTIONS_BACKEND_URL=$DirectionsBackendUrl"
}
if (-not [string]::IsNullOrWhiteSpace($DirectionsApiKey)) {
  $args += "--dart-define=DIRECTIONS_API_KEY=$DirectionsApiKey"
}

flutter run @args
