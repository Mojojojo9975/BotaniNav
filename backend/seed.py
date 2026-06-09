# backend/seed.py
#
# One-time script to populate the local database from the puutarhakanta
# external API (https://puutarhakanta-api.onrender.com).
#
# Pulls all Finnish plant names from /muunkielinen_nimi/ and creates
# PlantRow entries for each unique taxon.
#
# Usage:
#   cd backend
#   python seed.py
#
# After seeding, use the coordinate_picker.html tool to assign GPS
# coordinates, then import them via POST /api/v1/plants/coordinates.

import asyncio
import httpx
from database import PlantRow, init_db, async_session
from sqlalchemy import select

PLANT_DB_BASE = "https://web-database-six.vercel.app/api"
NAMES_PATH = "/muunkielinen_nimi/"
PAGE_SIZE = 500


async def seed():
    print("🌱 Initialising database...")
    await init_db()

    print("📡 Fetching plant names from puutarhakanta...")

    # ── Step 1: Fetch all Finnish names ───────────────────────────────────────
    finnish_names: dict[str, dict] = {}   # taxon_id → {primary, alts}
    skip = 0
    total_fetched = 0

    async with httpx.AsyncClient(timeout=30.0) as client:
        while True:
            url = f"{PLANT_DB_BASE}{NAMES_PATH}?skip={skip}&limit={PAGE_SIZE}"
            print(f"  Fetching {url}...")
            resp = await client.get(url)
            resp.raise_for_status()
            items = resp.json()

            if not isinstance(items, list):
                items = items.get("items", items.get("results", []))

            if not items:
                break

            total_fetched += len(items)

            for item in items:
                lang = (item.get("kieli") or "").lower()
                taxon_id = str(item.get("taksonin_nro", ""))
                name = item.get("nimi", "")

                if lang == "suomi" and taxon_id:
                    if taxon_id not in finnish_names:
                        finnish_names[taxon_id] = {"primary": name, "alts": []}
                    else:
                        finnish_names[taxon_id]["alts"].append(name)

            if len(items) < PAGE_SIZE:
                break
            skip += PAGE_SIZE

    print(f"  → {total_fetched} name records fetched")
    print(f"  → {len(finnish_names)} unique Finnish plant names found")

    # ── Step 2: Fetch scientific names from /kaspinosat/ or /taksoni/ ─────────
    # The main taxonomy endpoint. Try to enrich with scientific names.
    scientific_names: dict[str, str] = {}

    try:
        skip = 0
        while True:
            url = f"{PLANT_DB_BASE}/taksoni/?skip={skip}&limit={PAGE_SIZE}"
            print(f"  Fetching scientific names: {url}...")
            resp = await client.get(url)
            resp.raise_for_status()
            items = resp.json()

            if not isinstance(items, list):
                items = items.get("items", items.get("results", []))
            if not items:
                break

            for item in items:
                tid = str(item.get("taksonin_nro", ""))
                sci = item.get("tieteellinen_nimi", "") or item.get("nimi", "")
                if tid and sci:
                    scientific_names[tid] = sci

            if len(items) < PAGE_SIZE:
                break
            skip += PAGE_SIZE

        print(f"  → {len(scientific_names)} scientific names fetched")
    except Exception as e:
        print(f"  ⚠ Could not fetch scientific names: {e}")
        print(f"    (Using Finnish names as fallback)")

    # ── Step 3: Upsert into local database ────────────────────────────────────
    print("💾 Writing to database...")

    async with async_session() as db:
        created = 0
        updated = 0

        for taxon_id, names in finnish_names.items():
            existing = await db.get(PlantRow, taxon_id)

            finnish = names["primary"]
            scientific = scientific_names.get(taxon_id, finnish)

            if existing:
                # Update Finnish name if missing
                if not existing.finnish_name:
                    existing.finnish_name = finnish
                if not existing.name:
                    existing.name = scientific
                updated += 1
            else:
                plant = PlantRow(
                    taxon_number=taxon_id,
                    name=scientific,
                    finnish_name=finnish,
                    section="",
                    plant_status="Healthy",
                )
                db.add(plant)
                created += 1

        await db.commit()
        print(f"  → {created} plants created, {updated} updated")

    print("✅ Seed complete!")
    print()
    print("Next steps:")
    print("  1. Open coordinate_picker.html to assign GPS coordinates")
    print("  2. Export the JSON from the picker")
    print("  3. Import via: POST /api/v1/plants/coordinates")
    print("  4. Or run: python import_coords.py coordinates.json")


if __name__ == "__main__":
    asyncio.run(seed())
