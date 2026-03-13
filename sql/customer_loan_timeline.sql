\set QUIET 1

WITH
params AS (
  SELECT
    (:'customer_id')::uuid AS customer_id,
    NULLIF(:'facility_id', '')::uuid AS facility_id_in
),
facility_pick AS (
  SELECT COALESCE(
    (SELECT facility_id_in FROM params),
    (
      SELECT f.id
      FROM core_credit_facility_events_rollup f, params p
      WHERE f.customer_id = p.customer_id
      ORDER BY f.modified_at DESC, f.version DESC
      LIMIT 1
    )
  ) AS facility_id
),
facility_ids AS (
  SELECT DISTINCT f.id AS facility_id, f.pending_credit_facility_id, f.customer_id
  FROM core_credit_facility_events_rollup f
  JOIN facility_pick fp ON fp.facility_id = f.id
),
pending_ids AS (
  SELECT DISTINCT p.id AS pending_id, p.credit_facility_proposal_id, p.customer_id, p.approval_process_id
  FROM core_pending_credit_facility_events_rollup p
  JOIN facility_ids f ON f.pending_credit_facility_id = p.id
),
proposal_ids AS (
  SELECT DISTINCT pr.id AS proposal_id, pr.customer_id, pr.approval_process_id
  FROM core_credit_facility_proposal_events_rollup pr
  JOIN pending_ids p ON p.credit_facility_proposal_id = pr.id
),
disbursal_ids AS (
  SELECT DISTINCT d.id AS disbursal_id, d.facility_id, d.obligation_id, d.approval_process_id
  FROM core_disbursal_events_rollup d
  JOIN facility_ids f ON f.facility_id = d.facility_id
),
obligation_ids AS (
  SELECT obligation_id FROM disbursal_ids WHERE obligation_id IS NOT NULL
  UNION
  SELECT DISTINCT i.obligation_id
  FROM core_interest_accrual_cycle_events_rollup i
  JOIN facility_ids f ON f.facility_id = i.facility_id
  WHERE i.obligation_id IS NOT NULL
),
approval_process_ids AS (
  SELECT approval_process_id FROM proposal_ids WHERE approval_process_id IS NOT NULL
  UNION
  SELECT approval_process_id FROM pending_ids WHERE approval_process_id IS NOT NULL
  UNION
  SELECT approval_process_id FROM disbursal_ids WHERE approval_process_id IS NOT NULL
),
timeline AS (
  SELECT
    p.modified_at AS event_at,
    NULL::timestamptz AS effective_at,
    'prospect'::text AS entity,
    p.id AS entity_id,
    p.version,
    p.event_type,
    NULL::uuid AS customer_id,
    NULL::uuid AS facility_id,
    NULL::bigint AS amount_usd_cents,
    NULL::bigint AS collateral_sats,
    NULL::numeric AS collateralization_ratio,
    NULL::bigint AS price_usd,
    p.stage::text AS status,
    jsonb_build_object(
      'public_id', p.public_id,
      'party_id', p.party_id,
      'applicant_id', p.applicant_id,
      'customer_type', p.customer_type,
      'is_kyc_approved', p.is_kyc_approved,
      'verification_url', p.url
    ) AS details
  FROM core_prospect_events_rollup p
  JOIN params x ON p.id = x.customer_id

  UNION ALL

  SELECT
    c.modified_at,
    NULL,
    'customer',
    c.id,
    c.version,
    c.event_type,
    c.id,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    c.status::text,
    jsonb_build_object(
      'public_id', c.public_id,
      'party_id', c.party_id,
      'customer_type', c.customer_type,
      'kyc_level', c.level,
      'conversion', c.conversion
    )
  FROM core_customer_events_rollup c
  JOIN params x ON c.id = x.customer_id

  UNION ALL

  SELECT
    pr.modified_at,
    NULL,
    'credit_facility_proposal',
    pr.id,
    pr.version,
    pr.event_type,
    pr.customer_id,
    NULL,
    pr.amount,
    NULL,
    NULL,
    NULL,
    pr.status::text,
    jsonb_build_object(
      'approval_process_id', pr.approval_process_id,
      'customer_type', pr.customer_type,
      'custodian_id', pr.custodian_id,
      'terms', pr.terms,
      'disbursal_credit_account_id', pr.disbursal_credit_account_id
    )
  FROM core_credit_facility_proposal_events_rollup pr
  JOIN proposal_ids pid ON pid.proposal_id = pr.id

  UNION ALL

  SELECT
    ap.modified_at,
    NULL,
    'approval_process',
    ap.id,
    ap.version,
    ap.event_type,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    CASE WHEN ap.is_concluded THEN 'concluded' ELSE 'open' END,
    jsonb_build_object(
      'process_type', ap.process_type,
      'target_ref', ap.target_ref,
      'approved', ap.approved,
      'approver_ids', ap.approver_ids,
      'denier_ids', ap.denier_ids,
      'deny_reasons', ap.deny_reasons,
      'policy_id', ap.policy_id,
      'rules', ap.rules
    )
  FROM core_approval_process_events_rollup ap
  JOIN approval_process_ids aid ON aid.approval_process_id = ap.id

  UNION ALL

  SELECT
    p.modified_at,
    NULL,
    'pending_credit_facility',
    p.id,
    p.version,
    p.event_type,
    p.customer_id,
    NULL,
    p.amount,
    p.collateral,
    p.collateralization_ratio,
    p.price,
    p.collateralization_state::text,
    jsonb_build_object(
      'credit_facility_proposal_id', p.credit_facility_proposal_id,
      'approval_process_id', p.approval_process_id,
      'collateral_id', p.collateral_id,
      'terms', p.terms,
      'is_completed', p.is_completed
    )
  FROM core_pending_credit_facility_events_rollup p
  JOIN pending_ids pid ON pid.pending_id = p.id

  UNION ALL

  SELECT
    f.modified_at,
    f.activated_at,
    'credit_facility',
    f.id,
    f.version,
    f.event_type,
    f.customer_id,
    f.id,
    f.amount,
    f.collateral,
    f.collateralization_ratio,
    f.price,
    f.collateralization_state::text,
    jsonb_build_object(
      'pending_credit_facility_id', f.pending_credit_facility_id,
      'public_id', f.public_id,
      'outstanding', f.outstanding,
      'maturity_date', f.maturity_date,
      'terms', f.terms,
      'trigger_price', f.trigger_price,
      'is_matured', f.is_matured,
      'is_completed', f.is_completed
    )
  FROM core_credit_facility_events_rollup f
  JOIN facility_ids fid ON fid.facility_id = f.id

  UNION ALL

  SELECT
    d.modified_at,
    d.due_date,
    'disbursal',
    d.id,
    d.version,
    d.event_type,
    NULL,
    d.facility_id,
    d.amount,
    NULL,
    NULL,
    NULL,
    d.status::text,
    jsonb_build_object(
      'approval_process_id', d.approval_process_id,
      'approved', d.approved,
      'obligation_id', d.obligation_id,
      'public_id', d.public_id,
      'overdue_date', d.overdue_date,
      'liquidation_date', d.liquidation_date,
      'ledger_tx_ids', d.ledger_tx_ids
    )
  FROM core_disbursal_events_rollup d
  JOIN disbursal_ids did ON did.disbursal_id = d.id

  UNION ALL

  SELECT
    i.modified_at,
    i.accrued_at,
    'interest_accrual_cycle',
    i.id,
    i.version,
    i.event_type,
    NULL,
    i.facility_id,
    i.amount,
    NULL,
    NULL,
    NULL,
    CASE WHEN i.is_interest_accruals_posted THEN 'posted' ELSE 'open' END,
    jsonb_build_object(
      'idx', i.idx,
      'period', i.period,
      'total', i.total,
      'obligation_id', i.obligation_id,
      'terms', i.terms,
      'ledger_tx_ids', i.ledger_tx_ids
    )
  FROM core_interest_accrual_cycle_events_rollup i
  JOIN facility_ids f ON f.facility_id = i.facility_id

  UNION ALL

  SELECT
    o.modified_at,
    o.due_date,
    'obligation',
    o.id,
    o.version,
    o.event_type,
    NULL,
    NULL,
    o.amount,
    NULL,
    NULL,
    NULL,
    CASE
      WHEN o.is_completed THEN 'completed'
      WHEN o.is_defaulted_recorded THEN 'defaulted'
      WHEN o.is_overdue_recorded THEN 'overdue'
      WHEN o.is_due_recorded THEN 'due'
      ELSE 'open'
    END,
    jsonb_build_object(
      'obligation_type', o.obligation_type,
      'beneficiary_id', o.beneficiary_id,
      'due_amount', o.due_amount,
      'overdue_amount', o.overdue_amount,
      'defaulted_amount', o.defaulted_amount,
      'payment_id', o.payment_id,
      'payment_allocation_amount', o.payment_allocation_amount,
      'reference', o.reference,
      'payment_allocation_ids', o.payment_allocation_ids,
      'ledger_tx_ids', o.ledger_tx_ids
    )
  FROM core_obligation_events_rollup o
  JOIN obligation_ids oid ON oid.obligation_id = o.id

  UNION ALL

  SELECT
    p.modified_at,
    NULL,
    'payment',
    p.id,
    p.version,
    p.event_type,
    NULL,
    NULL,
    p.amount,
    NULL,
    NULL,
    NULL,
    NULL,
    jsonb_build_object(
      'beneficiary_id', p.beneficiary_id,
      'effective', p.effective,
      'ledger_tx_id', p.ledger_tx_id,
      'payment_source_account_id', p.payment_source_account_id,
      'facility_payment_holding_account_id', p.facility_payment_holding_account_id,
      'facility_uncovered_outstanding_account_id', p.facility_uncovered_outstanding_account_id
    )
  FROM core_payment_events_rollup p
  WHERE p.id IN (
    SELECT DISTINCT o.payment_id
    FROM core_obligation_events_rollup o
    JOIN obligation_ids oid ON oid.obligation_id = o.id
    WHERE o.payment_id IS NOT NULL
  )

  UNION ALL

  SELECT
    pa.modified_at,
    NULL,
    'payment_allocation',
    pa.id,
    pa.version,
    pa.event_type,
    NULL,
    NULL,
    pa.amount,
    NULL,
    NULL,
    NULL,
    NULL,
    jsonb_build_object(
      'payment_id', pa.payment_id,
      'obligation_id', pa.obligation_id,
      'obligation_type', pa.obligation_type,
      'payment_allocation_idx', pa.payment_allocation_idx,
      'beneficiary_id', pa.beneficiary_id,
      'effective', pa.effective,
      'ledger_tx_id', pa.ledger_tx_id
    )
  FROM core_payment_allocation_events_rollup pa
  JOIN obligation_ids oid ON oid.obligation_id = pa.obligation_id

  UNION ALL

  SELECT
    c.modified_at,
    NULL,
    'collateral',
    c.id,
    c.version,
    c.event_type,
    NULL,
    c.secured_loan_id,
    c.amount,
    c.collateral_amount,
    NULL,
    NULL,
    NULL,
    jsonb_build_object(
      'abs_diff', c.abs_diff,
      'direction', c.direction,
      'liquidation_id', c.liquidation_id,
      'payment_id', c.payment_id,
      'custody_wallet_id', c.custody_wallet_id,
      'ledger_tx_ids', c.ledger_tx_ids
    )
  FROM core_collateral_events_rollup c
  JOIN facility_ids f ON f.facility_id = c.secured_loan_id

  UNION ALL

  SELECT
    d.modified_at,
    NULL,
    'deposit',
    d.id,
    d.version,
    d.event_type,
    NULL,
    NULL,
    d.amount,
    NULL,
    NULL,
    NULL,
    d.status::text,
    jsonb_build_object(
      'deposit_account_id', d.deposit_account_id,
      'public_id', d.public_id,
      'reference', d.reference,
      'ledger_tx_ids', d.ledger_tx_ids
    )
  FROM core_deposit_events_rollup d
  WHERE d.deposit_account_id IN (
    SELECT DISTINCT da.id
    FROM core_deposit_account_events_rollup da
    JOIN params p ON p.customer_id = da.account_holder_id
  )

  UNION ALL

  SELECT
    w.modified_at,
    NULL,
    'withdrawal',
    w.id,
    w.version,
    w.event_type,
    NULL,
    NULL,
    w.amount,
    NULL,
    NULL,
    NULL,
    w.status::text,
    jsonb_build_object(
      'deposit_account_id', w.deposit_account_id,
      'approval_process_id', w.approval_process_id,
      'public_id', w.public_id,
      'approved', w.approved,
      'reference', w.reference,
      'ledger_tx_ids', w.ledger_tx_ids
    )
  FROM core_withdrawal_events_rollup w
  WHERE w.deposit_account_id IN (
    SELECT DISTINCT da.id
    FROM core_deposit_account_events_rollup da
    JOIN params p ON p.customer_id = da.account_holder_id
  )
)
SELECT
  event_at,
  effective_at,
  entity,
  entity_id,
  version,
  event_type,
  customer_id,
  facility_id,
  amount_usd_cents,
  collateral_sats,
  collateralization_ratio,
  price_usd,
  status,
  details
FROM timeline
ORDER BY event_at, entity, entity_id, version;
