-- =============================================================================
-- core.fact_payments
-- Purpose:  Payment fact table sourced from staging.payments_clean.
-- Grain:    1 row per payment event.
-- PK:       payment_id (surrogate, generated via ROW_NUMBER)
-- FK:       customer_id -> core.dim_customer
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.fact_payments;

CREATE TABLE core.fact_payments AS
SELECT
    ROW_NUMBER() OVER (ORDER BY p.customer_id, p.payment_date_clean)::int
        AS payment_id,
    p.customer_id,
    p.payment_date_clean,
    p.amount_clean,
    p.currency_clean,
    p.payment_method_clean,
    p.late_payment_flag_clean
FROM staging.payments_clean p
WHERE p.customer_id IS NOT NULL;

ALTER TABLE core.fact_payments
    ADD CONSTRAINT pk_fact_payments PRIMARY KEY (payment_id);

CREATE INDEX idx_fact_payments_customer_id
    ON core.fact_payments (customer_id);

CREATE INDEX idx_fact_payments_date
    ON core.fact_payments (payment_date_clean);

-- =============================================================================
-- Validation
-- =============================================================================

-- 1. Total row count
SELECT 'row_count' AS check, COUNT(*) AS value
FROM core.fact_payments;

-- 2. Duplicate payment_id check (expect 0)
SELECT 'duplicate_payment_id' AS check, COUNT(*) AS value
FROM (
    SELECT payment_id
    FROM core.fact_payments
    GROUP BY payment_id
    HAVING COUNT(*) > 1
) dupes;

-- 3. Orphan customer_id check (expect 0)
SELECT 'orphan_customer_id' AS check, COUNT(*) AS value
FROM core.fact_payments f
LEFT JOIN core.dim_customer d ON f.customer_id = d.customer_id
WHERE d.customer_id IS NULL;
