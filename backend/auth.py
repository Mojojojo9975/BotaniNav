# backend/auth.py
#
# API key authentication — used as a FastAPI dependency.
# HTTP requests: reads X-API-Key header.
# WebSocket:     reads ?api_key= query parameter.

from fastapi import Header, HTTPException, Query, WebSocket, status
from config import get_settings


async def verify_api_key(x_api_key: str = Header(..., alias="X-API-Key")):
    """
    FastAPI dependency for HTTP endpoints.
    Raises 401 if the key is missing or invalid.
    """
    settings = get_settings()
    if x_api_key not in settings.api_key_set:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API key",
        )
    return x_api_key


async def verify_ws_api_key(websocket: WebSocket, api_key: str = Query(...)):
    """
    Validates the API key for WebSocket connections.
    Returns the key if valid, otherwise closes with 4001.
    """
    settings = get_settings()
    if api_key not in settings.api_key_set:
        await websocket.close(code=4001, reason="Invalid API key")
        return None
    return api_key
