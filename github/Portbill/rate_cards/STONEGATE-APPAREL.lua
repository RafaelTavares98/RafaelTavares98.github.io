-- STONEGATE-APPAREL — grace-period storage + scalable pack + return re-inspection fee
-- Fashion client; first 5 pallet positions are free (SLA grace period).
-- Large storage volumes above 20 billable pallets earn an overflow discount.
-- Returns require garment re-inspection: flat fee plus per-unit handling.

local GRACE_PALLETS      = 5
local STORAGE_BASE_RATE  = 1.80
local STORAGE_OVERFLOW_RATE = 1.40  -- applies beyond 20 billable pallets
local STORAGE_OVERFLOW_BREAK = 20

local RETURN_BASE_FEE    = 2.00
local RETURN_PER_UNIT    = 0.15

return {
  version = "STONEGATE-v1",

  receive = function(e) return e.quantity * 0.11 end,
  putaway = function(e) return e.quantity * 0.06 end,
  pick    = function(e) return e.quantity * 0.48 end,

  pack = function(e)
    if e.quantity <= 5 then return 1.00 end
    return 1.00 + (e.quantity - 5) * 0.10
  end,

  ship = function(e) return 1.70 end,

  return_fee = function(e)
    return RETURN_BASE_FEE + e.quantity * RETURN_PER_UNIT
  end,

  storage_snapshot = function(e)
    local p        = e.metadata and e.metadata.pallet_count or 0
    local billable = math.max(0, p - GRACE_PALLETS)
    if billable > STORAGE_OVERFLOW_BREAK then
      return (STORAGE_OVERFLOW_BREAK * STORAGE_BASE_RATE)
           + ((billable - STORAGE_OVERFLOW_BREAK) * STORAGE_OVERFLOW_RATE)
    end
    return billable * STORAGE_BASE_RATE
  end,

  cpi_adjustment = 1.033,
}
