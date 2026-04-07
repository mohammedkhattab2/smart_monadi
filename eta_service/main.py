import os
from math import ceil

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv()

app = FastAPI(title="smart-monadi-eta-service", version="1.0.0")

_cors_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "*").split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins or ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

_GOOGLE_DIRECTIONS_API_KEY = os.getenv("GOOGLE_DIRECTIONS_API_KEY", "").strip()
_GOOGLE_DIRECTIONS_BASE_URL = (
    "https://maps.googleapis.com/maps/api/directions/json"
)


class EtaRequest(BaseModel):
    busLat: float = Field(...)
    busLng: float = Field(...)
    passengerLat: float = Field(...)
    passengerLng: float = Field(...)
    speedMetersPerSecond: float = Field(ge=0)


class EtaResponse(BaseModel):
    etaMinutes: int
    distanceMeters: float
    usedSpeedMetersPerSecond: float


def _haversine_meters(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    # Small, dependency-free distance approximation for ETA prediction endpoint.
    from math import radians, sin, cos, sqrt, atan2

    r = 6371000.0
    d_lat = radians(lat2 - lat1)
    d_lon = radians(lon2 - lon1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return r * c


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/directions")
def directions(
    from_lat: float = Query(..., ge=-90, le=90),
    from_lng: float = Query(..., ge=-180, le=180),
    to_lat: float = Query(..., ge=-90, le=90),
    to_lng: float = Query(..., ge=-180, le=180),
) -> dict:
    if not _GOOGLE_DIRECTIONS_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Google Directions API key is not configured on the server.",
        )

    params = {
        "origin": f"{from_lat},{from_lng}",
        "destination": f"{to_lat},{to_lng}",
        "mode": "driving",
        "key": _GOOGLE_DIRECTIONS_API_KEY,
    }

    try:
        with httpx.Client(timeout=8.0) as client:
            response = client.get(_GOOGLE_DIRECTIONS_BASE_URL, params=params)
            response.raise_for_status()
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=504,
            detail="Google Directions request timed out.",
        ) from exc
    except httpx.HTTPStatusError as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                "Google Directions returned HTTP "
                f"{exc.response.status_code}."
            ),
        ) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail="Failed to reach Google Directions API.",
        ) from exc

    payload = response.json()
    if not isinstance(payload, dict):
        raise HTTPException(
            status_code=502,
            detail="Unexpected response format from Google Directions API.",
        )

    status = str(payload.get("status", ""))
    if status not in {"OK", "ZERO_RESULTS"}:
        raise HTTPException(
            status_code=502,
            detail=f"Google Directions error: {status or 'UNKNOWN_ERROR'}",
        )

    return payload


@app.post("/predict", response_model=EtaResponse)
def predict_eta(payload: EtaRequest) -> EtaResponse:
    distance = _haversine_meters(
        payload.busLat,
        payload.busLng,
        payload.passengerLat,
        payload.passengerLng,
    )

    speed = payload.speedMetersPerSecond if payload.speedMetersPerSecond > 0.1 else 8.33
    eta_minutes = max(1, ceil(distance / (speed * 60)))

    return EtaResponse(
        etaMinutes=eta_minutes,
        distanceMeters=distance,
        usedSpeedMetersPerSecond=speed,
    )
