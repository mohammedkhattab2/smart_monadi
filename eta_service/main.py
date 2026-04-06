from math import ceil

from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="smart-monadi-eta-service", version="1.0.0")


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
