\set QUIET 1

WITH target_tables AS (
  SELECT unnest(ARRAY[
    'core_prospect_events_rollup',
    'core_customer_events_rollup',
    'core_party_events_rollup',
    'core_credit_facility_proposal_events_rollup',
    'core_approval_process_events_rollup',
    'core_pending_credit_facility_events_rollup',
    'core_credit_facility_events_rollup',
    'core_disbursal_events_rollup',
    'core_interest_accrual_cycle_events_rollup',
    'core_obligation_events_rollup',
    'core_payment_events_rollup',
    'core_payment_allocation_events_rollup',
    'core_collateral_events_rollup',
    'core_deposit_account_events_rollup',
    'core_deposit_events_rollup',
    'core_withdrawal_events_rollup'
  ]) AS table_name
),
counts AS (
  SELECT
    t.table_name,
    EXISTS (
      SELECT 1
      FROM information_schema.tables i
      WHERE i.table_schema = 'public'
        AND i.table_name = t.table_name
    ) AS table_exists,
    CASE
      WHEN EXISTS (
        SELECT 1
        FROM information_schema.tables i
        WHERE i.table_schema = 'public'
          AND i.table_name = t.table_name
      ) THEN (xpath('/row/cnt/text()', query_to_xml(format('SELECT count(*) AS cnt FROM %I', t.table_name), false, true, '')))[1]::text::bigint
      ELSE NULL::bigint
    END AS row_count
  FROM target_tables t
)
SELECT
  table_name,
  table_exists,
  row_count,
  CASE
    WHEN NOT table_exists THEN 'MISSING_TABLE'
    WHEN row_count = 0 THEN 'ZERO_ROWS'
    ELSE 'OK'
  END AS status
FROM counts
ORDER BY
  CASE
    WHEN NOT table_exists THEN 0
    WHEN row_count = 0 THEN 1
    ELSE 2
  END,
  table_name;
