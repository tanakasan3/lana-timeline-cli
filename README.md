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

## Output columns

- `event_at`: recorded timestamp (primary ordering)
- `effective_at`: business-effective date/time when available
- `entity`, `entity_id`, `version`, `event_type`
- `customer_id`, `facility_id`
- `amount_usd_cents`, `collateral_sats`, `collateralization_ratio`, `price_usd`
- `status`
- `details` (JSONB payload with entity-specific fields)

## Notes

- If `FACILITY_ID` is omitted, the query auto-picks latest facility for `CUSTOMER_ID`.
- Assumes rollup tables exist (e.g., `core_credit_facility_events_rollup`, etc.).
- Amount units are raw DB units (e.g., cents/satoshis as stored).

## Files

- `sql/customer_loan_timeline.sql` – main timeline query
- `scripts/run_timeline.sh` – env-aware runner
- `.env.example` – connection + input variables
- `Makefile` – convenient commands
