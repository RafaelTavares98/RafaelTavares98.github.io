--[[
  simulate.lua — standalone billing simulation for all five merchants.

  Runs the complete billing calculation pipeline in pure Lua, without Python
  or Docker. Demonstrates that the rate-card logic is self-contained and
  auditable by anyone who can open a terminal.

  Usage (from project root):
    lua rate_cards/simulate.lua

  Inside Docker:
    docker compose run --rm app lua rate_cards/simulate.lua

  What this script shows:
    - Lua as a standalone scripting language (not just an embedded sub-system)
    - dofile() for loading rate card modules at runtime
    - Lua tables as the event schema (same fields as the JSON events in Python)
    - First-class functions: rate card handlers are values stored in a table
    - String formatting with io.write / string.format
    - Table as a module cache (avoids reloading the same .lua file twice)
    - Variadic and iterator patterns from billing_utils

  Lua features specifically exercised:
    ipairs, pairs, math.ceil, math.max, string.rep, string.format,
    variadic functions (...), table as dict/array/namespace, closures,
    first-class functions as table values, dofile for module loading.
--]]

-- ── helpers ──────────────────────────────────────────────────────────────────

local function printf(fmt, ...) io.write(fmt:format(...)) end

local SEP  = string.rep("─", 72)
local SEP2 = string.rep("─", 72)

-- Rate card cache: load each .lua file at most once per simulation run.
-- Lua tables double as hashmaps — merchant_id is the key, the loaded
-- rate card table is the value.
local _card_cache = {}

local function load_card(merchant_id)
  if not _card_cache[merchant_id] then
    -- dofile executes the .lua file and returns whatever the file returns.
    -- Rate cards return a table of functions — that table becomes the card.
    _card_cache[merchant_id] = dofile("rate_cards/" .. merchant_id .. ".lua")
  end
  return _card_cache[merchant_id]
end

-- "return" is a reserved keyword in Lua, so rate cards cannot name a
-- function `return`. The convention in this codebase is `return_fee`.
local function handler_name(event_type)
  return event_type == "return" and "return_fee" or event_type
end

-- ── sample events ─────────────────────────────────────────────────────────────
--
-- These are Lua tables with the same field names as the JSON events the
-- Python generator produces. The billing functions only inspect the fields
-- they need — they are tolerant of extra or missing fields they don't use.
--
-- Chosen to exercise the non-trivial branches in each rate card:
--   NORDVIK:   pick at each of the three tiers + storage
--   HARLOW:    pick below and above the multi-unit cutoff + flat return
--   STONEGATE: storage in grace / normal / overflow zones + scaled pack
--   COASTAL:   pick without and with rush flag (compound multipliers)
--   ORION:     pick below and at the white-glove threshold + return

local EVENTS = {
  -- NORDVIK-LOGISTICS — three-tier pick
  { merchant_id="NORDVIK-LOGISTICS",  event_type="pick",             quantity=8,  metadata={pallet_count=0,  is_rush=false} },  -- tier-1 ($0.55)
  { merchant_id="NORDVIK-LOGISTICS",  event_type="pick",             quantity=25, metadata={pallet_count=0,  is_rush=false} },  -- tier-2 ($0.45)
  { merchant_id="NORDVIK-LOGISTICS",  event_type="pick",             quantity=50, metadata={pallet_count=0,  is_rush=false} },  -- tier-3 ($0.35)
  { merchant_id="NORDVIK-LOGISTICS",  event_type="storage_snapshot", quantity=0,  metadata={pallet_count=8,  is_rush=false} },

  -- HARLOW-ELECTRONICS — flat fees + multi-unit pick surcharge
  { merchant_id="HARLOW-ELECTRONICS", event_type="pick",             quantity=4,  metadata={pallet_count=0,  is_rush=false} },  -- below cutoff
  { merchant_id="HARLOW-ELECTRONICS", event_type="pick",             quantity=12, metadata={pallet_count=0,  is_rush=false} },  -- above cutoff (+$0.50 per extra)
  { merchant_id="HARLOW-ELECTRONICS", event_type="return",           quantity=1,  metadata={pallet_count=0,  is_rush=false} },  -- flat $12.00

  -- STONEGATE-APPAREL — grace-period storage + scalable pack
  { merchant_id="STONEGATE-APPAREL",  event_type="storage_snapshot", quantity=0,  metadata={pallet_count=3,  is_rush=false} },  -- fully within grace
  { merchant_id="STONEGATE-APPAREL",  event_type="storage_snapshot", quantity=0,  metadata={pallet_count=12, is_rush=false} },  -- above grace, below overflow
  { merchant_id="STONEGATE-APPAREL",  event_type="storage_snapshot", quantity=0,  metadata={pallet_count=30, is_rush=false} },  -- above overflow break
  { merchant_id="STONEGATE-APPAREL",  event_type="pack",             quantity=10, metadata={pallet_count=0,  is_rush=false} },  -- scalable pack

  -- COASTAL-FRESH — cold-chain × rush compound multipliers
  { merchant_id="COASTAL-FRESH",      event_type="pick",             quantity=40, metadata={pallet_count=0,  is_rush=false} },  -- cold only
  { merchant_id="COASTAL-FRESH",      event_type="pick",             quantity=40, metadata={pallet_count=0,  is_rush=true}  },  -- cold + rush
  { merchant_id="COASTAL-FRESH",      event_type="storage_snapshot", quantity=0,  metadata={pallet_count=5,  is_rush=true}  },  -- storage: rush ignored

  -- ORION-HOMEGOODS — pallet equivalents + white-glove fee
  { merchant_id="ORION-HOMEGOODS",    event_type="pick",             quantity=4,  metadata={pallet_count=0,  is_rush=false} },  -- 1 pallet-eq, below threshold
  { merchant_id="ORION-HOMEGOODS",    event_type="pick",             quantity=8,  metadata={pallet_count=0,  is_rush=false} },  -- 2 pallet-eq, triggers white-glove
  { merchant_id="ORION-HOMEGOODS",    event_type="return",           quantity=4,  metadata={pallet_count=0,  is_rush=false} },  -- always includes white-glove fee
}

