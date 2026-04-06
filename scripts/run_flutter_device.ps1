Param(
  [string]$DirectionsApiKey = "AIzaSyDpOwdvxDkDUlRlWCeHaXI-b2RdCJf62BY",
  [string]$EtaServiceUrl,
  [string]$DeviceId
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\.."
flutter pub get

if ([string]::IsNullOrWhiteSpace($EtaServiceUrl)) {
  $localIp = Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
      $_.IPAddress -notlike "169.254*" -and
      $_.IPAddress -ne "127.0.0.1" -and
      $_.InterfaceAlias -notmatch "Loopback|vEthernet"
    } |
    Select-Object -First 1 -ExpandProperty IPAddress

  if ([string]::IsNullOrWhiteSpace($localIp)) {
    throw "Could not auto-detect LAN IP. Pass -EtaServiceUrl manually."
  }

  $EtaServiceUrl = "http://$localIp`:8081"
}

if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  flutter run --dart-define=ETA_SERVICE_URL=$EtaServiceUrl --dart-define=DIRECTIONS_API_KEY=$DirectionsApiKey
}
else {
  flutter run -d $DeviceId --dart-define=ETA_SERVICE_URL=$EtaServiceUrl --dart-define=DIRECTIONS_API_KEY=$DirectionsApiKey
}
