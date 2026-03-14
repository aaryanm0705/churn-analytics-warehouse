-- =============================================================================
-- analytics.churn_labels
-- Purpose:  Derive churn labels from subscription end dates.
-- Grain:    1 row per customer.
-- PK:       customer_id
-- Source:   staging.subscriptions_clean
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.churn_labels;

CREATE TABLE analytics.churn_labels AS
WITH params AS (
    SELECT COALESCE(
        NULL::date,                    -- replace with DATE '2026-01-01' to override
        (SELECT MAX(end_date_clean)
         FROM staging.subscriptions_clean
         WHERE end_date_clean IS NOT NULL)
    ) AS analysis_date
),

customer_last_sub AS (
    SELECT
        s.customer_id,
        MAX(s.end_date_clean) AS last_end_date
    FROM staging.subscriptions_clean s
    GROUP BY s.customer_id
)

SELECT
    cls.customer_id,
    p.analysis_date,
    cls.last_end_date,
    CASE
        WHEN cls.last_end_date IS NULL
            THEN 0
        WHEN cls.last_end_date < p.analysis_date - INTERVAL '30 days'
            THEN 1
        ELSE 0
    END::int AS churned,
    CASE
        WHEN cls.last_end_date IS NOT NULL
         AND cls.last_end_date < p.analysis_date - INTERVAL '30 days'
            THEN cls.last_end_date
        ELSE NULL
    END AS churn_date
FROM customer_last_sub cls
CROSS JOIN params p;

ALTER TABLE analytics.churn_labels
    ADD CONSTRAINT pk_churn_labels PRIMARY KEY (customer_id);

-- =============================================================================
-- Validation
-- =============================================================================

-- 1. Total row count
SELECT 'row_count' AS check, COUNT(*) AS value
FROM analytics.churn_labels;

-- 2. Churned distribution
SELECT 'churned_distribution' AS check, churned, COUNT(*) AS value
FROM analytics.churn_labels
GROUP BY churned
ORDER BY churned;

-- 3. Duplicate customer_id check (expect 0)
SELECT 'duplicate_customer_id' AS check, COUNT(*) AS value
FROM (
    SELECT customer_id
    FROM analytics.churn_labels
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) dupes;

-- 4. NULL customer_id check (expect 0)
SELECT 'null_customer_id' AS check, COUNT(*) AS value
FROM analytics.churn_labels
WHERE customer_id IS NULL;
