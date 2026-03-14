-- =============================================================================
-- DASHBOARD QUERIES
-- Purpose:  Ready-to-use queries for a BI dashboard (Tableau, Power BI,
--           Metabase, etc.). Each query produces a clean result set designed
--           to power a specific dashboard panel.
-- Usage:    Connect your BI tool to PostgreSQL and use these as data sources.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 1: Executive KPI Scorecards
-- Shows the headline numbers a VP or CFO would want at a glance.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    COUNT(*)                                                        AS total_customers,
    SUM(churned)                                                    AS total_churned,
    COUNT(*) - SUM(churned)                                         AS total_retained,
    ROUND(SUM(churned)::numeric / GREATEST(COUNT(*), 1) * 100, 1)  AS overall_churn_rate_pct,
    ROUND(AVG(tenure_days))                                         AS avg_tenure_days,
    ROUND(AVG(total_payments_amount), 2)                            AS avg_lifetime_value,
    ROUND(AVG(avg_monthly_fee), 2)                                  AS avg_monthly_fee
FROM analytics.customer_features;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 2: Churn Rate by Plan Type (bar chart)
-- Identifies which pricing tiers have retention problems.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    plan_type_clean                             AS plan_type,
    customers,
    churned_customers,
    ROUND(churn_rate * 100, 1)                  AS churn_rate_pct
FROM analytics.churn_rate_by_plan_type
ORDER BY churn_rate DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 3: Churn Rate by Country (map or bar chart)
-- Shows geographic patterns in customer retention.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    country_clean                               AS country,
    customers,
    churned_customers,
    ROUND(churn_rate * 100, 1)                  AS churn_rate_pct
FROM analytics.churn_rate_by_country
ORDER BY churn_rate DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 4: Monthly Revenue Trend (line chart)
-- Revenue trajectory with month-over-month growth rate.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    month,
    revenue,
    payment_count,
    LAG(revenue) OVER (ORDER BY month)                                  AS prev_month_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / GREATEST(LAG(revenue) OVER (ORDER BY month), 1) * 100, 1
    )                                                                    AS mom_growth_pct
FROM analytics.monthly_revenue
ORDER BY month;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 5: Monthly Active Users & Engagement (dual-axis line chart)
-- Tracks user engagement trends alongside usage intensity.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    month,
    active_customers,
    total_minutes_used,
    ROUND(total_minutes_used::numeric / GREATEST(active_customers, 1), 1)
        AS avg_minutes_per_customer
FROM analytics.usage_summary
ORDER BY month;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 6: Customer Acquisition Channel Performance (stacked bar)
-- Compares channels on volume, churn rate, and average revenue.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    d.marketing_channel_clean                           AS channel,
    COUNT(*)                                            AS customers_acquired,
    SUM(d.churned)                                      AS churned,
    ROUND(SUM(d.churned)::numeric / COUNT(*) * 100, 1)  AS churn_rate_pct,
    ROUND(AVG(cf.total_payments_amount), 2)             AS avg_lifetime_value,
    ROUND(AVG(cf.avg_monthly_fee), 2)                   AS avg_monthly_fee
FROM core.dim_customer d
JOIN analytics.customer_features cf ON d.customer_id = cf.customer_id
GROUP BY d.marketing_channel_clean
ORDER BY customers_acquired DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 7: Churned vs. Retained Customer Profile (comparison table)
-- Side-by-side metrics for a "Know Your Churners" section.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    CASE WHEN churned = 1 THEN 'Churned' ELSE 'Retained' END   AS segment,
    COUNT(*)                                                    AS customers,
    ROUND(AVG(tenure_days))                                     AS avg_tenure_days,
    ROUND(AVG(subscription_count), 1)                           AS avg_subscriptions,
    ROUND(AVG(avg_monthly_fee), 2)                              AS avg_monthly_fee,
    ROUND(AVG(total_payments_amount), 2)                        AS avg_lifetime_value,
    ROUND(AVG(late_payment_rate) * 100, 1)                      AS avg_late_pmt_pct,
    ROUND(AVG(avg_minutes_per_active_day), 1)                   AS avg_daily_minutes,
    ROUND(AVG(usage_days_count))                                AS avg_active_days,
    ROUND(AVG(mobile_user_share) * 100, 1)                      AS mobile_pct
FROM analytics.customer_features
GROUP BY churned
ORDER BY churned;


-- ─────────────────────────────────────────────────────────────────────────────
-- PANEL 8: Cancellation Reasons Breakdown (pie/donut chart)
-- Shows why customers are leaving — actionable for product and support.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    s.cancellation_reason_clean                         AS reason,
    COUNT(*)                                            AS occurrences,
    ROUND(COUNT(*)::numeric / GREATEST(SUM(COUNT(*)) OVER (), 1) * 100, 1)
                                                        AS pct_of_cancellations
FROM core.fact_subscriptions s
WHERE s.cancellation_reason_clean <> 'unknown'
  AND s.status_clean IN ('cancelled', 'churned')
GROUP BY s.cancellation_reason_clean
ORDER BY occurrences DESC;
