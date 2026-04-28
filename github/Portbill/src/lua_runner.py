from pathlib import Path

import lupa


def _to_lua_table(lua_rt, obj):
    """Recursively convert a Python dict/list to a Lua table."""
    if isinstance(obj, dict):
        t = lua_rt.table()
        for k, v in obj.items():
            t[k] = _to_lua_table(lua_rt, v)
        return t
    if isinstance(obj, list):
        t = lua_rt.table()
        for i, v in enumerate(obj, 1):
            t[i] = _to_lua_table(lua_rt, v)
        return t
    return obj


def calculate_charge(event: dict, rate_cards_dir: str = "rate_cards") -> tuple[float, str]:
    """Load the merchant's Lua rate card and return (amount, rate_card_version)."""
    merchant_id = event["merchant_id"]
    card_path = Path(rate_cards_dir) / f"{merchant_id}.lua"

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    card = lua.eval(f'dofile("{card_path.as_posix()}")')

    # "return" is a Lua keyword; rate cards expose it as "return_fee"
    event_type = event["event_type"]
    handler_name = "return_fee" if event_type == "return" else event_type

    handler = card[handler_name]
    if handler is None:
        raise ValueError(f"No handler '{handler_name}' in {merchant_id} rate card")

    lua_event = _to_lua_table(lua, event)
    amount = handler(lua_event)
    version = str(card["version"])
    return float(amount), version
