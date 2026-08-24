# CLAUDE.md — Project Source of Truth

> **DIRECTIVE #1 — NON-NEGOTIABLE:**
> Read and update this file before making any change to the project.
> This is the historical record and the single source of truth for the project.
> Every phase completion, every architectural decision, every deviation from the plan must be logged here.

---

## What This Project Is

**portbill** is a warehouse billing pipeline built as a portfolio project for a
**Data Analyst — Billing Systems** interview. The target company is migrating to a new billing
system (S1B) that processes warehouse activity logs and converts them into charges via Lua scripts.

**Scope: data engineering only — generation and ingestion.**
The output is a Postgres database with clean, structured billing data ready for consumption.
Visualization (Power BI) is handled externally by the analyst and is out of scope here.

This project proves, in real working code, that the candidate can:
- Write and debug Lua to apply charges based on activity logs
- Work with JSON activity logs and WMS event triggers
- Reconcile data, identify discrepancies, and document bugs
- Build a simple, auditable data pipeline
- Operate in a cloud environment with Docker

---

## Non-Negotiable Principles

| Principle | Rule |
|---|---|
| **Simplicity over elegance** | When in doubt, choose the simpler solution. This is an MVP, not a master's thesis. |
| **Pragmatic TDD** | Write tests for every function that does calculation. Skip tests for I/O and orchestration loops. Write the test before the calculation code. |
| **Explicit pair programming** | Stop at decision points and ask before proceeding. Never take large decisions silently. |
| **Security** | All credentials (Oracle keys, Postgres passwords) use environment variables and `.env` (in `.gitignore`) from the first commit. Zero hardcoded credentials, ever. |
| **Zero cost** | All infrastructure must fit within Oracle Cloud Always Free tier. No credit card, no trial. |
| **Verifiable free tiers** | Before adding any dependency or service, confirm it is free without a trial. Open source local > free SaaS tier > anything that asks for an email. |

---

## Mandatory Stack

| Layer | Technology | Reason |
|---|---|---|
| Calculation language | Lua 5.4 | Mirrors the actual S1B billing system |
| Application | Python 3.11 | Candidate's existing skill, good ecosystem |
| Database | Postgres 16 (container) | Industry standard, free, handles JSONB, Power BI connects natively |
| Containerization | Docker Compose | One command to run everything |
| Cloud | Oracle Cloud Always Free — VM ARM Ampere A1 | Zero cost, real cloud deployment |
| CI/CD | GitHub Actions | Free for public repos, well-known |
| Version control | Git, public GitHub repo | Required |

**Do NOT introduce:** Airflow, dbt, Kafka, Kubernetes, Terraform, AWS, BigQuery, Snowflake,
Spark, Airbyte, Dagster, Streamlit, or any tool that requires more than 30 minutes of setup for an MVP.

---

## Architecture

Two services. One command. One responsibility each.

```
┌─────────────────────────────────────┐
│  app  (single container)            │
│                                     │
│  generate_events()                  │
│       ↓  in-memory                  │
│  validate_events()                  │
│       ↓                             │
│  apply_lua_rate_cards()             │
│       ↓                             │
│  write_to_postgres()                │
│                                     │
│  runs in a continuous loop          │
│  logs audit data to /data/audit/    │
└──────────────┬──────────────────────┘
               │
               ▼
         ┌─────────┐
         │postgres │  events, charges, errors
         │  :5432  │  ← Power BI (external) connects here
         └─────────┘
```

`docker compose up` starts both services. The app waits for Postgres to be healthy, then begins the loop.

---

## Folder Structure

```
portbill/
├── CLAUDE.md                    ← you are here — read before any change
├── docker-compose.yml           ← two services: app + postgres
├── Dockerfile                   ← single Dockerfile for the app
├── .env.example
├── .gitignore
├── README.md
├── src/
│   ├── main.py                  ← entry point: orchestrates the full loop
│   ├── generator.py             ← generate_event(), inject_error()
│   ├── validators.py            ← validate_event() → list[Error]
│   ├── lua_runner.py            ← loads rate card, calculates charge
│   └── tests/
│       ├── test_generator.py
│       ├── test_validators.py
│       └── test_lua_runner.py
├── rate_cards/
│   ├── ACME-FOODS.lua
│   ├── BETA-RETAIL.lua
│   ├── GAMMA-OUTDOOR.lua
│   └── tests/
│       └── test_rate_cards.lua
├── sql/
│   └── init.sql                 ← schema applied on Postgres startup
└── .github/
    └── workflows/
        └── ci.yml
```

No separate `generator/` or `pipeline/` folders. All application logic lives in `src/`.
No `dashboard/` folder. Power BI is the analyst's responsibility, out of scope.

---

## Event Schema (WMS-like)

Based on real 3PL market standards (ShipHero, ShipBob). Events represent warehouse activities
that become billable charges.

