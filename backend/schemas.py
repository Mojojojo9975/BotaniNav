# backend/schemas.py
#
# Pydantic models for request/response validation.
# These match the exact JSON contracts the Flutter frontend expects.

from pydantic import BaseModel


# ── POST /api/v1/navigation/route ─────────────────────────────────────────────

class RouteRequest(BaseModel):
    """Request body for outdoor route calculation."""
    plant_id: str
    user_lat: float
    user_lng: float


class RouteStep(BaseModel):
    """One turn-by-turn instruction inside the route response."""
    instruction: str
    distance_metres: float
    duration_seconds: int


class OutdoorRouteResponse(BaseModel):
    """
    Response from POST /api/v1/navigation/route.

    The Flutter frontend decodes the polyline to draw the route on
    Google Maps, and shows the steps in an expandable bottom sheet.
    """
    mode: str = "outdoor"
    plant_name: str
    distance_metres: float
    duration_seconds: int
    polyline: str                   # Google encoded polyline
    destination_lat: float
    destination_lng: float
    steps: list[RouteStep]


# ── WebSocket navigation state ────────────────────────────────────────────────

class NavigationState(BaseModel):
    """
    Real-time navigation state pushed over WebSocket.

    The Flutter frontend uses this to:
      - Rotate the directional arrow (bearing - compass_heading)
      - Update the hot/cold gauge (hot_cold_score)
      - Show distance in the top banner (distance_metres)
      - Display the hint text (hint)
      - Detect arrival and navigate to the arrival screen (arrived)
    """
    bearing: float                  # 0–360 degrees from north
    distance_metres: float          # straight-line to target
    hot_cold_score: float           # 0.0 (cold) to 1.0 (hot)
    hint: str                       # e.g. "Getting warmer 🌡"
    waypoint_index: int             # current step index
    arrived: bool                   # true → app navigates to arrival screen


# ── POST /api/v1/plants/coordinates ───────────────────────────────────────────

class CoordinateEntry(BaseModel):
    """One entry from the coordinate picker JSON export."""
    taksonin_nro: int
    finnishName: str = ""
    gps_lat: float
    gps_lng: float


class CoordinateImportResponse(BaseModel):
    """Response from the coordinate import endpoint."""
    updated: int
    not_found: list[str]
    total: int


# ── GET /api/v1/plants ────────────────────────────────────────────────────────

class PlantsResponse(BaseModel):
    """Wrapped plant catalogue response."""
    count: int
    plants: list[dict]              # Each is PlantRow.to_api_dict()
