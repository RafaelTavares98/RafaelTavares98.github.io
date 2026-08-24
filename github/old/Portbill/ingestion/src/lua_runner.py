"""
Python ↔ Lua bridge.

This file is the entire surface area of the cross-language hop. It exists
to load a merchant's rate card (a `.lua` file that returns a table of
functions), pick the function matching the event_type, and execute it on
a converted copy of the event dict.

Why Lua at all (the headline architectural decision):
  The target billing system (S1B) ships pricing rules as Lua scripts so
  the billing team can amend a contract without a code release. Mirroring
  that here was the single most important design choice — without it,
  the project is just "Python validates JSON". With it, the project
  demonstrates the actual integration pattern the role requires.

Why `lupa` specifically:
  - Pure-Python wrapper around a real Lua 5.4 VM (~1 MB embedded).
  - No second process or service to manage; the VM lives inside the
    Python container.
  - Mature: it's the same library JupyterLab uses for its Lua kernel.

Why a fresh LuaRuntime per call:
  Tempting to cache the runtime as a module-level singleton — and in a
  high-QPS service we would. Here the pipeline processes maybe 10 events
  per hour, and `dofile` reload is *the feature*: edit a rate card, the
  next event picks up the change with no restart. A cached runtime would
  defeat that.
"""

from pathlib import Path

import lupa


def _to_lua_table(lua_rt, obj):
    """Recursively convert a Python dict/list to a Lua table.

    Why this conversion exists at all:
      lupa auto-converts the *outer* call argument, but nested dicts come
      through as Python objects (PyObject pointers). Rate cards reach into
      `event.metadata.is_rush` constantly — without the recursive walk
      that access raises a Lua error instead of returning nil.

    Two non-obvious details:
      1. Lua arrays are 1-indexed. `enumerate(obj, 1)` matters: starting
         at 0 would silently shift every list element by one, and you'd
         find out only when a rate card produces wrong totals.
      2. A Lua "table" is dict, list, namespace, and object all at once.
         The same `lua_rt.table()` call serves all three roles — that's
         why a rate card can `return { version = "v1", pick = function ... }`
         and have it read like config and execute like code.
    """
    if isinstance(obj, dict):
        t = lua_rt.table()
        for k, v in obj.items():
            t[k] = _to_lua_table(lua_rt, v)
        return t
    if isinstance(obj, list):
        t = lua_rt.table()
        for i, v in enumerate(obj, 1):   # 1-indexed: Lua's choice, not a bug
            t[i] = _to_lua_table(lua_rt, v)
        return t
    return obj


def calculate_charge(event: dict, rate_cards_dir: str = "rate_cards") -> tuple[float, str]:
    """Load the merchant's Lua rate card and return (amount, rate_card_version).

    Architecture flow:
      1. `dofile()` reads the `.lua` file from disk and executes it. The
         file ends in `return { ... }`, so the value of the dofile
         expression is the rate card table itself.
      2. We pick a handler function by event_type. In Python this would be
         a class method or dict-of-lambdas; in Lua it's just `card[name]`,
         and the handler closes over any `local` constants declared at the
         top of the file (see STONEGATE-APPAREL.lua for grace-period
         constants used this way).
      3. We convert the Python event dict to a Lua table and call the
         handler. The result is a number — the dollar amount.

    Returning the version alongside the amount lets us trace any charge
    back to the exact rate card revision that produced it. Audit teams
    care about this; it's the same reason invoices include a contract
    reference number.
    """
    merchant_id = event["merchant_id"]
    card_path = Path(rate_cards_dir) / f"{merchant_id}.lua"

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    card = lua.eval(f'dofile("{card_path.as_posix()}")')

    # `return` is a reserved word in Lua, so rate cards can't expose a
    # function literally named `return`. The convention is to use
    # `return_fee` in the table and remap it here. Keeps the rate cards
    # syntactically valid without polluting the public event_type vocabulary.
    event_type = event["event_type"]
    handler_name = "return_fee" if event_type == "return" else event_type

    handler = card[handler_name]
    if handler is None:
        # Defensive: a missing handler means the rate card is incomplete
        # for this event_type. Raising rather than returning 0 makes the
        # bug visible — silent zeros would underbill the customer.
        raise ValueError(f"No handler '{handler_name}' in {merchant_id} rate card")

    lua_event = _to_lua_table(lua, event)
    amount = handler(lua_event)
    version = str(card["version"])
    return float(amount), version
