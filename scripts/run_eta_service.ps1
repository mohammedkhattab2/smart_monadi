Param(
  [string]$Port = "8081"
)

$ErrorActionPreference = "Stop"

Set-Location "$PSScriptRoot\..\eta_service"

if (-not (Test-Path ".venv")) {
  python -m venv .venv
}

. .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port $Port
