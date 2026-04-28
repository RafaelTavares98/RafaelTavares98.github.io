-- COASTAL-FRESH — cold-chain multiplier on all operations + extreme rush premium
-- Fresh produce client; every billable operation carries a 30% cold-chain surcharge.
-- Rush orders add a further 50% on top of the cold-adjusted rate.
-- Storage is billed at a fixed cold rate regardless of rush status.

local COLD_CHAIN_FACTOR  = 1.30
local RUSH_FACTOR        = 1.50

local function cold(base, event)
  local amount = base * COLD_CHAIN_FACTOR
  if event.metadata and event.metadata.is_rush then
    amount = amount * RUSH_FACTOR
  end
  return amount
end

return {
  version = "COASTAL-v1",

  receive    = function(e) return cold(e.quantity * 0.14, e) end,
  putaway    = function(e) return cold(e.quantity * 0.08, e) end,
  pick       = function(e) return cold(e.quantity * 0.40, e) end,
  pack       = function(e) return cold(1.60, e) end,
  ship       = function(e) return cold(e.quantity * 0.10 + 1.50, e) end,
  return_fee = function(e) return cold(4.00, e) end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 3.20
  end,

  cpi_adjustment = 1.047,
}
