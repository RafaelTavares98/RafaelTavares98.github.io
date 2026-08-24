-- COASTAL-FRESH — cold-chain multiplier on all operations + extreme rush premium
-- Fresh produce client; every billable operation carries a 30% cold-chain surcharge.
-- Rush orders add a further 50% on top of the cold-adjusted rate.
-- Storage is billed at a fixed cold rate regardless of rush status.
--
-- Lua pattern shown: U.with_surcharges() applies multipliers left-to-right
-- using variadic args (...). The conditional logic decides how many to pass —
-- no if/else inside the calculation itself.

local U = dofile("rate_cards/lib/billing_utils.lua")

local COLD_CHAIN_FACTOR = 1.30
local RUSH_FACTOR       = 1.50

-- Returns the surcharge factors that apply to this event.
-- Called once per handler so the condition is evaluated only at the boundary.
local function surcharges(event)
  if event.metadata and event.metadata.is_rush then
    return COLD_CHAIN_FACTOR, RUSH_FACTOR   -- two multipliers
  end
  return COLD_CHAIN_FACTOR                  -- one multiplier
end

return {
  version = "COASTAL-v1",

  receive    = function(e) return U.with_surcharges(e.quantity * 0.14, surcharges(e)) end,
  putaway    = function(e) return U.with_surcharges(e.quantity * 0.08, surcharges(e)) end,
  pick       = function(e) return U.with_surcharges(e.quantity * 0.40, surcharges(e)) end,
  pack       = function(e) return U.with_surcharges(1.60, surcharges(e)) end,
  ship       = function(e) return U.with_surcharges(e.quantity * 0.10 + 1.50, surcharges(e)) end,
  return_fee = function(e) return U.with_surcharges(4.00, surcharges(e)) end,

  -- Storage uses a fixed cold rate; rush flag is explicitly ignored.
  -- The comment serves as the contract: a future change to add rush
  -- storage pricing should be deliberate and visible here.
  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 3.20   -- cold rate, no rush multiplier
  end,

  cpi_adjustment = 1.047,
}
