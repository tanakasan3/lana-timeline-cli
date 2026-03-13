# lana-timeline-cli

CLI plumbing to query a **single-customer / single-loan timeline** from Lana Bank PostgreSQL `*_events_rollup` tables.

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
# edit .env and set DB connection + CUSTOMER_ID
make check
make timeline
```

Or pass ids directly:

```bash
make timeline CUSTOMER_ID=<customer-uuid>
make timeline CUSTOMER_ID=<customer-uuid> FACILITY_ID=<facility-uuid>
```

## Common commands

```bash
# full raw timeline
make timeline CUSTOMER_ID=<customer-uuid>

# CSV output for BI tools
make timeline-csv CUSTOMER_ID=<customer-uuid>

# executive milestone timeline
make milestones CUSTOMER_ID=<customer-uuid>

# create / refresh materialized view
make mv-create
make mv-refresh
```

## Output columns (main timeline)

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

- If `FACILITY_ID` is omitted, timeline queries auto-pick latest facility for `CUSTOMER_ID`.
- Assumes rollup tables exist (e.g., `core_credit_facility_events_rollup`, etc.).
- Amount units are raw DB units (e.g., cents/satoshis as stored).

## Files

- `sql/customer_loan_timeline.sql` – main event-level timeline query
- `sql/executive_milestones.sql` – milestone summary query
- `sql/create_timeline_mv.sql` – materialized view DDL
- `scripts/run_timeline.sh` – env-aware timeline runner
- `scripts/run_milestones.sh` – milestone runner
- `scripts/manage_mv.sh` – MV create/refresh/drop helper
- `.env.example` – connection + input variables
- `Makefile` – convenient commands
