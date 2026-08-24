-- HARLOW-ELECTRONICS — flat event fees + multi-unit pick surcharge
-- Electronics client; billing is value-based (per event), not quantity-based.
-- Picks above 5 units carry an assembly-risk surcharge per additional unit.

local EVENT_FLAT_FEES = {
  receive    = 8.00,
  putaway    = 5.00,
  pack       = 4.50,
  ship       = 7.00,
}

local PICK_BASE_FEE          = 6.00
local PICK_MULTI_UNIT_CUTOFF = 5
local PICK_EXTRA_PER_UNIT    = 0.50

return {
  version = "HARLOW-v1",

  receive = function(e) return EVENT_FLAT_FEES.receive end,
  putaway = function(e) return EVENT_FLAT_FEES.putaway end,

  pick = function(e)
    local fee = PICK_BASE_FEE
    if e.quantity > PICK_MULTI_UNIT_CUTOFF then
      fee = fee + (e.quantity - PICK_MULTI_UNIT_CUTOFF) * PICK_EXTRA_PER_UNIT
    end
    return fee
  end,

  pack       = function(e) return EVENT_FLAT_FEES.pack end,
  ship       = function(e) return EVENT_FLAT_FEES.ship end,
  return_fee = function(e) return 12.00 end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 3.50
  end,

  cpi_adjustment = 1.044,
}