-- ── simulation loop ───────────────────────────────────────────────────────────

printf("\nPortbill — Lua Billing Simulation\n%s\n", SEP)
printf("%-25s %-20s %6s %10s  %-14s  %s\n",
  "Merchant", "Event type", "Qty", "Amount ($)", "Rate card", "Notes")
printf("%s\n", SEP)

local grand_total   = 0
local prev_merchant = nil

for _, ev in ipairs(EVENTS) do
  -- Blank line between merchant blocks for readability
  if prev_merchant and ev.merchant_id ~= prev_merchant then
    printf("\n")
  end
  prev_merchant = ev.merchant_id

  local card    = load_card(ev.merchant_id)
  local handler = card[handler_name(ev.event_type)]

  if not handler then
    printf("%-25s %-20s  ERROR: no handler for '%s' in %s\n",
      ev.merchant_id, ev.event_type, ev.event_type, ev.merchant_id)
  else
    local amount = handler(ev)
    grand_total  = grand_total + amount

    -- Build an inline annotation so the reader sees *why* the amount
    -- is what it is without needing to open the rate card file.
    local note = ""
    if ev.event_type == "pick" then
      local qty = ev.quantity
      if ev.merchant_id == "NORDVIK-LOGISTICS" then
        local tier = qty <= 10 and "tier-1 $0.55" or (qty <= 30 and "tier-2 $0.45" or "tier-3 $0.35")
        note = tier
      elseif ev.merchant_id == "COASTAL-FRESH" then
        note = ev.metadata.is_rush and "×1.30 cold ×1.50 rush" or "×1.30 cold"
      elseif ev.merchant_id == "ORION-HOMEGOODS" then
        local peq = math.ceil(qty / 4)
        note = peq .. " pallet-eq" .. (peq >= 2 and " +$15 white-glove" or "")
      end
    elseif ev.event_type == "storage_snapshot" then
      local p = ev.metadata.pallet_count
      if ev.merchant_id == "STONEGATE-APPAREL" then
        local billable = math.max(0, p - 5)
        note = p .. " pallets → " .. billable .. " billable"
      elseif ev.merchant_id == "COASTAL-FRESH" then
        note = "rush flag ignored for storage"
      end
    end

    printf("%-25s %-20s %6d %10.4f  %-14s  %s\n",
      ev.merchant_id, ev.event_type, ev.quantity, amount, card.version, note)
  end
end

printf("\n%s\n", SEP2)
printf("%-52s %10.4f\n\n", "GRAND TOTAL", grand_total)

-- ── per-merchant summary ──────────────────────────────────────────────────────
--
-- Aggregate by merchant to show that the simulation mirrors what an analyst
-- would query in SQL: revenue per merchant per run.
--
-- Lua-specific: using a table as a dict (string keys → number values),
-- and `pairs` for unordered iteration (merchant order doesn't matter here).

local totals = {}
for _, ev in ipairs(EVENTS) do
  local card    = load_card(ev.merchant_id)
  local handler = card[handler_name(ev.event_type)]
  if handler then
    local amount = handler(ev)
    totals[ev.merchant_id] = (totals[ev.merchant_id] or 0) + amount
  end
end

-- Build a sorted list so the summary is deterministic
local merchants = {}
for m in pairs(totals) do merchants[#merchants + 1] = m end
table.sort(merchants)

printf("Revenue by merchant (this batch)\n%s\n", string.rep("─", 40))
for _, m in ipairs(merchants) do
  printf("  %-26s  %8.4f\n", m, totals[m])
end
printf("%s\n\n", string.rep("─", 40))
