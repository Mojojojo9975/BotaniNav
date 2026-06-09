# backend/routes/navigation.py
#
# Outdoor navigation endpoints:
#   POST /api/v1/navigation/route          → walking route via Google Directions
#   WS   /api/v1/navigation/ws/{session}   → real-time bearing/distance/arrival

import asyncio
import json
import logging

import httpx
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import verify_api_key, verify_ws_api_key
from config import get_settings
from database import get_db, PlantRow
from geo import haversine_metres, bearing_degrees, hot_cold_score, hint_for_score
from schemas import RouteRequest, OutdoorRouteResponse, RouteStep

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/v1/navigation", tags=["navigation"])


# ─────────────────────────────────────────────────────────────────────────────
# In-memory store for user GPS positions.
#
# In production, you'd want Redis or similar. The Flutter app needs to push
# GPS updates somewhere so the WS handler can compute bearing/distance.
#
# Option A: Client POSTs GPS to a separate endpoint (implemented below).
# Option B: Client sends GPS over the same WebSocket (also handled below).
# ─────────────────────────────────────────────────────────────────────────────

_session_positions: dict[str, tuple[float, float]] = {}
_session_targets: dict[str, str] = {}  # session_id → plant taxon_number


# ── POST /api/v1/navigation/route ────────────────────────────────────────────

@router.post("/route", response_model=OutdoorRouteResponse)
async def get_outdoor_route(
    req: RouteRequest,
    _api_key: str = Depends(verify_api_key),
    db: AsyncSession = Depends(get_db),
):
    """
    Calculates a walking route from the user's GPS position to the target plant.

    Calls Google Directions API on the server side and returns:
      - An encoded polyline (drawn on Google Maps in the Flutter app)
      - Turn-by-turn step instructions (shown in the bottom sheet)
      - Total distance and duration
      - Destination coordinates (used to fit the map camera)

    The Flutter frontend calls this once when OutdoorNavigationScreen opens.
    """
    settings = get_settings()

    # Find the target plant
    plant = await db.get(PlantRow, req.plant_id)
    if not plant:
        from fastapi import HTTPException
        raise HTTPException(404, f"Plant '{req.plant_id}' not found")

    if not plant.gps_lat or not plant.gps_lng:
        from fastapi import HTTPException
        raise HTTPException(
            404,
            f"Plant '{req.plant_id}' has no GPS coordinates. "
            "Use the coordinate picker to map it first.",
        )

    # ── Call Google Directions API ────────────────────────────────────────────
    async with httpx.AsyncClient(timeout=10.0) as client:
        resp = await client.get(
            "https://maps.googleapis.com/maps/api/directions/json",
            params={
                "origin": f"{req.user_lat},{req.user_lng}",
                "destination": f"{plant.gps_lat},{plant.gps_lng}",
                "mode": "walking",
                "key": settings.google_maps_api_key,
            },
        )
        resp.raise_for_status()
        data = resp.json()

    if data.get("status") != "OK" or not data.get("routes"):
        from fastapi import HTTPException
        raise HTTPException(
            404,
            f"Google Directions returned no route: {data.get('status', 'UNKNOWN')}",
        )

    route = data["routes"][0]
    leg = route["legs"][0]

    # ── Parse step instructions ──────────────────────────────────────────────
    # Google returns HTML-formatted instructions — strip tags for plain text.
    steps = []
    for step in leg.get("steps", []):
        instruction = step.get("html_instructions", "")
        # Strip common HTML tags
        for tag in ["<b>", "</b>", "<div>", "</div>", '<div style="font-size:0.9em">']:
            instruction = instruction.replace(tag, " ")
        instruction = instruction.strip()

        steps.append(RouteStep(
            instruction=instruction,
            distance_metres=step["distance"]["value"],
            duration_seconds=step["duration"]["value"],
        ))

    return OutdoorRouteResponse(
        mode="outdoor",
        plant_name=plant.finnish_name or plant.name,
        distance_metres=leg["distance"]["value"],
        duration_seconds=leg["duration"]["value"],
        polyline=route["overview_polyline"]["points"],
        destination_lat=plant.gps_lat,
        destination_lng=plant.gps_lng,
        steps=steps,
    )


# ── POST /api/v1/navigation/position ─────────────────────────────────────────
# The Flutter app can POST GPS updates here so the WS handler has fresh data.
# Alternative: send GPS over the WebSocket itself (also handled below).

