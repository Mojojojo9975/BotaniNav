# backend/routes/qr.py
#
# QR scan endpoint — Phase 3 / hardware integration.
#
#   POST /api/v1/scan
#
# When a user scans a section QR code inside the greenhouse,
# the Flutter app sends the section_id here. The backend can then
# anchor the user's position to that known section location
# and update the indoor navigation state.
#
# This is a stub — implement when BLE beacons / hardware are ready.

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from auth import verify_api_key

router = APIRouter(prefix="/api/v1", tags=["qr"])


class QrScanRequest(BaseModel):
    section_id: str


class QrScanResponse(BaseModel):
    status: str
    section_id: str
    message: str


@router.post("/scan", response_model=QrScanResponse)
async def post_qr_scan(
    req: QrScanRequest,
    _api_key: str = Depends(verify_api_key),
):
    """
    Receives a QR code scan from the greenhouse.

    The Flutter app calls this when the user scans a section QR code.
    The section_id (e.g. "A-12") identifies which greenhouse section
    the user is physically standing at.

    TODO [Backend Phase 3 / Hardware]:
      - Look up the section's known coordinates
      - Update the user's indoor navigation state
      - Trigger BLE beacon calibration if applicable

    For now, returns a stub response so the app doesn't crash.
    """
    return QrScanResponse(
        status="pending",
        section_id=req.section_id,
        message=f"QR scan for section {req.section_id} received. "
                f"Indoor anchoring pending Phase 3 hardware integration.",
    )
