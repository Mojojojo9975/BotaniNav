# backend/database.py
#
# Async SQLAlchemy setup + Plant ORM model.
# Uses SQLite by default — swap database_url in config for PostgreSQL.

from sqlalchemy import Column, String, Float, Text, Boolean
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from config import get_settings

settings = get_settings()

engine = create_async_engine(settings.database_url, echo=settings.debug)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass


class PlantRow(Base):
    """
    One plant in the garden.

    Mirrors the JSON contract expected by the Flutter frontend.
    The taxon_number is the primary key — matches 'taxonNumber' in the API response
    and 'taksonin_nro' from the puutarhakanta external DB.
    """
    __tablename__ = "plants"

    taxon_number = Column(String, primary_key=True, index=True)
    name = Column(String, nullable=False, default="")           # scientific name
    finnish_name = Column(String, nullable=True)
    synonym = Column(String, nullable=True)
    family_name = Column(String, nullable=True)

    # ── Section / placement ───────────────────────────────────────────────────
    section = Column(String, nullable=True, default="")         # e.g. "A-12"
    plant_comments = Column(Text, nullable=True)
    plant_status = Column(String, nullable=True, default="Healthy")

    # ── Indoor enriched data ──────────────────────────────────────────────────
    square_x = Column(Float, nullable=True)                     # GeoJSON longitude
    square_y = Column(Float, nullable=True)                     # GeoJSON latitude
    greenhouse_id = Column(String, nullable=True)

    # ── Images ────────────────────────────────────────────────────────────────
    image_url = Column(String, nullable=True)
    thumbnail_url = Column(String, nullable=True)

    # ── Outdoor GPS coordinates ───────────────────────────────────────────────
    # These are set by the coordinate picker tool.
    # NULL until a staff member maps the plant.
    gps_lat = Column(Float, nullable=True)
    gps_lng = Column(Float, nullable=True)

    def to_api_dict(self) -> dict:
        """Serialize to the JSON shape the Flutter frontend expects."""
        return {
            "taxonNumber": self.taxon_number,
            "name": self.name or "",
            "finnishName": self.finnish_name,
            "synonym": self.synonym,
            "family": {"name": self.family_name} if self.family_name else None,
            "placement": {
                "square": self.section or "",
                "plantComments": self.plant_comments,
                "plantStatus": self.plant_status,
            },
            "enriched": {
                "square_x": self.square_x,
                "square_y": self.square_y,
                "greenhouse_id": self.greenhouse_id,
            },
            "image_url": self.image_url,
            "thumbnail_url": self.thumbnail_url,
            "gps_lat": self.gps_lat,
            "gps_lng": self.gps_lng,
        }


async def init_db():
    """Create tables if they don't exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_db() -> AsyncSession:
    """FastAPI dependency — yields an async DB session."""
    async with async_session() as session:
        yield session
