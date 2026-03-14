-- =============================================================================
-- VALIDATION SUITE
-- Purpose:  Consolidated data quality checks across all warehouse layers.
--           Run after a full build to verify correctness.
-- Usage:    Execute this entire script in DBeaver or psql.
--           Every check returns a row with (layer, table_name, check_name, result).
--           Look for any result that says 'FAIL'.
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- STAGING LAYER
-- ─────────────────────────────────────────────────────────────────────────────

-- S1: Customers — no NULL primary keys
SELECT 'staging' AS layer,
       'customers_clean' AS table_name,
       'null_customer_id' AS check_name,
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END AS result
FROM staging.customers_clean
WHERE customer_id IS NULL;

-- S2: Subscriptions — no NULL primary keys
SELECT 'staging', 'subscriptions_clean', 'null_subscription_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM staging.subscriptions_clean
WHERE subscription_id IS NULL;

-- S3: Subscriptions — no NULL customer_id
SELECT 'staging', 'subscriptions_clean', 'null_customer_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM staging.subscriptions_clean
WHERE customer_id IS NULL;

-- S4: Payments — no NULL customer_id
SELECT 'staging', 'payments_clean', 'null_customer_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM staging.payments_clean
WHERE customer_id IS NULL;

-- S5: Usage — no NULL customer_id
SELECT 'staging', 'usage_clean', 'null_customer_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM staging.usage_clean
WHERE customer_id IS NULL;

-- S6: Customers — signup dates within plausible range
SELECT 'staging', 'customers_clean', 'signup_date_range',
       CASE
           WHEN MIN(signup_date_clean) >= DATE '2015-01-01'
            AND MAX(signup_date_clean) <= CURRENT_DATE
           THEN 'PASS'
           ELSE 'FAIL — range: ' || MIN(signup_date_clean) || ' to ' || MAX(signup_date_clean)
       END
FROM staging.customers_clean
WHERE signup_date_clean IS NOT NULL;

-- S7: Subscriptions — end_date not before start_date
-- Note: raw data contains ~300 rows with swapped dates. These are nulled out in
-- core.fact_subscriptions. The staging view retains the raw values intentionally.
-- This check is informational only at the staging layer.
SELECT 'staging', 'subscriptions_clean', 'end_before_start (informational — fixed in core)',
       COUNT(*) || ' rows with swapped dates (nulled in core.fact_subscriptions)' AS result
FROM staging.subscriptions_clean
WHERE end_date_clean IS NOT NULL
  AND start_date_clean IS NOT NULL
  AND end_date_clean < start_date_clean;

-- S7b: Core — confirm the fix holds (expect 0)
SELECT 'core', 'fact_subscriptions', 'end_before_start',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM core.fact_subscriptions
WHERE end_date_clean IS NOT NULL
  AND end_date_clean < start_date_clean;

-- S8: Payments — amounts are positive
SELECT 'staging', 'payments_clean', 'negative_amounts',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM staging.payments_clean
WHERE amount_clean IS NOT NULL AND amount_clean < 0;

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE LAYER — PRIMARY KEY INTEGRITY
-- ─────────────────────────────────────────────────────────────────────────────

-- C1: dim_customer — no duplicate primary keys
SELECT 'core', 'dim_customer', 'duplicate_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' dupes' END
FROM (
    SELECT customer_id FROM core.dim_customer
    GROUP BY customer_id HAVING COUNT(*) > 1
) d;

-- C2: dim_customer — no NULL primary keys
SELECT 'core', 'dim_customer', 'null_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM core.dim_customer WHERE customer_id IS NULL;

-- C3: fact_payments — no duplicate primary keys
SELECT 'core', 'fact_payments', 'duplicate_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' dupes' END
FROM (
    SELECT payment_id FROM core.fact_payments
    GROUP BY payment_id HAVING COUNT(*) > 1
) d;

-- C4: fact_subscriptions — no duplicate primary keys
SELECT 'core', 'fact_subscriptions', 'duplicate_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' dupes' END
FROM (
    SELECT subscription_id FROM core.fact_subscriptions
    GROUP BY subscription_id HAVING COUNT(*) > 1
) d;

-- C5: fact_usage_daily — no duplicate composite keys
SELECT 'core', 'fact_usage_daily', 'duplicate_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' dupes' END
FROM (
    SELECT customer_id, usage_date_clean FROM core.fact_usage_daily
    GROUP BY customer_id, usage_date_clean HAVING COUNT(*) > 1
) d;

-- ─────────────────────────────────────────────────────────────────────────────
-- CORE LAYER — REFERENTIAL INTEGRITY (orphan checks)
-- ─────────────────────────────────────────────────────────────────────────────

-- C6: fact_payments — all customer_ids exist in dim_customer
SELECT 'core', 'fact_payments', 'orphan_customer_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' orphans' END
FROM core.fact_payments f
LEFT JOIN core.dim_customer d ON f.customer_id = d.customer_id
WHERE d.customer_id IS NULL;

