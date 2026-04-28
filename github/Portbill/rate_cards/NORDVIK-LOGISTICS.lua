-- NORDVIK-LOGISTICS — three-tier pick pricing based on order volume
-- High-volume 3PL client; larger picks earn progressively lower per-unit rates.

local PICK_TIERS = {
  { threshold = 10,  rate = 0.55 },
  { threshold = 30,  rate = 0.45 },
  { threshold = math.huge, rate = 0.35 },
}

local function tiered_pick(qty)
  for _, tier in ipairs(PICK_TIERS) do
    if qty <= tier.threshold then
      return qty * tier.rate
    end
  end
end

return {
  version = "NORDVIK-v1",

  receive  = function(e) return e.quantity * 0.10 end,
  putaway  = function(e) return e.quantity * 0.06 end,
  pick     = function(e) return tiered_pick(e.quantity) end,
  pack     = function(e) return 1.20 end,
  ship     = function(e) return 1.80 end,
  return_fee = function(e) return 2.50 end,

  storage_snapshot = function(e)
    local p = e.metadata and e.metadata.pallet_count or 0
    return p * 1.90
  end,

  cpi_adjustment = 1.028,
}
