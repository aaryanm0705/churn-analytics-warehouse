-- =============================================================================
-- core.dim_customer
-- Purpose:  Customer dimension with stable attributes and derived churn status.
-- Grain:    1 row per customer.
-- PK:       customer_id
-- Sources:  staging.customers_clean, analytics.churn_labels
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.dim_customer;

CREATE TABLE core.dim_customer AS
SELECT
    c.customer_id,
    c.signup_date_clean,
    c.age_clean,
    c.country_clean,
    c.marketing_channel_clean,
    c.plan_type_clean,
    c.is_student_clean,
    COALESCE(cl.churned, 0) AS churned,
    cl.churn_date
FROM staging.customers_clean c
LEFT JOIN analytics.churn_labels cl
    ON c.customer_id = cl.customer_id;

ALTER TABLE core.dim_customer
    ADD CONSTRAINT pk_dim_customer PRIMARY KEY (customer_id);

CREATE INDEX idx_dim_customer_country ON core.dim_customer (country_clean);
CREATE INDEX idx_dim_customer_churned ON core.dim_customer (churned);

-- =============================================================================
-- Validation
-- =============================================================================

-- 1. Total row count
SELECT 'row_count' AS check, COUNT(*) AS value
FROM core.dim_customer;

-- 2. Duplicate customer_id check (expect 0)
SELECT 'duplicate_customer_id' AS check, COUNT(*) AS value
FROM (
    SELECT customer_id
    FROM core.dim_customer
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) dupes;

-- 3. NULL customer_id check (expect 0)
SELECT 'null_customer_id' AS check, COUNT(*) AS value
FROM core.dim_customer
WHERE customer_id IS NULL;

-- 4. Churned distribution
SELECT 'churned_distribution' AS check, churned, COUNT(*) AS value
FROM core.dim_customer
GROUP BY churned
ORDER BY churned;
