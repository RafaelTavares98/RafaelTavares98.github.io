-- ORION-HOMEGOODS — pallet-equivalent pricing + white-glove handling fee
-- Home furnishings client; billing is pallet-based (every 4 units = 1 pallet equivalent).
-- Picks of 2+ pallet equivalents require white-glove handling: flat fee applied.
--
-- Lua pattern shown: U.pallet_eq() wraps math.ceil(qty / N) with a named
-- intent. Using a named function instead of inline math makes the rate
-- card readable to a non-engineer reading the contract terms.

local U = dofile("rate_cards/lib/billing_utils.lua")

local UNITS_PER_PALLET      = 4
local WHITE_GLOVE_THRESHOLD = 2      -- pallet equivalents that trigger the fee
local WHITE_GLOVE_FEE       = 15.00

return {
  version = "ORION-v1",

  receive = function(e) return U.pallet_eq(e.quantity, UNITS_PER_PALLET) * 3.50 end,
  putaway = function(e) return U.pallet_eq(e.quantity, UNITS_PER_PALLET) * 2.50 end,

  pick = function(e)
    local p   = U.pallet_eq(e.quantity, UNITS_PER_PALLET)
    local fee = p * 4.00
    -- White-glove threshold is a contractual minimum: any shipment occupying
    -- 2+ pallet positions requires supervised handling, regardless of value.
    if p >= WHITE_GLOVE_THRESHOLD then
      fee = fee + WHITE_GLOVE_FEE
    end
    return fee
  end,

  pack = function(e) return U.pallet_eq(e.quantity, UNITS_PER_PALLET) * 3.00 end,
  ship = function(e) return U.pallet_eq(e.quantity, UNITS_PER_PALLET) * 5.00 end,

  -- Returns always include white-glove: furniture pieces must be inspected
  -- for damage on the way back regardless of pallet count.
  return_fee = function(e)
    return U.pallet_eq(e.quantity, UNITS_PER_PALLET) * 4.00 + WHITE_GLOVE_FEE
  end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 4.00
  end,

  cpi_adjustment = 1.025,
}