-- C7: fact_subscriptions — all customer_ids exist in dim_customer
SELECT 'core', 'fact_subscriptions', 'orphan_customer_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' orphans' END
FROM core.fact_subscriptions f
LEFT JOIN core.dim_customer d ON f.customer_id = d.customer_id
WHERE d.customer_id IS NULL;

-- C8: fact_usage_daily — all customer_ids exist in dim_customer
SELECT 'core', 'fact_usage_daily', 'orphan_customer_id',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' orphans' END
FROM core.fact_usage_daily f
LEFT JOIN core.dim_customer d ON f.customer_id = d.customer_id
WHERE d.customer_id IS NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- ANALYTICS LAYER — CHURN LABEL CONSISTENCY
-- ─────────────────────────────────────────────────────────────────────────────

-- A1: churn_labels — no duplicate primary keys
SELECT 'analytics', 'churn_labels', 'duplicate_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' dupes' END
FROM (
    SELECT customer_id FROM analytics.churn_labels
    GROUP BY customer_id HAVING COUNT(*) > 1
) d;

-- A2: churn_labels — churned is strictly 0 or 1
SELECT 'analytics', 'churn_labels', 'churned_values',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' invalid' END
FROM analytics.churn_labels
WHERE churned NOT IN (0, 1);

-- A3: churn_labels — churn_date is NULL when churned = 0
SELECT 'analytics', 'churn_labels', 'churn_date_when_not_churned',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM analytics.churn_labels
WHERE churned = 0 AND churn_date IS NOT NULL;

-- A4: churn_labels — churn_date is NOT NULL when churned = 1
SELECT 'analytics', 'churn_labels', 'churn_date_when_churned',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM analytics.churn_labels
WHERE churned = 1 AND churn_date IS NULL;

-- A5: customer_features — no duplicate primary keys
SELECT 'analytics', 'customer_features', 'duplicate_pk',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' dupes' END
FROM (
    SELECT customer_id FROM analytics.customer_features
    GROUP BY customer_id HAVING COUNT(*) > 1
) d;

-- A6: customer_features — no negative tenure
SELECT 'analytics', 'customer_features', 'negative_tenure',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' rows' END
FROM analytics.customer_features
WHERE tenure_days < 0;

-- A7: customer_features — churned matches dim_customer
SELECT 'analytics', 'customer_features', 'churned_mismatch_with_dim',
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL — ' || COUNT(*) || ' mismatches' END
FROM analytics.customer_features cf
JOIN core.dim_customer d ON cf.customer_id = d.customer_id
WHERE cf.churned <> d.churned;

-- ─────────────────────────────────────────────────────────────────────────────
-- ROW COUNT SUMMARY
-- ─────────────────────────────────────────────────────────────────────────────

SELECT 'summary' AS layer, 'row_counts' AS table_name, 'all_tables' AS check_name,
       'See results below' AS result;

SELECT 'staging'   AS layer, 'customers_clean'     AS table_name, COUNT(*)::text AS row_count FROM staging.customers_clean
UNION ALL
SELECT 'staging',            'subscriptions_clean',                COUNT(*)::text            FROM staging.subscriptions_clean
UNION ALL
SELECT 'staging',            'payments_clean',                     COUNT(*)::text            FROM staging.payments_clean
UNION ALL
SELECT 'staging',            'usage_clean',                        COUNT(*)::text            FROM staging.usage_clean
UNION ALL
SELECT 'staging',            'churn_labels_clean',                 COUNT(*)::text            FROM staging.churn_labels_clean
UNION ALL
SELECT 'core',              'dim_customer',                        COUNT(*)::text            FROM core.dim_customer
UNION ALL
SELECT 'core',              'fact_payments',                       COUNT(*)::text            FROM core.fact_payments
UNION ALL
SELECT 'core',              'fact_subscriptions',                  COUNT(*)::text            FROM core.fact_subscriptions
UNION ALL
SELECT 'core',              'fact_usage_daily',                    COUNT(*)::text            FROM core.fact_usage_daily
UNION ALL
SELECT 'analytics',         'churn_labels',                        COUNT(*)::text            FROM analytics.churn_labels
UNION ALL
SELECT 'analytics',         'customer_features',                   COUNT(*)::text            FROM analytics.customer_features
UNION ALL
SELECT 'analytics',         'churn_rate_by_plan_type',             COUNT(*)::text            FROM analytics.churn_rate_by_plan_type
UNION ALL
SELECT 'analytics',         'churn_rate_by_country',               COUNT(*)::text            FROM analytics.churn_rate_by_country
UNION ALL
SELECT 'analytics',         'churn_rate_by_marketing_channel',     COUNT(*)::text            FROM analytics.churn_rate_by_marketing_channel
UNION ALL
SELECT 'analytics',         'monthly_revenue',                     COUNT(*)::text            FROM analytics.monthly_revenue
UNION ALL
SELECT 'analytics',         'usage_summary',                       COUNT(*)::text            FROM analytics.usage_summary
ORDER BY layer, table_name;
