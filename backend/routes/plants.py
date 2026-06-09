# backend/routes/plants.py
#
# Plant catalogue endpoints:
#   GET  /api/v1/plants              → full catalogue with GPS coords
#   POST /api/v1/plants/coordinates  → import GPS coords from coordinate picker

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth import verify_api_key
from database import get_db, PlantRow
from schemas import CoordinateEntry, CoordinateImportResponse, PlantsResponse

router = APIRouter(prefix="/api/v1", tags=["plants"])


# ── GET /api/v1/plants ────────────────────────────────────────────────────────

@router.get("/plants", response_model=PlantsResponse)
async def get_plants(
    _api_key: str = Depends(verify_api_key),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns the full plant catalogue.

    The Flutter frontend accepts both wrapped {"count": N, "plants": [...]}
    and flat [...] formats. We use the wrapped format.

    Plants with gps_lat/gps_lng set will appear as markers on the outdoor map.
    Plants without GPS coords are shown in the catalogue but not on the map.
    """
    result = await db.execute(select(PlantRow))
    plants = result.scalars().all()

    return PlantsResponse(
        count=len(plants),
        plants=[p.to_api_dict() for p in plants],
    )


# ── POST /api/v1/plants/coordinates ───────────────────────────────────────────

@router.post("/plants/coordinates", response_model=CoordinateImportResponse)
async def import_coordinates(
    entries: list[CoordinateEntry],
    _api_key: str = Depends(verify_api_key),
    db: AsyncSession = Depends(get_db),
):
    """
    Imports GPS coordinates exported by the coordinate_picker.html tool.

    The coordinate picker outputs JSON like:
        [{"taksonin_nro": 451, "gps_lat": 65.063821, "gps_lng": 25.464512}, ...]

    This endpoint matches each taksonin_nro to a plant in the database
    and updates its gps_lat / gps_lng fields.
    """
    updated = 0
    not_found: list[str] = []

    for entry in entries:
        taxon_id = str(entry.taksonin_nro)

        plant = await db.get(PlantRow, taxon_id)
        if plant:
            plant.gps_lat = entry.gps_lat
            plant.gps_lng = entry.gps_lng
            updated += 1
        else:
            not_found.append(taxon_id)

    await db.commit()

    return CoordinateImportResponse(
        updated=updated,
        not_found=not_found,
        total=len(entries),
    )
