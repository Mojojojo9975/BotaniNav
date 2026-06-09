# backend/geo.py
#
# Geodesic helper functions for navigation.
# Used by the WebSocket handler to compute bearing and distance
# between user position and target plant.

import math


def haversine_metres(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """
    Great-circle distance in metres between two GPS points.
    Uses the Haversine formula.
    """
    R = 6_371_000  # Earth radius in metres

    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lam = math.radians(lng2 - lng1)

    a = (math.sin(d_phi / 2) ** 2
         + math.cos(phi1) * math.cos(phi2) * math.sin(d_lam / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

    return R * c


def bearing_degrees(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """
    Initial bearing in degrees (0–360, clockwise from north)
    from point 1 to point 2.

    This is used by the Flutter frontend as:
        arrow_angle = bearing - compass_heading
    to rotate the navigation arrow toward the target.
    """
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    d_lam = math.radians(lng2 - lng1)

    x = math.sin(d_lam) * math.cos(phi2)
    y = (math.cos(phi1) * math.sin(phi2)
         - math.sin(phi1) * math.cos(phi2) * math.cos(d_lam))

    theta = math.atan2(x, y)
    return (math.degrees(theta) + 360) % 360


def hot_cold_score(distance_metres: float, max_range: float = 100.0) -> float:
    """
    Maps distance to a 0.0–1.0 score for the hot/cold gauge.
        0.0 = far away  (cold / blue)
        1.0 = right on it (hot / red)

    Uses an inverse relationship clamped to [0, 1].
    max_range controls how far away "fully cold" is (default 100m).
    """
    if distance_metres <= 0:
        return 1.0
    score = 1.0 - (distance_metres / max_range)
    return max(0.0, min(1.0, score))


def hint_for_score(score: float) -> str:
    """
    Human-readable hint shown in the navigation UI.
    Maps the hot/cold score to an encouraging message.
    """
    if score > 0.9:
        return "You're right here! 🎯"
    if score > 0.7:
        return "Almost there! 🔥"
    if score > 0.5:
        return "Getting warmer 🌡"
    if score > 0.3:
        return "Keep going…"
    return "Getting colder ❄️"
