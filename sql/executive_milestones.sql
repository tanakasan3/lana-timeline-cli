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
ctx AS (
  SELECT f.id AS facility_id, f.pending_credit_facility_id, f.customer_id
  FROM core_credit_facility_events_rollup f
  JOIN facility_pick fp ON fp.facility_id = f.id
  LIMIT 1
),
pending_ctx AS (
  SELECT p.id AS pending_id, p.credit_facility_proposal_id
  FROM core_pending_credit_facility_events_rollup p
  JOIN ctx c ON c.pending_credit_facility_id = p.id
  LIMIT 1
),
proposal_ctx AS (
  SELECT pr.id AS proposal_id
  FROM core_credit_facility_proposal_events_rollup pr
  JOIN pending_ctx p ON p.credit_facility_proposal_id = pr.id
  LIMIT 1
),
milestones AS (
  SELECT MIN(modified_at) AS ts, 'Prospect created' AS milestone, 'prospect' AS source
  FROM core_prospect_events_rollup p JOIN params x ON p.id = x.customer_id
  WHERE p.event_type = 'initialized'

  UNION ALL
  SELECT MIN(modified_at), 'KYC started', 'prospect'
  FROM core_prospect_events_rollup p JOIN params x ON p.id = x.customer_id
  WHERE p.event_type = 'kyc_started'

  UNION ALL
  SELECT MIN(modified_at), 'KYC approved', 'prospect'
  FROM core_prospect_events_rollup p JOIN params x ON p.id = x.customer_id
  WHERE p.event_type IN ('kyc_approved','manually_converted')

  UNION ALL
  SELECT MIN(modified_at), 'Customer created', 'customer'
  FROM core_customer_events_rollup c JOIN params x ON c.id = x.customer_id
  WHERE c.event_type = 'initialized'

  UNION ALL
  SELECT MIN(modified_at), 'Proposal created', 'proposal'
  FROM core_credit_facility_proposal_events_rollup pr JOIN proposal_ctx pc ON pr.id = pc.proposal_id
  WHERE pr.event_type = 'initialized'

  UNION ALL
  SELECT MIN(modified_at), 'Proposal approval concluded', 'proposal'
  FROM core_credit_facility_proposal_events_rollup pr JOIN proposal_ctx pc ON pr.id = pc.proposal_id
  WHERE pr.event_type = 'approval_process_concluded'

  UNION ALL
  SELECT MIN(modified_at), 'Pending facility created', 'pending'
  FROM core_pending_credit_facility_events_rollup p JOIN ctx c ON p.id = c.pending_credit_facility_id
  WHERE p.event_type = 'initialized'

  UNION ALL
  SELECT MIN(modified_at), 'Pending facility completed', 'pending'
  FROM core_pending_credit_facility_events_rollup p JOIN ctx c ON p.id = c.pending_credit_facility_id
  WHERE p.event_type = 'completed'

  UNION ALL
  SELECT MIN(modified_at), 'Facility initialized', 'facility'
  FROM core_credit_facility_events_rollup f JOIN ctx c ON f.id = c.facility_id
  WHERE f.event_type = 'initialized'

  UNION ALL
  SELECT MIN(modified_at), 'Facility activated', 'facility'
  FROM core_credit_facility_events_rollup f JOIN ctx c ON f.id = c.facility_id
  WHERE f.event_type = 'activated'

  UNION ALL
  SELECT MIN(modified_at), 'First disbursal settled', 'disbursal'
  FROM core_disbursal_events_rollup d JOIN ctx c ON d.facility_id = c.facility_id
  WHERE d.event_type = 'settled'

  UNION ALL
  SELECT MIN(modified_at), 'First interest posted', 'interest'
  FROM core_interest_accrual_cycle_events_rollup i JOIN ctx c ON i.facility_id = c.facility_id
  WHERE i.event_type = 'interest_accruals_posted'

  UNION ALL
  SELECT MIN(modified_at), 'First payment recorded', 'payment'
  FROM core_payment_events_rollup p
  WHERE p.id IN (
    SELECT pa.payment_id
    FROM core_payment_allocation_events_rollup pa
    JOIN core_disbursal_events_rollup d ON d.obligation_id = pa.obligation_id
    JOIN ctx c ON c.facility_id = d.facility_id
  )

  UNION ALL
  SELECT MIN(modified_at), 'Facility matured', 'facility'
  FROM core_credit_facility_events_rollup f JOIN ctx c ON f.id = c.facility_id
  WHERE f.event_type = 'matured'

  UNION ALL
  SELECT MIN(modified_at), 'Facility completed', 'facility'
  FROM core_credit_facility_events_rollup f JOIN ctx c ON f.id = c.facility_id
  WHERE f.event_type = 'completed'
)
SELECT
  ts AS milestone_at,
  milestone,
  source
FROM milestones
WHERE ts IS NOT NULL
ORDER BY ts;
