-- =============================================================================
-- BUSINESS QUESTIONS
-- Purpose:  Example analytical queries that answer real business questions
--           using the final analytics and core layers.
-- Usage:    Run each query individually in DBeaver or psql. Each query is
--           self-contained and labelled with the business question it answers.
-- =============================================================================


-- ─────────────────────────────────────────────────────────────────────────────
-- Q1: Which marketing channel brings in the most loyal customers?
-- Why it matters: Helps marketing allocate acquisition budget to channels
--                 that deliver customers who stay longest and churn least.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    d.marketing_channel_clean                           AS channel,
    COUNT(*)                                            AS total_customers,
    ROUND(AVG(cf.tenure_days))                          AS avg_tenure_days,
    ROUND(SUM(d.churned)::numeric / COUNT(*) * 100, 1)  AS churn_rate_pct,
    ROUND(AVG(cf.total_payments_amount), 2)             AS avg_lifetime_value
FROM core.dim_customer d
JOIN analytics.customer_features cf ON d.customer_id = cf.customer_id
GROUP BY d.marketing_channel_clean
ORDER BY churn_rate_pct ASC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q2: What does the typical churned customer look like vs. a retained one?
-- Why it matters: Builds a profile of at-risk customers so the retention
--                 team knows whom to target with outreach campaigns.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    CASE WHEN cf.churned = 1 THEN 'Churned' ELSE 'Retained' END  AS segment,
    COUNT(*)                                                      AS customers,
    ROUND(AVG(cf.tenure_days))                                    AS avg_tenure_days,
    ROUND(AVG(cf.avg_monthly_fee), 2)                             AS avg_monthly_fee,
    ROUND(AVG(cf.total_payments_amount), 2)                       AS avg_lifetime_value,
    ROUND(AVG(cf.late_payment_rate) * 100, 1)                     AS avg_late_pmt_pct,
    ROUND(AVG(cf.avg_minutes_per_active_day), 1)                  AS avg_daily_minutes,
    ROUND(AVG(cf.usage_days_count))                               AS avg_usage_days,
    ROUND(AVG(cf.mobile_user_share) * 100, 1)                     AS mobile_pct
FROM analytics.customer_features cf
GROUP BY cf.churned
ORDER BY cf.churned;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q3: Are students more or less likely to churn?
-- Why it matters: If students churn more, the company might offer student
--                 discounts or targeted onboarding to improve retention.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    d.is_student_clean                                  AS student_status,
    COUNT(*)                                            AS total_customers,
    SUM(d.churned)                                      AS churned_customers,
    ROUND(SUM(d.churned)::numeric / COUNT(*) * 100, 1)  AS churn_rate_pct,
    ROUND(AVG(cf.avg_monthly_fee), 2)                   AS avg_monthly_fee,
    ROUND(AVG(cf.avg_minutes_per_active_day), 1)        AS avg_daily_minutes
FROM core.dim_customer d
JOIN analytics.customer_features cf ON d.customer_id = cf.customer_id
GROUP BY d.is_student_clean
ORDER BY churn_rate_pct DESC;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q4: Is there a revenue trend — is the business growing or shrinking?
-- Why it matters: Shows whether churn is outpacing new customer acquisition,
--                 giving leadership a clear picture of revenue trajectory.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    mr.month,
    mr.revenue,
    mr.payment_count,
    ROUND(mr.revenue / GREATEST(mr.payment_count, 1), 2)    AS avg_payment_amount,
    mr.revenue - LAG(mr.revenue) OVER (ORDER BY mr.month)   AS revenue_change,
    ROUND(
        (mr.revenue - LAG(mr.revenue) OVER (ORDER BY mr.month))
        / GREATEST(LAG(mr.revenue) OVER (ORDER BY mr.month), 1) * 100, 1
    )                                                        AS mom_growth_pct
FROM analytics.monthly_revenue mr
ORDER BY mr.month;


-- ─────────────────────────────────────────────────────────────────────────────
-- Q5: Which customers are most at risk of churning right now?
-- Why it matters: Gives the retention team a prioritised list of customers
--                 to contact before they leave. Sorted by risk signals:
--                 low usage, high late payments, short tenure.
-- ─────────────────────────────────────────────────────────────────────────────

SELECT
    cf.customer_id,
    d.plan_type_clean                                   AS plan,
    d.country_clean                                     AS country,
    cf.tenure_days,
    cf.avg_minutes_per_active_day,
    cf.usage_days_count,
    ROUND(cf.late_payment_rate * 100, 1)                AS late_pmt_pct,
    cf.has_active_subscription,
    cf.total_payments_amount                            AS lifetime_value
FROM analytics.customer_features cf
JOIN core.dim_customer d ON cf.customer_id = d.customer_id
WHERE cf.churned = 0                                    -- still active
  AND cf.has_active_subscription = 1                    -- has a subscription
ORDER BY
    cf.avg_minutes_per_active_day ASC,                  -- lowest engagement first
    cf.late_payment_rate DESC,                          -- highest late payments
    cf.tenure_days ASC                                  -- newest customers
LIMIT 20;
