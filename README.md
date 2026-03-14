# Churn Analytics Warehouse

A layered SQL data warehouse built in PostgreSQL, with a Power BI dashboard on top. Built on synthetic data designed to mimic the messiness of real production systems — mixed date formats, nulls, duplicated labels, numbers stored as text.

**Stack:** PostgreSQL · SQL · Power BI

---

## Dashboard

![Executive Overview](power_bi_dashboard/dashboard_page1.png)

![Segment Deep Dive](power_bi_dashboard/dashboard_page2.png)

The `.pbix` file is in [`power_bi_dashboard/`](power_bi_dashboard/).

---

## Key Findings

Results from the actual dataset (20,000 synthetic customers):

- **77.4% churn rate** — 15,471 of 20,000 customers churned
- **Churned customers paid more** — avg monthly fee $23.53 vs $14.64 for retained, indicating price sensitivity as a likely driver
- **Churn is consistent across all acquisition channels** (~77% for Google, Instagram, LinkedIn, other) — this rules out acquisition quality as the cause and points to product or pricing
- **No geographic concentration** — churn is uniform across all countries, ruling out regional factors
- **Cancellation reasons are evenly distributed** across competition, high price, low usage, technical issues, and other — no single dominant reason, suggesting a broad retention problem
- **Revenue volatile between $240K–$280K/month** with no clear growth trend, consistent with high churn neutralising new customer revenue

---

## Architecture

Four layers, each with a clear purpose:

| Layer | What it does |
|---|---|
| **raw** | CSV files loaded as-is — every column as text, no type assumptions |
| **staging** | Views that clean and standardise the raw data |
| **core** | Persistent dimension and fact tables with PKs, FKs, and indexes |
| **analytics** | Churn labels, customer feature profiles, and KPI rollups |

---

## Key outputs

- `core.dim_customer` — one row per customer with demographics, plan, and churn status
- `core.fact_subscriptions / fact_payments / fact_usage_daily` — event-level fact tables
- `analytics.churn_labels` — churned/retained classification using a 30-day grace period rule
- `analytics.customer_features` — one row per customer: tenure, spend, late payment rate, engagement
- `analytics.churn_rate_by_plan_type / by_country / by_marketing_channel` — KPI tables
- `analytics.monthly_revenue / usage_summary` — time-series aggregations

---

## Files

| Path | Description |
|---|---|
| [sql/](sql/) | All SQL organised by layer |
| [sql/validation/validation_suite.sql](sql/validation/validation_suite.sql) | Data quality checks across all layers |
| [sql/analytics/04_business_questions.sql](sql/analytics/04_business_questions.sql) | Five business questions answered with SQL |
| [sql/analytics/05_dashboard_queries.sql](sql/analytics/05_dashboard_queries.sql) | Eight Power BI-ready queries |
| [BUSINESS_OVERVIEW.md](BUSINESS_OVERVIEW.md) | Project context, data problems, churn definition, and key findings |
| [workflows/build_core_and_analytics.md](workflows/build_core_and_analytics.md) | Technical run guide and churn definition |

---

> **Data:** Fully synthetic. Generated to resemble real subscription data including intentional data quality issues. No real customer information is used.
