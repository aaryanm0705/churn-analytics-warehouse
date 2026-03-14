-- =============================================================================
-- core.fact_usage_daily
-- Purpose:  Daily usage fact table aggregated from staging.usage_clean.
-- Grain:    1 row per customer per day.
-- PK:       (customer_id, usage_date_clean) composite
-- FK:       customer_id -> core.dim_customer
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.fact_usage_daily;

CREATE TABLE core.fact_usage_daily AS
SELECT
    u.customer_id,
    u.usage_date_clean,
    SUM(u.logins_clean)             AS logins_clean,
    SUM(u.minutes_used_clean)       AS minutes_used_clean,
    SUM(u.core_features_used_clean) AS core_features_used_clean,
    MAX(u.is_mobile_user_clean)     AS is_mobile_user_clean
FROM staging.usage_clean u
WHERE u.customer_id IS NOT NULL
GROUP BY u.customer_id, u.usage_date_clean;

ALTER TABLE core.fact_usage_daily
    ADD CONSTRAINT pk_fact_usage_daily PRIMARY KEY (customer_id, usage_date_clean);

CREATE INDEX idx_fact_usage_daily_customer_id
    ON core.fact_usage_daily (customer_id);

-- =============================================================================
-- Validation
-- =============================================================================

-- 1. Duplicate composite key check (expect 0 — enforced by PK, but verify)
SELECT 'duplicate_composite_key' AS check, COUNT(*) AS value
FROM (
    SELECT customer_id, usage_date_clean
    FROM core.fact_usage_daily
    GROUP BY customer_id, usage_date_clean
    HAVING COUNT(*) > 1
) dupes;

-- 2. Orphan customer_id check (expect 0)
SELECT 'orphan_customer_id' AS check, COUNT(*) AS value
FROM core.fact_usage_daily f
LEFT JOIN core.dim_customer d ON f.customer_id = d.customer_id
WHERE d.customer_id IS NULL;

-- 3. NULL customer_id check (expect 0)
SELECT 'null_customer_id' AS check, COUNT(*) AS value
FROM core.fact_usage_daily
WHERE customer_id IS NULL;
