\set QUIET 1

WITH
params AS (
  SELECT
    NULLIF(:'customer_id', '')::uuid AS customer_id_in,
    NULLIF(:'facility_id', '')::uuid AS facility_id_in
),
target_facilities AS (
  SELECT DISTINCT ON (f.id)
    f.id AS facility_id,
    f.pending_credit_facility_id,
    f.customer_id
  FROM core_credit_facility_events_rollup f
  CROSS JOIN params p
  WHERE (p.facility_id_in IS NULL OR f.id = p.facility_id_in)
    AND (p.customer_id_in IS NULL OR f.customer_id = p.customer_id_in)
  ORDER BY f.id, f.version DESC
),
target_customers AS (
  SELECT DISTINCT c.id AS customer_id
  FROM core_customer_events_rollup c
  CROSS JOIN params p
  WHERE (p.customer_id_in IS NULL OR c.id = p.customer_id_in)
    AND (
      p.facility_id_in IS NULL
      OR EXISTS (
        SELECT 1 FROM target_facilities tf
        WHERE tf.facility_id = p.facility_id_in
          AND tf.customer_id = c.id
      )
    )
),
pending_ctx AS (
  SELECT DISTINCT p.id AS pending_id, p.credit_facility_proposal_id, p.customer_id
  FROM core_pending_credit_facility_events_rollup p
  JOIN target_facilities tf ON tf.pending_credit_facility_id = p.id
),
proposal_ctx AS (
  SELECT DISTINCT pr.id AS proposal_id, pr.customer_id
  FROM core_credit_facility_proposal_events_rollup pr
  JOIN pending_ctx p ON p.credit_facility_proposal_id = pr.id
),
milestones AS (
  SELECT tc.customer_id, NULL::uuid AS facility_id, MIN(p.modified_at) AS ts, 'Prospect created' AS milestone, 'prospect' AS source
  FROM core_prospect_events_rollup p
  JOIN target_customers tc ON tc.customer_id = p.id
  WHERE p.event_type = 'initialized'
  GROUP BY tc.customer_id

  UNION ALL
  SELECT tc.customer_id, NULL, MIN(p.modified_at), 'KYC started', 'prospect'
  FROM core_prospect_events_rollup p
  JOIN target_customers tc ON tc.customer_id = p.id
  WHERE p.event_type = 'kyc_started'
  GROUP BY tc.customer_id

  UNION ALL
  SELECT tc.customer_id, NULL, MIN(p.modified_at), 'KYC approved', 'prospect'
  FROM core_prospect_events_rollup p
  JOIN target_customers tc ON tc.customer_id = p.id
  WHERE p.event_type IN ('kyc_approved','manually_converted')
  GROUP BY tc.customer_id

  UNION ALL
  SELECT tc.customer_id, NULL, MIN(c.modified_at), 'Customer created', 'customer'
  FROM core_customer_events_rollup c
  JOIN target_customers tc ON tc.customer_id = c.id
  WHERE c.event_type = 'initialized'
  GROUP BY tc.customer_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(pr.modified_at), 'Proposal created', 'proposal'
  FROM core_credit_facility_proposal_events_rollup pr
  JOIN proposal_ctx pc ON pc.proposal_id = pr.id
  JOIN pending_ctx p ON p.credit_facility_proposal_id = pr.id
  JOIN target_facilities tf ON tf.pending_credit_facility_id = p.pending_id
  WHERE pr.event_type = 'initialized'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(pr.modified_at), 'Proposal approval concluded', 'proposal'
  FROM core_credit_facility_proposal_events_rollup pr
  JOIN proposal_ctx pc ON pc.proposal_id = pr.id
  JOIN pending_ctx p ON p.credit_facility_proposal_id = pr.id
  JOIN target_facilities tf ON tf.pending_credit_facility_id = p.pending_id
  WHERE pr.event_type = 'approval_process_concluded'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(p.modified_at), 'Pending facility created', 'pending'
  FROM core_pending_credit_facility_events_rollup p
  JOIN target_facilities tf ON tf.pending_credit_facility_id = p.id
  WHERE p.event_type = 'initialized'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(p.modified_at), 'Pending facility completed', 'pending'
  FROM core_pending_credit_facility_events_rollup p
  JOIN target_facilities tf ON tf.pending_credit_facility_id = p.id
  WHERE p.event_type = 'completed'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(f.modified_at), 'Facility initialized', 'facility'
  FROM core_credit_facility_events_rollup f
  JOIN target_facilities tf ON tf.facility_id = f.id
  WHERE f.event_type = 'initialized'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(f.modified_at), 'Facility activated', 'facility'
  FROM core_credit_facility_events_rollup f
  JOIN target_facilities tf ON tf.facility_id = f.id
  WHERE f.event_type = 'activated'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(d.modified_at), 'First disbursal settled', 'disbursal'
  FROM core_disbursal_events_rollup d
  JOIN target_facilities tf ON tf.facility_id = d.facility_id
  WHERE d.event_type = 'settled'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(i.modified_at), 'First interest posted', 'interest'
  FROM core_interest_accrual_cycle_events_rollup i
  JOIN target_facilities tf ON tf.facility_id = i.facility_id
  WHERE i.event_type = 'interest_accruals_posted'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(p.modified_at), 'First payment recorded', 'payment'
  FROM core_payment_events_rollup p
  JOIN core_payment_allocation_events_rollup pa ON pa.payment_id = p.id
  JOIN core_disbursal_events_rollup d ON d.obligation_id = pa.obligation_id
  JOIN target_facilities tf ON tf.facility_id = d.facility_id
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(f.modified_at), 'Facility matured', 'facility'
  FROM core_credit_facility_events_rollup f
  JOIN target_facilities tf ON tf.facility_id = f.id
  WHERE f.event_type = 'matured'
  GROUP BY tf.customer_id, tf.facility_id

  UNION ALL
  SELECT tf.customer_id, tf.facility_id, MIN(f.modified_at), 'Facility completed', 'facility'
  FROM core_credit_facility_events_rollup f
  JOIN target_facilities tf ON tf.facility_id = f.id
  WHERE f.event_type = 'completed'
  GROUP BY tf.customer_id, tf.facility_id
)
SELECT
  customer_id,
  facility_id,
  CASE
    WHEN facility_id IS NULL THEN CONCAT('customer/', customer_id::text)
    ELSE CONCAT('customer/', customer_id::text, ' | facility/', facility_id::text)
  END AS milestone_bucket,
  ts AS milestone_at,
  milestone,
  source
FROM milestones
WHERE ts IS NOT NULL
ORDER BY customer_id, facility_id NULLS FIRST, ts;
