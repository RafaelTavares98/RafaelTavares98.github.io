--[[
  billing_utils.lua — shared pricing primitives for Portbill rate cards.

  Why this module exists:
    Each merchant contract has a unique structure, but the *patterns* repeat:
    tiered pricing, stacked surcharges, grace-period storage. Without a shared
    library those patterns are re-implemented five times — and a logic fix
    (e.g. the precision of pallet rounding) has to be applied to five files.

  How to load from a rate card (CWD must be project root or /app in Docker):
    local U = dofile("rate_cards/lib/billing_utils.lua")

  Lua specifics shown here:
    - Module pattern: a local table `M` populated with functions, returned
      at the end. Callers get a first-class table of functions.
    - Variadic functions (...) for open-ended argument lists.
    - `ipairs` for ordered iteration of array-like tables.
    - `math.max` / `math.ceil` as examples of Lua's stdlib.
    - Tail-call-safe guard: none needed here (no recursion), but the pattern
      of early `return` guards is used throughout.
--]]

local M = {}

--- Tiered pick pricing: find the first tier whose max threshold covers `qty`
--- and return qty × that tier's rate.
---
--- @param qty        number   units to price
--- @param tiers      table    array of { max=N, rate=R } sorted ascending
--- @return           number
---
--- Example (NORDVIK three-tier pick):
---   local TIERS = { {max=10, rate=0.55}, {max=30, rate=0.45}, {max=math.huge, rate=0.35} }
---   U.tiered(25, TIERS)  →  11.25
function M.tiered(qty, tiers)
  for _, tier in ipairs(tiers) do
    if qty <= tier.max then
      return qty * tier.rate
    end
  end
  -- Fallback: should never fire if tiers ends with max=math.huge.
  -- Raising an error makes misconfigured tiers visible immediately
  -- rather than silently returning nil (which would produce a NaN charge).
  error("tiered(): qty " .. qty .. " exceeded all tier thresholds")
end

--- Stack one or more multipliers onto a base amount, left to right.
---
--- Used for compound surcharges where ORDER matters:
---   cold-chain (×1.30) is applied first, then rush (×1.50) on top.
---   U.with_surcharges(base, 1.30, 1.50) ≠ U.with_surcharges(base, 1.50, 1.30)
---   ... actually equal for multiplication, but the intent stays explicit.
---
--- @param base   number   pre-surcharge amount
--- @param ...    number   multipliers (variadic — pass as many as needed)
--- @return       number
function M.with_surcharges(base, ...)
  local amount = base
  -- `{...}` packs variadic args into a table so ipairs can iterate them.
  for _, factor in ipairs({...}) do
    amount = amount * factor
  end
  return amount
end

--- Grace-period storage with an optional overflow discount tier.
---
--- Logic:
---   1. First `grace_pallets` are free (SLA grace period in the contract).
---   2. Billable pallets up to `overflow_break` are billed at `base_rate`.
---   3. Billable pallets beyond `overflow_break` are billed at `overflow_rate`.
---
--- @param pallet_count   number   reported pallet count in the event
--- @param grace_pallets  number   how many pallets are free
--- @param base_rate      number   $/pallet for billable pallets in normal range
--- @param overflow_break number   (optional) pallet count that triggers discount
--- @param overflow_rate  number   (optional) $/pallet beyond overflow_break
--- @return               number
---
--- Example (STONEGATE: 5 free, $1.80 up to 20 billable, $1.40 beyond):
---   U.storage_with_grace(30, 5, 1.80, 20, 1.40)  →  43.00
---   — 25 billable pallets: 20 × $1.80 = $36.00 + 5 × $1.40 = $7.00
function M.storage_with_grace(pallet_count, grace_pallets, base_rate,
                               overflow_break, overflow_rate)
  local billable = math.max(0, pallet_count - grace_pallets)
  if overflow_break and billable > overflow_break then
    return (overflow_break * base_rate)
         + ((billable - overflow_break) * (overflow_rate or base_rate))
  end
  return billable * base_rate
end

--- Convert a unit quantity to pallet equivalents (ceiling division).
---
--- Ceiling is correct for billing: 5 units in a 4-unit-per-pallet system
--- still occupies 2 pallet positions and should be billed as 2.
---
--- @param qty              number  unit count
--- @param units_per_pallet number  how many units fit in one pallet position
--- @return                 number  pallet equivalents (integer)
function M.pallet_eq(qty, units_per_pallet)
  return math.ceil(qty / units_per_pallet)
end

--- Round a currency amount to 4 decimal places (billing precision).
---
--- Lua's `%f` format already rounds for display, but storing a rounded
--- value avoids accumulating floating-point drift across many charges
--- when a downstream system aggregates them.
---
--- @param amount  number
--- @return        number
function M.round4(amount)
  return math.floor(amount * 10000 + 0.5) / 10000
end

return M
