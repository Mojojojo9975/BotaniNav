# backend/import_coords.py
#
# CLI utility to import GPS coordinates from the coordinate picker JSON export
# directly into the database, without going through the REST API.
#
# Usage:
#   python import_coords.py plant_coordinates_2026-06-04.json
#
# The JSON file should be the output from coordinate_picker.html:
#   [{"taksonin_nro": 451, "finnishName": "...", "gps_lat": 65.0, "gps_lng": 25.4}, ...]

import asyncio
import json
import sys
from database import PlantRow, init_db, async_session


async def import_coordinates(filepath: str):
    print(f"📂 Loading {filepath}...")
    with open(filepath, "r", encoding="utf-8") as f:
        entries = json.load(f)

    if not isinstance(entries, list):
        print("❌ Expected a JSON array of coordinate entries.")
        sys.exit(1)

    print(f"  → {len(entries)} coordinate entries found")

    await init_db()

    async with async_session() as db:
        updated = 0
        not_found = []

        for entry in entries:
            taxon_id = str(entry["taksonin_nro"])
            gps_lat = entry["gps_lat"]
            gps_lng = entry["gps_lng"]

            plant = await db.get(PlantRow, taxon_id)
            if plant:
                plant.gps_lat = gps_lat
                plant.gps_lng = gps_lng
                updated += 1
            else:
                #might take a look at it later, as it just appends the takson_id without any coordinates.
                not_found.append(taxon_id)

        await db.commit()

    print(f"✅ Updated {updated} plants with GPS coordinates")
    if not_found:
        print(f"⚠  {len(not_found)} taxon IDs not found in database: {not_found[:10]}{'...' if len(not_found) > 10 else ''}")
    print()
    print("Plants are now visible on the outdoor map! 🗺")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python import_coords.py <coordinates.json>")
        sys.exit(1)

    asyncio.run(import_coordinates(sys.argv[1]))
