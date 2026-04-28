import math
import random
import uuid
from datetime import datetime, timezone, timedelta

MERCHANTS = [
    "NORDVIK-LOGISTICS",
    "HARLOW-ELECTRONICS",
    "STONEGATE-APPAREL",
    "COASTAL-FRESH",
    "ORION-HOMEGOODS",
]

WAREHOUSES = ["WH-DAL-01", "WH-ATL-02", "WH-LAX-03", "WH-CHI-04", "WH-NYC-05"]

EVENT_TYPES = ["receive", "putaway", "pick", "pack", "ship", "return", "storage_snapshot"]

REQUIRED_FIELDS = {"event_id", "merchant_id", "warehouse_id", "event_type", "timestamp", "quantity"}

MONTHLY_TARGET = 600  # total events across all merchants per month

_SKUS = [
    "SKU-GEN-CASE-01",  "SKU-GEN-CASE-02",  "SKU-GEN-PALLET-01",
    "SKU-ELC-PHONE-01", "SKU-ELC-TABLET-01", "SKU-ELC-LAPTOP-01", "SKU-ELC-CABLE-01",
    "SKU-APP-SHIRT-M",  "SKU-APP-SHIRT-L",   "SKU-APP-PANTS-32",  "SKU-APP-JACKET-XL",
    "SKU-FRS-BERRY-01", "SKU-FRS-CITRUS-01", "SKU-FRS-LEAFY-01",  "SKU-FRS-ROOT-01",
    "SKU-HME-SOFA-01",  "SKU-HME-TABLE-01",  "SKU-HME-CHAIR-01",  "SKU-HME-LAMP-01",
]

# event_weights order: receive, putaway, pick, pack, ship, return, storage_snapshot
# uom_options: list of (unit_of_measure, weight) pairs — American standard units
# monthly_volume shares must sum to MONTHLY_TARGET (600)
_PROFILES = {
    "NORDVIK-LOGISTICS": {
        "event_weights":  [0.14, 0.14, 0.34, 0.10, 0.20, 0.05, 0.03],
        "qty_mean": 22.0, "qty_std": 9.0, "qty_min": 1, "qty_max": 80,
        "rush_rate": 0.06,
        "monthly_volume": 150,
        "uom_options": [("cs", 0.50), ("ea", 0.35), ("plt", 0.15)],
    },
    "HARLOW-ELECTRONICS": {
        "event_weights":  [0.20, 0.18, 0.22, 0.20, 0.15, 0.04, 0.01],
        "qty_mean":  4.0, "qty_std": 2.0, "qty_min": 1, "qty_max": 15,
        "rush_rate": 0.15,
        "monthly_volume": 110,
        "uom_options": [("ea", 0.85), ("unit", 0.15)],
    },
    "STONEGATE-APPAREL": {
        "event_weights":  [0.18, 0.16, 0.28, 0.15, 0.14, 0.06, 0.03],
        "qty_mean": 18.0, "qty_std": 7.0, "qty_min": 1, "qty_max": 72,
        "rush_rate": 0.10,
        "monthly_volume": 120,
        "uom_options": [("ea", 0.60), ("pc", 0.40)],
    },
    "COASTAL-FRESH": {
        "event_weights":  [0.30, 0.12, 0.18, 0.08, 0.28, 0.03, 0.01],
        "qty_mean": 45.0, "qty_std": 18.0, "qty_min": 5, "qty_max": 200,
        "rush_rate": 0.28,
        "monthly_volume": 110,
        "uom_options": [("lb", 0.70), ("cs", 0.30)],
    },
    "ORION-HOMEGOODS": {
        "event_weights":  [0.20, 0.18, 0.20, 0.10, 0.18, 0.04, 0.10],
        "qty_mean":  3.0, "qty_std": 1.0, "qty_min": 1, "qty_max": 8,
        "rush_rate": 0.03,
        "monthly_volume": 110,
        "uom_options": [("ea", 0.65), ("pc", 0.35)],
    },
}

# Relative activity weight per hour of day (index = hour 0–23, Eastern time)
_HOUR_WEIGHTS = [0, 0, 0, 0, 0, 0, 0, 1,  3, 6, 8, 8, 7, 6, 7, 8,  8, 7, 5, 3, 2, 1, 0, 0]


def _truncated_normal_int(mean: float, std: float, min_val: int, max_val: int) -> int:
    for _ in range(20):
        val = round(random.gauss(mean, std))
        if min_val <= val <= max_val:
            return val
    return max(min_val, min(max_val, round(mean)))