```json
{
  "event_id": "EVT-20260426-00041923",
  "merchant_id": "ACME-FOODS",
  "warehouse_id": "WH-DAL-01",
  "event_type": "pick",
  "timestamp": "2026-04-26T14:32:11.482Z",
  "order_id": "ORD-9981724",
  "sku": "SKU-COFFEE-12OZ",
  "quantity": 3,
  "unit_of_measure": "each",
  "metadata": {
    "zone": "A",
    "wave_id": "WAVE-2026-04-26-AM",
    "is_rush": false
  }
}
```

**Event types:** `receive`, `putaway`, `pick`, `pack`, `ship`, `return`, `storage_snapshot`

**Merchants (fixed):**
- `ACME-FOODS` — standard per-unit pricing
- `BETA-RETAIL` — tiered pricing / volume discount
- `GAMMA-OUTDOOR` — flat fees + storage grace period

---

## Injected Errors (3% probability)

| Category | Description |
|---|---|
| `schema` | Missing required field or wrong type |
| `business_logic` | Pick without matching pack, return without original ship, negative/zero quantity |
| `reference` | `merchant_id` not found in any rate card |
| `duplicate` | Same `event_id` repeated |
| `time_anomaly` | Timestamp in the future or outside plausible operational window |

The generator records injected error counts in `/data/audit/generator_audit.log`.
The pipeline computes **detection rate** (injected vs. captured) and writes it to the `audit_summary` table — a key metric for anyone querying the database.

---

## Rate Card Structure (Lua)

Each merchant has a file `rate_cards/{merchant_id}.lua`:

```lua
-- rate_cards/ACME-FOODS.lua
return {
  receive   = function(event) return event.quantity * 0.10 end,
  putaway   = function(event) return event.quantity * 0.05 end,
  pick      = function(event) return event.quantity * 0.50 end,
  pack      = function(event) return 1.25 end,
  ship      = function(event) return 2.00 end,
  return_fee = function(event) return 3.00 end,
  storage_snapshot = function(event)
    return (event.metadata.pallet_count or 0) * 2.00
  end,
  cpi_adjustment = 1.043,
}
```

At least one merchant must have a conditional rule (volume discount or grace period)
to make Lua tests more meaningful.

---

## Postgres Schema

Minimal tables. No normalization overengineering. No dimensional modeling.

```sql
CREATE TABLE events (
  event_id          TEXT PRIMARY KEY,
  merchant_id       TEXT,
  warehouse_id      TEXT,
  event_type        TEXT,
  event_timestamp   TIMESTAMPTZ,
  raw_payload       JSONB,
  ingested_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE charges (
  charge_id         BIGSERIAL PRIMARY KEY,
  event_id          TEXT REFERENCES events(event_id),
  merchant_id       TEXT,
  amount            NUMERIC(12, 4),
  rate_card_version TEXT,
  calculated_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE errors (
  error_id      BIGSERIAL PRIMARY KEY,
  event_id      TEXT,
  category      TEXT,  -- schema, business_logic, reference, duplicate, time_anomaly
  details       TEXT,
  raw_payload   JSONB,
  detected_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Audit summary written by the pipeline at the end of each run
CREATE TABLE audit_summary (
  run_id          BIGSERIAL PRIMARY KEY,
  run_at          TIMESTAMPTZ DEFAULT NOW(),
  events_generated  INT,
  errors_injected   INT,
  errors_detected   INT,
  detection_rate    NUMERIC(5, 2)  -- percentage
);

CREATE INDEX idx_events_merchant   ON events(merchant_id);
CREATE INDEX idx_events_timestamp  ON events(event_timestamp);
CREATE INDEX idx_errors_category   ON errors(category);
```

---

## Testing Rules

### What MUST have tests
- Every Lua rate card function (using `busted`)
- `validators.py` — all error categories
- `inject_error()` in `generator.py`
- `lua_runner.py` — charge calculation logic

### What does NOT need tests
- `main.py` (orchestration loop)
- Postgres connections
- Dockerfiles and configuration

### Python test pattern
```python
def test_validator_detects_negative_quantity():
    event = {"quantity": -1, ...}
    errors = validate_event(event)
    assert any(e.category == "business_logic" for e in errors)
```

Direct. No complex fixtures. No elaborate mocks.

---

## CI/CD (GitHub Actions)

Runs on every push:
1. Python lint (`ruff`)
2. Python tests (`pytest`)
3. Lua lint (`luacheck`)
4. Lua tests (`busted`)
5. Docker build (no deploy)

No automatic deploy to Oracle. Deploy is manual via SSH, once.

---

## Complete Roadmap

### Phase 1 — Foundation ✅
- [x] `.env` with working local defaults
- [x] `sql/init.sql` — 4 tables + 3 indexes applied on Postgres startup
- [x] `docker-compose.yml` — `app` + `postgres` services
- [x] `Dockerfile` — Python 3.11 + Lua 5.4 + lupa, `PYTHONUNBUFFERED=1`
- [x] `src/main.py` — Postgres connection smoke test
- [x] `docker compose up --build` confirmed working

---

### Phase 2 — Generator ✅
- [x] `src/generator.py` — `generate_event(merchant_id, event_type) -> dict`
- [x] `src/generator.py` — `inject_error(event, category) -> dict` (5 categories)
- [x] `src/__init__.py` + `src/tests/__init__.py` — package structure for pytest
- [x] `src/tests/test_generator.py` — 9 tests, all error categories covered
- [x] `pytest` green inside the container — 9 passed in 0.05s

