# BotaniNav Backend

FastAPI backend for the BotaniNav botanical garden navigation app.

## Quick Start

```bash
cd backend

# 1. Create virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

# 2. Install dependencies
pip install -r requirements.txt

# 3. Configure environment
copy .env.example .env
# Edit .env — add your GOOGLE_MAPS_API_KEY and API_KEYS

# 4. Seed the database from puutarhakanta
python seed.py

# 5. Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

The API docs are available at **http://localhost:8000/docs** (Swagger UI).

## Project Structure

```
backend/
├── main.py              ← FastAPI entry point
├── config.py            ← Environment settings (reads .env)
├── database.py          ← SQLAlchemy models + async session
├── auth.py              ← API key verification
├── geo.py               ← Haversine, bearing, hot/cold helpers
├── schemas.py           ← Pydantic request/response models
├── routes/
│   ├── plants.py        ← GET /plants + POST /plants/coordinates
│   ├── navigation.py    ← POST /route + WS /ws/{session_id}
│   └── qr.py            ← POST /scan (Phase 3 stub)
├── seed.py              ← Populate DB from puutarhakanta API
├── import_coords.py     ← CLI import for coordinate picker JSON
├── requirements.txt
└── .env.example
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/v1/plants` | Full plant catalogue with GPS coords |
| POST | `/api/v1/plants/coordinates` | Import coords from coordinate picker |
| POST | `/api/v1/navigation/route` | Walking route via Google Directions |
| POST | `/api/v1/navigation/position` | Push GPS update for WS session |
| WS | `/api/v1/navigation/ws/{session_id}` | Real-time bearing/distance/arrival |
| POST | `/api/v1/scan` | QR code scan (Phase 3 stub) |
| GET | `/health` | Health check |

## Workflow: Mapping Outdoor Plants

1. **Seed the database** — `python seed.py` pulls plant names from puutarhakanta
2. **Open coordinate_picker.html** — staff tool to click GPS locations on satellite view
3. **Export JSON** from the picker
4. **Import coordinates** via either:
   - CLI: `python import_coords.py coordinates.json`
   - API: `POST /api/v1/plants/coordinates` with the JSON body
5. **Plants appear on the outdoor map** in the Flutter app

## Auth

All HTTP requests require `X-API-Key` header.
WebSocket connections use `?api_key=` query parameter.

Valid keys are configured in `.env` as a comma-separated `API_KEYS` list.

## Flutter App Configuration

In the Flutter app's `.env` file, set:

```
API_BASE_URL=http://your-server:8000
```

For local development on an Android emulator, use `http://10.0.2.2:8000`.
