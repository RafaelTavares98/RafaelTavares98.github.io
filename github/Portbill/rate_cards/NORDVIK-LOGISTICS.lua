-- NORDVIK-LOGISTICS — three-tier pick pricing based on order volume
-- High-volume 3PL client; larger picks earn progressively lower per-unit rates.
--
-- Lua pattern shown: tiered pricing extracted to billing_utils.tiered()
-- so the tier table reads as data (config), not as procedural logic.

local U = dofile("rate_cards/lib/billing_utils.lua")

-- Tier table: array of {max, rate} pairs sorted ascending.
-- U.tiered() walks this with ipairs and returns on the first match.
-- math.huge represents "no upper bound" — any qty above 30 falls here.
local PICK_TIERS = {
  { max = 10,         rate = 0.55 },
  { max = 30,         rate = 0.45 },
  { max = math.huge,  rate = 0.35 },
}

return {
  version = "NORDVIK-v1",

  receive  = function(e) return e.quantity * 0.10 end,
  putaway  = function(e) return e.quantity * 0.06 end,
  pick     = function(e) return U.tiered(e.quantity, PICK_TIERS) end,
  pack     = function(e) return 1.20 end,
  ship     = function(e) return 1.80 end,
  return_fee = function(e) return 2.50 end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 1.90
  end,

  cpi_adjustment = 1.028,
}