---

### Phase 3 — Lua Rate Cards ✅
- [x] `rate_cards/ACME-FOODS.lua` — standard per-unit pricing
- [x] `rate_cards/BETA-RETAIL.lua` — tiered pricing with volume discount
- [x] `rate_cards/GAMMA-OUTDOOR.lua` — flat fees + storage grace period
- [x] `rate_cards/tests/test_rate_cards.lua` — busted tests for all 3 cards + edge cases
- [x] `busted` green — 17 passed in 0.009s

---

### Phase 4 — Pipeline ✅
- [x] `src/validators.py` — `validate_event(event, seen_ids) -> list[ValidationError]`, all 5 categories
- [x] `src/tests/test_validators.py` — 6 tests (one per error category + valid event)
- [x] `src/lua_runner.py` — load rate card via `lupa`, recursive dict→Lua table conversion
- [x] `src/tests/test_lua_runner.py` — 4 tests with inline test rate card via tmp_path
- [x] `src/main.py` — real pipeline: generate batch → validate → apply Lua rate card → write to Postgres → write `audit_summary`; duplicate detection via `seen_ids` set
- [ ] All tests green inside Docker ← confirm with `docker compose run --rm app pytest`

---

### Phase 5 — Oracle Cloud Deploy
- [ ] Create Oracle Cloud Always Free account
- [ ] Provision VM ARM Ampere A1 (4 OCPU, 24 GB RAM)
- [ ] Configure firewall: port 22 (SSH) + port 5432 (Postgres for Power BI)
- [ ] Install Docker + Docker Compose on VM
- [ ] Clone repo, create `.env`, `docker compose up -d`
- [ ] Confirm port 5432 reachable from local Power BI Desktop

---

### Phase 6 — CI/CD + Git + Polish
- [ ] `.gitignore` — `.env`, `data/`, `__pycache__/`, `*.pyc`
- [ ] `requirements.txt` updated with `pytest` + `ruff`
- [ ] `.github/workflows/ci.yml` — ruff lint, pytest, luacheck, busted, docker build
- [ ] `README.md` — title, why, architecture diagram (Mermaid), 3-command quickstart, stack decisions, "how I'd extend this"
- [ ] Push to GitHub public repo
- [ ] CI green badge in README

---

## Decision Log

> Record every non-obvious architectural or technical decision here with date and rationale.

| Date | Decision | Rationale |
|---|---|---|
| 2026-04-26 | Project initialized | Starting fresh per portfolio brief |
| 2026-04-26 | Replaced Streamlit with Power BI Desktop | Power BI is directly relevant to the target role; no Pro license needed for portfolio; Postgres :5432 is the integration point |
| 2026-04-26 | Consolidated to a single app container | Generator and pipeline run in the same container; removes inter-container complexity; two services total (app + postgres); cleaner for a portfolio MVP focused on data engineering |
| 2026-04-26 | Visualization out of scope | Power BI dashboard built by the analyst separately; project scope is generation + ingestion only |
| 2026-04-26 | No `.env.example` | A template file with placeholder values is effectively a TODO in the codebase. Using a real `.env` with working local defaults instead. Gitignored when git is set up. |
| 2026-04-26 | Git deferred | Git setup (`.gitignore`, remote) added after the core pipeline is working. Not needed to prove data engineering capability. |
| 2026-04-26 | `PYTHONUNBUFFERED=1` in Dockerfile | Python buffers stdout by default; without this, `docker logs` shows nothing. Standard fix for Python in Docker. |
| 2026-04-26 | `busted` + `luacheck` installed via `luarocks` in Dockerfile | No host-side tooling required; all Lua tests run inside the container. `luarocks` defaults to Lua 5.1 for its own runtime, but rate card code uses only arithmetic and tables — compatible with both 5.1 and 5.4. `lupa` (the pipeline bridge) continues to use Lua 5.4. |

---

## Success Criteria

The project is **done** when:
- [ ] `docker compose up` starts cleanly from a fresh clone in under 2 minutes
- [ ] Postgres has populated `events`, `charges`, `errors`, and `audit_summary` tables after the first run
- [ ] Port 5432 is accessible from Power BI Desktop (local and on Oracle Cloud)
- [ ] README is readable in 60 seconds
- [ ] CI is green on GitHub
- [ ] ≥80% of calculation functions have tests
- [ ] Lua, Docker, and Postgres appear live — not just as CV bullets

The project is **NOT done** if:
- There is a `TODO` in the code
- There is a hardcoded credential (even a test one)
- Any container fails to start
- README says "work in progress"

---

## Pair Programming Protocol

- Announce what will be built at the start of each phase, and confirm before starting
- Stop and ask before any non-obvious technical decision
- When writing a test, briefly explain what it proves (one sentence)
- After each phase: run tests, show results, confirm readiness for the next phase
- If a new feature request grows the scope, ask: include now or save for "How I'd extend this"?
- Do not write more than 80 lines of code without checking in
- Do not create more than 3 new files without checking in
