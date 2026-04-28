-- STONEGATE-APPAREL — grace-period storage + scalable pack + return re-inspection fee
-- Fashion client; first 5 pallet positions are free (SLA grace period).
-- Large storage volumes above 20 billable pallets earn an overflow discount.
-- Returns require garment re-inspection: flat fee plus per-unit handling.
--
-- Lua pattern shown: U.storage_with_grace() encapsulates the three-zone
-- storage logic (grace / normal / overflow) as a reusable primitive.
-- The constants remain local to this file — they are this contract's terms,
-- not shared defaults.

local U = dofile("rate_cards/lib/billing_utils.lua")

local GRACE_PALLETS         = 5
local STORAGE_BASE_RATE     = 1.80
local STORAGE_OVERFLOW_RATE = 1.40   -- discount rate above the overflow break
local STORAGE_OVERFLOW_BREAK = 20    -- billable pallets before discount kicks in

local RETURN_BASE_FEE  = 2.00
local RETURN_PER_UNIT  = 0.15

return {
  version = "STONEGATE-v1",

  receive = function(e) return e.quantity * 0.11 end,
  putaway = function(e) return e.quantity * 0.06 end,
  pick    = function(e) return e.quantity * 0.48 end,

  -- Pack fee scales with volume: first 5 units at a flat rate,
  -- each additional unit adds $0.10. Rewards consolidated shipments.
  pack = function(e)
    if e.quantity <= 5 then return 1.00 end
    return 1.00 + (e.quantity - 5) * 0.10
  end,

  ship = function(e) return 1.70 end,

  -- Return re-inspection: flat base + per-unit handling for garment QC.
  return_fee = function(e)
    return RETURN_BASE_FEE + e.quantity * RETURN_PER_UNIT
  end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return U.storage_with_grace(p,
      GRACE_PALLETS,
      STORAGE_BASE_RATE,
      STORAGE_OVERFLOW_BREAK,
      STORAGE_OVERFLOW_RATE)
  end,

  cpi_adjustment = 1.033,
}
