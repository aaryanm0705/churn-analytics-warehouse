-- =============================================================================
-- analytics.03_kpi_views
-- Purpose:  Business KPI tables for churn, revenue, and usage reporting.
-- Sources:  analytics.customer_features, core.dim_customer,
--           core.fact_payments, core.fact_usage_daily
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS analytics;

-- =============================================
-- 1. Churn rate by plan type
-- Grain: 1 row per plan_type_clean
-- =============================================

DROP TABLE IF EXISTS analytics.churn_rate_by_plan_type;

CREATE TABLE analytics.churn_rate_by_plan_type AS
SELECT
    d.plan_type_clean,
    COUNT(*)                                            AS customers,
    SUM(d.churned)                                      AS churned_customers,
    ROUND(SUM(d.churned)::numeric / GREATEST(COUNT(*), 1), 4) AS churn_rate
FROM core.dim_customer d
GROUP BY d.plan_type_clean
ORDER BY churn_rate DESC;

-- =============================================
-- 2. Churn rate by country
-- Grain: 1 row per country_clean
-- =============================================

DROP TABLE IF EXISTS analytics.churn_rate_by_country;

CREATE TABLE analytics.churn_rate_by_country AS
SELECT
    d.country_clean,
    COUNT(*)                                            AS customers,
    SUM(d.churned)                                      AS churned_customers,
    ROUND(SUM(d.churned)::numeric / GREATEST(COUNT(*), 1), 4) AS churn_rate
FROM core.dim_customer d
GROUP BY d.country_clean
ORDER BY churn_rate DESC;

-- =============================================
-- 3. Churn rate by marketing channel
-- Grain: 1 row per marketing_channel_clean
-- =============================================

DROP TABLE IF EXISTS analytics.churn_rate_by_marketing_channel;

CREATE TABLE analytics.churn_rate_by_marketing_channel AS
SELECT
    d.marketing_channel_clean,
    COUNT(*)                                            AS customers,
    SUM(d.churned)                                      AS churned_customers,
    ROUND(SUM(d.churned)::numeric / GREATEST(COUNT(*), 1), 4) AS churn_rate
FROM core.dim_customer d
GROUP BY d.marketing_channel_clean
ORDER BY churn_rate DESC;

-- =============================================
-- 4. Monthly revenue
-- Grain: 1 row per calendar month
-- =============================================

DROP TABLE IF EXISTS analytics.monthly_revenue;

CREATE TABLE analytics.monthly_revenue AS
SELECT
    DATE_TRUNC('month', p.payment_date_clean)::date     AS month,
    SUM(p.amount_clean)                                 AS revenue,
    COUNT(*)                                            AS payment_count
FROM core.fact_payments p
WHERE p.payment_date_clean IS NOT NULL
GROUP BY DATE_TRUNC('month', p.payment_date_clean)
ORDER BY month;

-- =============================================
-- 5. Monthly usage summary
-- Grain: 1 row per calendar month
-- =============================================

DROP TABLE IF EXISTS analytics.usage_summary;

CREATE TABLE analytics.usage_summary AS
SELECT
    DATE_TRUNC('month', u.usage_date_clean)::date       AS month,
    SUM(u.minutes_used_clean)                           AS total_minutes_used,
    COUNT(DISTINCT u.customer_id)                       AS active_customers
FROM core.fact_usage_daily u
WHERE u.usage_date_clean IS NOT NULL
GROUP BY DATE_TRUNC('month', u.usage_date_clean)
ORDER BY month;

-- =============================================================================
-- Validation
-- =============================================================================

-- Quick row counts for each KPI table
SELECT 'churn_rate_by_plan_type'       AS kpi, COUNT(*) AS rows FROM analytics.churn_rate_by_plan_type
UNION ALL
SELECT 'churn_rate_by_country',                COUNT(*)         FROM analytics.churn_rate_by_country
UNION ALL
SELECT 'churn_rate_by_marketing_channel',      COUNT(*)         FROM analytics.churn_rate_by_marketing_channel
UNION ALL
SELECT 'monthly_revenue',                      COUNT(*)         FROM analytics.monthly_revenue
UNION ALL
SELECT 'usage_summary',                        COUNT(*)         FROM analytics.usage_summary;