def _poisson(lam: float) -> int:
    if lam <= 0:
        return 0
    L = math.exp(-lam)
    k, p = 0, 1.0
    while p > L:
        k += 1
        p *= random.random()
    return k - 1


def _business_timestamp(base_date: datetime) -> datetime:
    hour = random.choices(range(24), weights=_HOUR_WEIGHTS)[0]
    return base_date.replace(
        hour=hour,
        minute=random.randint(0, 59),
        second=random.randint(0, 59),
        microsecond=random.randint(0, 999_999),
    )


def _pick_uom(profile: dict) -> str:
    uoms, weights = zip(*profile["uom_options"])
    return random.choices(uoms, weights=weights)[0]


def generate_event(merchant_id: str, event_type: str, timestamp: datetime | None = None) -> dict:
    profile = _PROFILES[merchant_id]
    ts = timestamp or datetime.now(timezone.utc)
    qty = _truncated_normal_int(profile["qty_mean"], profile["qty_std"], profile["qty_min"], profile["qty_max"])
    return {
        "event_id":        f"EVT-{ts.strftime('%Y%m%d')}-{uuid.uuid4().hex[:10].upper()}",
        "merchant_id":     merchant_id,
        "warehouse_id":    random.choice(WAREHOUSES),
        "event_type":      event_type,
        "timestamp":       ts.strftime("%Y-%m-%dT%H:%M:%S.") + f"{ts.microsecond // 1000:03d}Z",
        "order_id":        f"ORD-{random.randint(1_000_000, 9_999_999)}",
        "sku":             random.choice(_SKUS),
        "quantity":        qty,
        "unit_of_measure": _pick_uom(profile),
        "metadata":        _build_metadata(event_type, ts, profile),
    }


def _build_metadata(event_type: str, ts: datetime, profile: dict) -> dict:
    wave_period = "AM" if ts.hour < 12 else "PM"
    meta = {
        "zone":    random.choice(["A", "B", "C", "D"]),
        "wave_id": f"WAVE-{ts.strftime('%Y-%m-%d')}-{wave_period}",
        "is_rush": random.random() < profile["rush_rate"],
    }
    if event_type == "storage_snapshot":
        meta["pallet_count"] = random.randint(1, 20)
    return meta


def generate_backlog(months: int = 3) -> list[dict]:
    """Return historical events spread across the past `months` months.

    Each merchant receives its proportional share of MONTHLY_TARGET per month,
    distributed across business hours using a realistic hour-weight profile.
    """
    now = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    events: list[dict] = []

    for merchant_id, profile in _PROFILES.items():
        for m in range(months):
            period_start = (now - timedelta(days=(months - m) * 30)).replace(tzinfo=timezone.utc)
            for _ in range(profile["monthly_volume"]):
                day_offset = random.randint(0, 29)
                base = period_start + timedelta(days=day_offset)
                ts = _business_timestamp(base)
                event_type = random.choices(EVENT_TYPES, weights=profile["event_weights"])[0]
                events.append(generate_event(merchant_id, event_type, timestamp=ts))

    events.sort(key=lambda e: e["timestamp"])
    return events


def hourly_batch() -> list[dict]:
    """Generate new events for the current hour proportional to each merchant's monthly volume."""
    now = datetime.now(timezone.utc)
    events: list[dict] = []
    for merchant_id, profile in _PROFILES.items():
        lam = profile["monthly_volume"] / 720.0
        for _ in range(_poisson(lam)):
            event_type = random.choices(EVENT_TYPES, weights=profile["event_weights"])[0]
            events.append(generate_event(merchant_id, event_type, timestamp=now))
    return events


def inject_error(event: dict, category: str) -> dict:
    """Return a copy of event with one error injected. Pure function — no mutation."""
    corrupted = dict(event)
    corrupted["metadata"] = dict(event.get("metadata", {}))

    if category == "schema":
        field = random.choice(["merchant_id", "event_type", "timestamp", "quantity"])
        corrupted.pop(field, None)
    elif category == "business_logic":
        corrupted["quantity"] = random.choice([0, -1, -random.randint(2, 20)])
    elif category == "reference":
        corrupted["merchant_id"] = "INVALID-MERCHANT-XYZ"
    elif category == "duplicate":
        pass
    elif category == "time_anomaly":
        future = datetime.now(timezone.utc) + timedelta(days=random.randint(1, 30))
        corrupted["timestamp"] = future.strftime("%Y-%m-%dT%H:%M:%S.") + f"{future.microsecond // 1000:03d}Z"

    return corrupted
