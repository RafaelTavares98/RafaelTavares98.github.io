-- busted test suite — five rate cards
-- Run from /app: busted rate_cards/tests/test_rate_cards.lua

local function load_card(name)
  return dofile("rate_cards/" .. name .. ".lua")
end

-- Floating-point equality with tolerance (used for compound multiplications)
local function near(a, b)
  return math.abs(a - b) < 1e-9
end

local function event(qty, pallet_count, extras)
  local e = {
    quantity = qty,
    sku      = "SKU-GEN-CASE-01",
    metadata = { pallet_count = pallet_count, is_rush = false, wave_id = "WAVE-2026-03-15-AM" },
  }
  if extras then
    for k, v in pairs(extras) do
      if     k == "sku"     then e.sku = v
      elseif k == "is_rush" then e.metadata.is_rush = v
      elseif k == "wave_id" then e.metadata.wave_id = v
      else                       e[k] = v
      end
    end
  end
  return e
end

-- ---------------------------------------------------------------------------
-- NORDVIK-LOGISTICS — three-tier pick pricing
-- ---------------------------------------------------------------------------
describe("NORDVIK-LOGISTICS", function()
  local card = load_card("NORDVIK-LOGISTICS")

  it("pick tier-1: up to 10 units at $0.55/ea", function()
    assert.are.equal(5.50, card.pick(event(10, 0)))
  end)

  it("pick tier-2: 11–30 units at $0.45/ea", function()
    assert.are.equal(13.50, card.pick(event(30, 0)))
  end)

  it("pick tier-3: above 30 units at $0.35/ea", function()
    assert.are.equal(14.00, card.pick(event(40, 0)))
  end)

  it("receive charges $0.10/unit", function()
    assert.are.equal(2.00, card.receive(event(20, 0)))
  end)

  it("storage charges $1.90 per pallet", function()
    assert.are.equal(9.50, card.storage_snapshot(event(0, 5)))
  end)
end)

-- ---------------------------------------------------------------------------
-- HARLOW-ELECTRONICS — flat event fees + multi-unit pick surcharge
-- ---------------------------------------------------------------------------
describe("HARLOW-ELECTRONICS", function()
  local card = load_card("HARLOW-ELECTRONICS")

  it("pick at or below 5 units is flat $6.00", function()
    assert.are.equal(6.00, card.pick(event(5, 0)))
  end)

  it("pick above 5 units adds $0.50 per extra unit", function()
    -- $6.00 + 5 extra * $0.50 = $8.50
    assert.are.equal(8.50, card.pick(event(10, 0)))
  end)

  it("receive is always flat $8.00 regardless of quantity", function()
    assert.are.equal(8.00, card.receive(event(999, 0)))
  end)

  it("return_fee is flat $12.00", function()
    assert.are.equal(12.00, card.return_fee(event(1, 0)))
  end)
end)

-- ---------------------------------------------------------------------------
-- STONEGATE-APPAREL — grace-period storage + scalable pack + return re-inspection
-- ---------------------------------------------------------------------------
describe("STONEGATE-APPAREL", function()
  local card = load_card("STONEGATE-APPAREL")

  it("storage within 5-pallet grace period costs $0.00", function()
    assert.are.equal(0.00, card.storage_snapshot(event(0, 5)))
  end)

  it("storage above grace period charges $1.80 per billable pallet", function()
    -- 10 pallets: 5 free, 5 billable × $1.80 = $9.00
    assert.are.equal(9.00, card.storage_snapshot(event(0, 10)))
  end)

  it("storage overflow beyond 20 billable pallets uses $1.40 rate", function()
    -- 30 pallets: 5 grace, 20 at $1.80 = $36.00, 5 at $1.40 = $7.00 → $43.00
    assert.are.equal(43.00, card.storage_snapshot(event(0, 30)))
  end)

  it("pack scales above 5 units: $1.00 + $0.10 per extra unit", function()
    -- 10 units: $1.00 + 5 × $0.10 = $1.50
    assert.are.equal(1.50, card.pack(event(10, 0)))
  end)

  it("return_fee includes per-unit re-inspection: $2.00 + $0.15/unit", function()
    -- 10 units: $2.00 + 10 × $0.15 = $3.50
    assert.are.equal(3.50, card.return_fee(event(10, 0)))
  end)
end)

-- ---------------------------------------------------------------------------
-- COASTAL-FRESH — cold-chain multiplier + rush factor
-- ---------------------------------------------------------------------------
describe("COASTAL-FRESH", function()
  local card = load_card("COASTAL-FRESH")

  it("pick without rush applies 1.30x cold-chain factor", function()
    -- 10 lb × $0.40 × 1.30 = $5.20
    assert.are.equal(5.20, card.pick(event(10, 0)))
  end)

  it("pick with rush applies cold (1.30) then rush (1.50)", function()
    -- 10 lb × $0.40 × 1.30 × 1.50 = $7.80
    assert.is_true(near(card.pick(event(10, 0, {is_rush=true})), 7.80))
  end)

  it("storage is fixed cold rate $3.20/pallet — no rush multiplier", function()
    assert.are.equal(16.00, card.storage_snapshot(event(0, 5)))
  end)

  it("receive without rush: qty × $0.14 × 1.30", function()
    assert.is_true(near(card.receive(event(10, 0)), 1.82))
  end)
end)

-- ---------------------------------------------------------------------------
-- ORION-HOMEGOODS — pallet-equivalent pricing + white-glove fee
-- ---------------------------------------------------------------------------
describe("ORION-HOMEGOODS", function()
  local card = load_card("ORION-HOMEGOODS")

  it("pick below white-glove threshold: no flat fee", function()
    -- 4 units = 1 pallet-eq, below threshold of 2: 1 × $4.00 = $4.00
    assert.are.equal(4.00, card.pick(event(4, 0)))
  end)

  it("pick at white-glove threshold adds $15.00 flat fee", function()
    -- 8 units = 2 pallet-eq: 2 × $4.00 + $15.00 = $23.00
    assert.are.equal(23.00, card.pick(event(8, 0)))
  end)

  it("ship uses pallet-equivalent rate $5.00/pallet-eq", function()
    -- 6 units = 2 pallet-eq: 2 × $5.00 = $10.00
    assert.are.equal(10.00, card.ship(event(6, 0)))
  end)

  it("return_fee always includes $15.00 white-glove fee", function()
    -- 4 units = 1 pallet-eq: 1 × $4.00 + $15.00 = $19.00
    assert.are.equal(19.00, card.return_fee(event(4, 0)))
  end)

  it("storage charges $4.00 per pallet", function()
    assert.are.equal(20.00, card.storage_snapshot(event(0, 5)))
  end)
end)