@router.post("/position")
async def update_position(
    session_id: str,
    lat: float,
    lng: float,
    _api_key: str = Depends(verify_api_key),
):
    """
    Receives a GPS position update from the Flutter app.
    The WebSocket handler reads these to compute navigation state.
    """
    _session_positions[session_id] = (lat, lng)
    return {"ok": True}


# ── WS /api/v1/navigation/ws/{session_id} ────────────────────────────────────

@router.websocket("/ws/{session_id}")
async def navigation_websocket(
    websocket: WebSocket,
    session_id: str,
    api_key: str = Query(...),
):
    """
    Real-time navigation state over WebSocket.

    The Flutter frontend connects when navigation starts and expects
    JSON messages pushed every ~2 seconds:

        {
            "bearing": 142.5,         # degrees from north to target
            "distance_metres": 23.7,  # straight-line distance
            "hot_cold_score": 0.78,   # 0.0 (far) to 1.0 (close)
            "hint": "Getting warmer 🌡",
            "waypoint_index": 2,
            "arrived": false
        }

    When "arrived" is true, the Flutter app navigates to the arrival
    screen, and the server closes the connection.

    ── GPS Source ──
    The server needs the user's current GPS to compute bearing/distance.
    Two methods are supported:
      1. POST /api/v1/navigation/position (separate HTTP call)
      2. Client sends JSON over WS: {"lat": 65.0, "lng": 25.4}
    """
    # Validate API key
    settings = get_settings()
    if api_key not in settings.api_key_set:
        await websocket.close(code=4001, reason="Invalid API key")
        return

    await websocket.accept()

    # Look up the target plant for this session.
    # The plant_id must be stored when the route is requested.
    # For now, we also accept it as a query param or initial WS message.
    target_plant: PlantRow | None = None

    try:
        while True:
            # ── Check for incoming messages (non-blocking) ────────────────────
            # The client might send GPS updates or a target plant_id.
            try:
                raw = await asyncio.wait_for(
                    websocket.receive_text(),
                    timeout=settings.ws_push_interval_seconds,
                )
                data = json.loads(raw)

                # Client sending GPS update
                if "lat" in data and "lng" in data:
                    _session_positions[session_id] = (data["lat"], data["lng"])

                # Client sending target plant ID
                if "plant_id" in data:
                    _session_targets[session_id] = data["plant_id"]

            except asyncio.TimeoutError:
                pass  # No message — proceed to push state

            # ── Resolve target plant if needed ────────────────────────────────
            if target_plant is None and session_id in _session_targets:
                async with get_db_session() as db:
                    target_plant = await db.get(
                        PlantRow, _session_targets[session_id]
                    )

            # ── Compute and push navigation state ─────────────────────────────
            user_pos = _session_positions.get(session_id)

            if user_pos and target_plant and target_plant.gps_lat and target_plant.gps_lng:
                user_lat, user_lng = user_pos
                plant_lat = target_plant.gps_lat
                plant_lng = target_plant.gps_lng

                dist = haversine_metres(user_lat, user_lng, plant_lat, plant_lng)
                bear = bearing_degrees(user_lat, user_lng, plant_lat, plant_lng)
                score = hot_cold_score(dist)
                arrived = dist < settings.arrival_threshold_metres

                await websocket.send_json({
                    "bearing": round(bear, 1),
                    "distance_metres": round(dist, 1),
                    "hot_cold_score": round(score, 3),
                    "hint": hint_for_score(score),
                    "waypoint_index": 0,
                    "arrived": arrived,
                })

                if arrived:
                    logger.info(
                        "Session %s arrived at plant %s",
                        session_id, target_plant.taxon_number,
                    )
                    await websocket.close()
                    break
            else:
                # No position yet — send a waiting state
                await websocket.send_json({
                    "bearing": 0.0,
                    "distance_metres": 0.0,
                    "hot_cold_score": 0.5,
                    "hint": "Waiting for GPS…",
                    "waypoint_index": 0,
                    "arrived": False,
                })

    except WebSocketDisconnect:
        logger.info("Session %s disconnected", session_id)
    except Exception as e:
        logger.error("WS error for session %s: %s", session_id, e)
    finally:
        # Clean up session data
        _session_positions.pop(session_id, None)
        _session_targets.pop(session_id, None)


# ── Helper: get a DB session outside of FastAPI dependency injection ──────────

from database import async_session

class _DBCtx:
    """Async context manager for DB sessions outside of request scope."""
    async def __aenter__(self):
        self.session = async_session()
        return self.session
    async def __aexit__(self, *args):
        await self.session.close()

def get_db_session():
    return _DBCtx()
