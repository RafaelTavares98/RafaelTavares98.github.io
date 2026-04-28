-- ORION-HOMEGOODS — pallet-equivalent pricing + white-glove handling fee
-- Home furnishings client; billing is pallet-based (every 4 units = 1 pallet equivalent).
-- Picks of 2+ pallet equivalents require white-glove handling: flat fee applied.

local UNITS_PER_PALLET      = 4
local WHITE_GLOVE_THRESHOLD = 2    -- pallet equivalents that trigger the fee
local WHITE_GLOVE_FEE       = 15.00

local function pallet_eq(qty)
  return math.ceil(qty / UNITS_PER_PALLET)
end

return {
  version = "ORION-v1",

  receive = function(e) return pallet_eq(e.quantity) * 3.50 end,
  putaway = function(e) return pallet_eq(e.quantity) * 2.50 end,

  pick = function(e)
    local p   = pallet_eq(e.quantity)
    local fee = p * 4.00
    if p >= WHITE_GLOVE_THRESHOLD then
      fee = fee + WHITE_GLOVE_FEE
    end
    return fee
  end,

  pack = function(e) return pallet_eq(e.quantity) * 3.00 end,
  ship = function(e) return pallet_eq(e.quantity) * 5.00 end,

  return_fee = function(e)
    return pallet_eq(e.quantity) * 4.00 + WHITE_GLOVE_FEE
  end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 4.00
  end,

  cpi_adjustment = 1.025,
}
