# lana-timeline-cli

CLI plumbing to query customer/loan timelines from Lana Bank PostgreSQL `*_events_rollup` tables.

## Scope behavior (new)

`CUSTOMER_ID` and `FACILITY_ID` are both optional:

- leave both empty → iterate **all customers + all facilities**
- set `CUSTOMER_ID` only → all facilities for that customer
- set `FACILITY_ID` only → that facility (and its customer)
- set both → exact scoped timeline

Output is grouped sequentially by:

- `timeline_customer_id`
- `timeline_facility_id`
- `timeline_bucket` (human-readable separator key)

---

## What this gives you

- Chronological timeline across:
  - prospect/customer onboarding
  - credit facility proposal + approvals
  - pending facility collateralization
  - active credit facility lifecycle
  - disbursals, obligations, interest accrual, payments, allocations
  - collateral changes and liquidation-related events
  - deposit/withdrawal events for the same customer
- One SQL query (`sql/customer_loan_timeline.sql`) runnable from CLI.
- Executive milestone timeline (`sql/executive_milestones.sql`) with key business checkpoints.
- Materialized view plumbing (`sql/create_timeline_mv.sql`) for faster analytics.

## Quick start

```bash
cd lana-timeline-cli
make init
# edit .env and set DB connection; CUSTOMER_ID/FACILITY_ID are optional
make check
make timeline
```

## Common commands

```bash
# all customers/facilities
make timeline

# one customer, all facilities
make timeline CUSTOMER_ID=<customer-uuid>

# one facility
make timeline FACILITY_ID=<facility-uuid>

# exact customer+facility
make timeline CUSTOMER_ID=<customer-uuid> FACILITY_ID=<facility-uuid>

# CSV output for BI tools
make timeline-csv
make milestones-csv

# save outputs to ./out/
make timeline-save
make milestones-save

# build local HTML data explorer (timeline + milestones)
make explorer
# opens as latest at out/index.html

# serve ./out at http://127.0.0.1:8000 (open /index.html)
make serve-out
# optional: custom port
make serve-out PORT=9000

# executive milestone timeline (same optional filters)
make milestones

# create / refresh materialized view
make mv-create
make mv-refresh
```

## Output columns (main timeline)

- `timeline_customer_id`, `timeline_facility_id`, `timeline_bucket`
- `event_at`: recorded timestamp (primary ordering)
- `effective_at`: business-effective date/time when available
- `entity`, `entity_id`, `version`, `event_type`
- `customer_id`, `facility_id`
- `amount_usd_cents`, `collateral_sats`, `collateralization_ratio`, `price_usd`
- `status`
- `details` (JSONB payload with entity-specific fields)

## Materialized view

`make mv-create` creates `core_customer_loan_timeline_mv` with a per-facility snapshot summary:

- proposal/pending/facility references
- collateralization state and ratio
- total disbursed, total payments
- obligation counters (completed/defaulted)
- last event timestamps + snapshot timestamp

Then refresh anytime with:

```bash
make mv-refresh
```

## Notes

- Assumes rollup tables exist (e.g., `core_credit_facility_events_rollup`, etc.).
- Amount units are raw DB units (e.g., cents/satoshis as stored).

## Files

- `sql/customer_loan_timeline.sql` – main event-level timeline query
- `sql/executive_milestones.sql` – milestone summary query
- `sql/create_timeline_mv.sql` – materialized view DDL
- `scripts/run_timeline.sh` – env-aware timeline runner
- `scripts/run_milestones.sh` – milestone runner
- `scripts/manage_mv.sh` – MV create/refresh/drop helper
- `scripts/build_explorer.sh` + `scripts/build_explorer.py` – generate HTML data explorer from CSV dumps
- `scripts/serve_out.sh` – serve `./out` locally via Python HTTP server
- `.env.example` – connection + optional filters
- `Makefile` – convenient commands
