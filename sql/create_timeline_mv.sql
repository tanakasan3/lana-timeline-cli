-- Materialized view for faster timeline analytics across facilities
-- Rebuild with: REFRESH MATERIALIZED VIEW core_customer_loan_timeline_mv;

CREATE MATERIALIZED VIEW IF NOT EXISTS core_customer_loan_timeline_mv AS
WITH
proposal_latest AS (
  SELECT DISTINCT ON (id)
    id, customer_id, amount, status, modified_at
  FROM core_credit_facility_proposal_events_rollup
  ORDER BY id, version DESC
),
pending_latest AS (
  SELECT DISTINCT ON (id)
    id, customer_id, credit_facility_proposal_id, amount, collateral, collateralization_ratio,
    collateralization_state, modified_at
  FROM core_pending_credit_facility_events_rollup
  ORDER BY id, version DESC
),
facility_latest AS (
  SELECT DISTINCT ON (id)
    id, customer_id, pending_credit_facility_id, amount, collateral, collateralization_ratio,
    collateralization_state, outstanding, modified_at
  FROM core_credit_facility_events_rollup
  ORDER BY id, version DESC
),
obligation_latest AS (
  SELECT DISTINCT ON (id)
    id, amount, due_amount, overdue_amount, defaulted_amount,
    is_due_recorded, is_overdue_recorded, is_defaulted_recorded, is_completed, modified_at
  FROM core_obligation_events_rollup
  ORDER BY id, version DESC
),
facility_rollup AS (
  SELECT
    f.id AS facility_id,
    f.customer_id,
    f.amount AS facility_amount_usd_cents,
    f.collateral AS collateral_sats,
    f.collateralization_ratio,
    f.collateralization_state,
    f.outstanding,
    f.modified_at AS facility_last_event_at,
    p.id AS proposal_id,
    p.status AS proposal_status,
    p.modified_at AS proposal_last_event_at,
    pd.id AS pending_id,
    pd.collateralization_state AS pending_collateral_state,
    pd.modified_at AS pending_last_event_at
  FROM facility_latest f
  LEFT JOIN pending_latest pd ON pd.id = f.pending_credit_facility_id
  LEFT JOIN proposal_latest p ON p.id = pd.credit_facility_proposal_id
),
facility_ops AS (
  SELECT
    f.id AS facility_id,
    COALESCE(SUM(d.amount), 0)::bigint AS total_disbursed_usd_cents,
    COUNT(DISTINCT d.id)::int AS disbursal_count,
    COALESCE(SUM(pay.amount), 0)::bigint AS total_payments_usd_cents,
    COUNT(DISTINCT pay.id)::int AS payment_count,
    COUNT(DISTINCT o.id)::int AS obligation_count,
    COALESCE(SUM(CASE WHEN o.is_completed THEN 1 ELSE 0 END), 0)::int AS obligations_completed,
    COALESCE(SUM(CASE WHEN o.is_defaulted_recorded THEN 1 ELSE 0 END), 0)::int AS obligations_defaulted
  FROM facility_latest f
  LEFT JOIN core_disbursal_events_rollup d ON d.facility_id = f.id
  LEFT JOIN core_payment_allocation_events_rollup pa ON pa.obligation_id = d.obligation_id
  LEFT JOIN core_payment_events_rollup pay ON pay.id = pa.payment_id
  LEFT JOIN obligation_latest o ON o.id = d.obligation_id
  GROUP BY f.id
)
SELECT
  fr.customer_id,
  fr.facility_id,
  fr.proposal_id,
  fr.pending_id,
  fr.facility_amount_usd_cents,
  fr.collateral_sats,
  fr.collateralization_ratio,
  fr.collateralization_state,
  fr.outstanding,
  fr.proposal_status,
  fr.pending_collateral_state,
  ops.total_disbursed_usd_cents,
  ops.disbursal_count,
  ops.total_payments_usd_cents,
  ops.payment_count,
  ops.obligation_count,
  ops.obligations_completed,
  ops.obligations_defaulted,
  fr.proposal_last_event_at,
  fr.pending_last_event_at,
  fr.facility_last_event_at,
  now()::timestamptz AS snapshot_at
FROM facility_rollup fr
LEFT JOIN facility_ops ops ON ops.facility_id = fr.facility_id;

CREATE UNIQUE INDEX IF NOT EXISTS core_customer_loan_timeline_mv_pk
  ON core_customer_loan_timeline_mv (facility_id);

CREATE INDEX IF NOT EXISTS core_customer_loan_timeline_mv_customer_idx
  ON core_customer_loan_timeline_mv (customer_id);
