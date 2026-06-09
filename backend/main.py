# backend/main.py
#
# FastAPI entry point for the BotaniNav backend.
#
# Start the server:
#   cd backend
#   uvicorn main:app --reload --host 0.0.0.0 --port 8000
#
# Endpoints served:
#   GET  /api/v1/plants              — full plant catalogue
#   POST /api/v1/plants/coordinates  — import GPS coords from picker tool
#   POST /api/v1/navigation/route    — walking route (Google Directions)
#   POST /api/v1/navigation/position — GPS position update for WS sessions
#   WS   /api/v1/navigation/ws/{id}  — real-time navigation state
#   POST /api/v1/scan                — QR code scan (Phase 3 stub)
#   GET  /health                     — health check

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import get_settings
from database import init_db
from routes import plants, navigation, qr

logger = logging.getLogger("botanicnav")


# ── Lifespan ──────────────────────────────────────────────────────────────────

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Runs on startup and shutdown."""
    settings = get_settings()

    # Create tables if they don't exist
    await init_db()
    logger.info("Database initialised")

    if not settings.google_maps_api_key:
        logger.warning(
            "GOOGLE_MAPS_API_KEY not set — "
            "POST /api/v1/navigation/route will fail"
        )

    yield  # App is running

    logger.info("Shutting down")


# ── App ───────────────────────────────────────────────────────────────────────

settings = get_settings()

app = FastAPI(
    title=settings.app_title,
    version=settings.app_version,
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allow the Flutter app and coordinate_picker.html to call the API.

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],            # Tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────

app.include_router(plants.router)
app.include_router(navigation.router)
app.include_router(qr.router)


# ── Health check ──────────────────────────────────────────────────────────────

@app.get("/health", tags=["system"])
async def health():
    return {"status": "ok", "version": settings.app_version}


# ── Logging ───────────────────────────────────────────────────────────────────

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s  %(message)s",
    datefmt="%H:%M:%S",
)
