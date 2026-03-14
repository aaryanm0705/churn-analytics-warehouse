-- =============================================================================
-- analytics.customer_features
-- Purpose:  ML-ready feature table combining customer attributes with
--           behavioural signals from subscriptions, payments, and usage.
-- Grain:    1 row per customer.
-- PK:       customer_id
-- Sources:  core.dim_customer, core.fact_subscriptions,
--           core.fact_payments, core.fact_usage_daily
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.customer_features;

CREATE TABLE analytics.customer_features AS
WITH params AS (
    SELECT COALESCE(
        NULL::date,                    -- replace with DATE '2026-01-01' to override
        (SELECT MAX(end_date_clean)
         FROM staging.subscriptions_clean
         WHERE end_date_clean IS NOT NULL)
    ) AS analysis_date
),

sub_agg AS (
    SELECT
        s.customer_id,
        COUNT(*)                        AS subscription_count,
        AVG(s.monthly_fee_clean)        AS avg_monthly_fee,
        MAX(CASE
            WHEN s.end_date_clean IS NULL
              OR s.end_date_clean >= p.analysis_date
            THEN 1 ELSE 0
        END)                            AS has_active_subscription
    FROM core.fact_subscriptions s
    CROSS JOIN params p
    GROUP BY s.customer_id
),

pay_agg AS (
    SELECT
        py.customer_id,
        COUNT(*)                        AS payment_count,
        SUM(py.amount_clean)            AS total_payments_amount,
        CASE
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND(
                SUM(CASE WHEN py.late_payment_flag_clean = 'TRUE' THEN 1 ELSE 0 END)::numeric
                / COUNT(*), 4)
        END                             AS late_payment_rate
    FROM core.fact_payments py
    GROUP BY py.customer_id
),

usage_agg AS (
    SELECT
        u.customer_id,
        COUNT(*)                        AS usage_days_count,
        SUM(u.minutes_used_clean)       AS total_minutes_used,
        CASE
            WHEN COUNT(*) = 0 THEN 0
            ELSE ROUND(SUM(u.minutes_used_clean)::numeric / COUNT(*), 2)
        END                             AS avg_minutes_per_active_day,
        ROUND(
            SUM(CASE WHEN u.is_mobile_user_clean = 'TRUE' THEN 1 ELSE 0 END)::numeric
            / GREATEST(COUNT(*), 1), 4
        )                               AS mobile_user_share
    FROM core.fact_usage_daily u
    GROUP BY u.customer_id
)

SELECT
    d.customer_id,
    d.churned,
    d.churn_date,
    p.analysis_date,

    -- tenure
    COALESCE(p.analysis_date - d.signup_date_clean, 0)  AS tenure_days,

    -- subscription features
    COALESCE(sa.has_active_subscription, 0)             AS has_active_subscription,
    COALESCE(sa.subscription_count, 0)                  AS subscription_count,
    COALESCE(sa.avg_monthly_fee, 0)                     AS avg_monthly_fee,

    -- payment features
    COALESCE(pa.total_payments_amount, 0)               AS total_payments_amount,
    COALESCE(pa.payment_count, 0)                       AS payment_count,
    COALESCE(pa.late_payment_rate, 0)                   AS late_payment_rate,

    -- usage features
    COALESCE(ua.usage_days_count, 0)                    AS usage_days_count,
    COALESCE(ua.total_minutes_used, 0)                  AS total_minutes_used,
    COALESCE(ua.avg_minutes_per_active_day, 0)          AS avg_minutes_per_active_day,
    COALESCE(ua.mobile_user_share, 0)                   AS mobile_user_share

FROM core.dim_customer d
CROSS JOIN params p
LEFT JOIN sub_agg   sa ON d.customer_id = sa.customer_id
LEFT JOIN pay_agg   pa ON d.customer_id = pa.customer_id
LEFT JOIN usage_agg ua ON d.customer_id = ua.customer_id;

ALTER TABLE analytics.customer_features
    ADD CONSTRAINT pk_customer_features PRIMARY KEY (customer_id);

CREATE INDEX idx_customer_features_churned
    ON analytics.customer_features (churned);

-- =============================================================================
-- Validation
-- =============================================================================

-- 1. Total row count
SELECT 'row_count' AS check, COUNT(*) AS value
FROM analytics.customer_features;

-- 2. Duplicate customer_id check (expect 0)
SELECT 'duplicate_customer_id' AS check, COUNT(*) AS value
FROM (
    SELECT customer_id
    FROM analytics.customer_features
    GROUP BY customer_id
    HAVING COUNT(*) > 1
) dupes;

-- 3. NULL customer_id check (expect 0)
SELECT 'null_customer_id' AS check, COUNT(*) AS value
FROM analytics.customer_features
WHERE customer_id IS NULL;

-- 4. Churned distribution
SELECT 'churned_distribution' AS check, churned, COUNT(*) AS value
FROM analytics.customer_features
GROUP BY churned
ORDER BY churned;

-- 5. Sanity: customers with negative tenure (expect 0)
SELECT 'negative_tenure' AS check, COUNT(*) AS value
FROM analytics.customer_features
WHERE tenure_days < 0;
