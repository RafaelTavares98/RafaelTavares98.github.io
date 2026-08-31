"""Pull hourly candles from the exchange.

The transport sits behind an argument, so the tests run with a fake and never
touch the network. The scheduled job asks for more hours than it needs, and
the warehouse drops the overlap.
"""
from __future__ import annotations

from typing import Callable

import httpx
import pandas as pd

from btc.ingest.klines import parse_klines

URL = "https://api.binance.com/api/v3/klines"
SYMBOL = "BTCUSDT"
PAGE = 1000


def _http_get(params: dict) -> list[list]:
    response = httpx.get(URL, params=params, timeout=30)
    response.raise_for_status()
    return response.json()


def fetch_candles(hours: int = 1000,
                  transport: Callable[[dict], list[list]] = _http_get
                  ) -> pd.DataFrame:
    """Fetch the last `hours` hourly candles, oldest first.

    Args:
        hours: how many hours to ask for. The exchange caps one page at 1000,
            so a larger number pages backwards.
        transport: the function that performs the call. The tests pass a fake.

    Returns:
        The parsed frame, validated by `parse_klines`.
    """
    rows: list[list] = []
    end_time: int | None = None

    while len(rows) < hours:
        params = {"symbol": SYMBOL, "interval": "1h",
                  "limit": min(PAGE, hours - len(rows))}
        if end_time is not None:
            params["endTime"] = end_time
        page = transport(params)
        if not page:
            break
        rows = page + rows
        end_time = page[0][0] - 1

    return parse_klines(rows)
