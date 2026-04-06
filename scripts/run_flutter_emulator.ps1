Param(
  [string]$DirectionsApiKey = "AIzaSyDpOwdvxDkDUlRlWCeHaXI-b2RdCJf62BY",
  [string]$EtaServiceUrl = "http://10.0.2.2:8081"
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\.."
flutter pub get
flutter run --dart-define=ETA_SERVICE_URL=$EtaServiceUrl --dart-define=DIRECTIONS_API_KEY=$DirectionsApiKey
