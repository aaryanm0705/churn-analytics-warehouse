-- =============================================================================
-- core.fact_subscriptions
-- Purpose:  Subscription fact table sourced from staging.subscriptions_clean.
-- Grain:    1 row per subscription_id.
-- PK:       subscription_id
-- FK:       customer_id -> core.dim_customer
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.fact_subscriptions;

CREATE TABLE core.fact_subscriptions AS
SELECT
    s.subscription_id,
    s.customer_id,
    s.start_date_clean,
    -- end_date: null out when it precedes start_date (swapped dates in raw data).
    -- Rows are kept; the invalid end_date is treated as NULL (subscription still active).
    CASE
        WHEN s.end_date_clean IS NOT NULL
         AND s.start_date_clean IS NOT NULL
         AND s.end_date_clean < s.start_date_clean
        THEN NULL
        ELSE s.end_date_clean
    END AS end_date_clean,
    s.status_clean,
    s.cancellation_reason_clean,
    s.renewal_count_clean,
    s.monthly_fee_clean
FROM staging.subscriptions_clean s
WHERE s.customer_id IS NOT NULL;

ALTER TABLE core.fact_subscriptions
    ADD CONSTRAINT pk_fact_subscriptions PRIMARY KEY (subscription_id);

CREATE INDEX idx_fact_subscriptions_customer_id
    ON core.fact_subscriptions (customer_id);

CREATE INDEX idx_fact_subscriptions_end_date
    ON core.fact_subscriptions (end_date_clean);

-- =============================================================================
-- Validation
-- =============================================================================

-- 1. Total row count
SELECT 'row_count' AS check, COUNT(*) AS value
FROM core.fact_subscriptions;

-- 2. Duplicate subscription_id check (expect 0)
SELECT 'duplicate_subscription_id' AS check, COUNT(*) AS value
FROM (
    SELECT subscription_id
    FROM core.fact_subscriptions
    GROUP BY subscription_id
    HAVING COUNT(*) > 1
) dupes;

-- 3. NULL subscription_id check (expect 0)
SELECT 'null_subscription_id' AS check, COUNT(*) AS value
FROM core.fact_subscriptions
WHERE subscription_id IS NULL;

-- 4. NULL customer_id check (expect 0)
SELECT 'null_customer_id' AS check, COUNT(*) AS value
FROM core.fact_subscriptions
WHERE customer_id IS NULL;

-- 5. Orphan customer_id check (expect 0)
SELECT 'orphan_customer_id' AS check, COUNT(*) AS value
FROM core.fact_subscriptions f
LEFT JOIN core.dim_customer d ON f.customer_id = d.customer_id
WHERE d.customer_id IS NULL;

-- 6. end_date before start_date check (expect 0 — nulled out in SELECT)
SELECT 'end_before_start' AS check, COUNT(*) AS value
FROM core.fact_subscriptions
WHERE end_date_clean IS NOT NULL
  AND end_date_clean < start_date_clean;
