# Build Core & Analytics Layers

## Objective

Build a portfolio-grade churn analytics data warehouse on PostgreSQL.
Transform raw CSV data through staging views into dimensional core tables and analytics-ready outputs.

## Architecture

```
raw (CSV imports) --> staging (cleaned views) --> core (dim/fact tables) --> analytics (features, labels, KPIs)
```

**Materialization rules:**

- **raw** -- tables created by CSV import, then moved from `public` to `raw` schema.
- **staging** -- SQL views (`CREATE OR REPLACE VIEW`). These clean and normalise raw data. They are the **source of truth** for all column names and data types used downstream.
- **core** -- persistent tables (`CREATE TABLE AS`). Dimensional models with primary keys and indexes.
- **analytics** -- persistent tables (`CREATE TABLE AS`). Derived, reproducible outputs for reporting and ML.

## Prerequisites

- PostgreSQL instance running
- Raw CSV files loaded into `public.*` tables
- `sql/setup/setup_database_schemas.sql` executed (creates schemas, moves tables to `raw`)
- All `sql/staging/*_clean.sql` views created

## Run Order

| Step | Script | Purpose |
|------|--------|---------|
| 1 | `sql/setup/setup_database_schemas.sql` | Create schemas; move raw tables |
| 2 | `sql/staging/customers_clean.sql` | Staging view for customers |
| 3 | `sql/staging/subscriptions_clean.sql` | Staging view for subscriptions |
| 4 | `sql/staging/payments_clean.sql` | Staging view for payments |
| 5 | `sql/staging/usage_clean.sql` | Staging view for usage |
| 6 | `sql/staging/churn_labels_clean.sql` | Staging view for churn labels |
| 7 | `sql/analytics/01_churn_labels.sql` | Derived churn labels (must run before dim_customer) |
| 8 | `sql/core/01_dim_customer.sql` | Customer dimension (joins churn labels) |
| 9 | `sql/core/02_fact_payments.sql` | Payment facts |
| 10 | `sql/core/03_fact_subscriptions.sql` | Subscription facts |
| 11 | `sql/core/04_fact_usage_daily.sql` | Daily usage facts |
| 12 | `sql/analytics/02_customer_features.sql` | ML-ready feature table |
| 13 | `sql/analytics/03_kpi_views.sql` | Business KPI views |
| 14 | `sql/validation/validation_suite.sql` | Data quality checks across all layers |

### Optional (post-build analysis)

| Step | Script | Purpose |
|------|--------|---------|
| — | `sql/analytics/04_business_questions.sql` | Five business questions answered with SQL |
| — | `sql/analytics/05_dashboard_queries.sql` | Eight dashboard-ready queries for BI tools |

### One-command build

Instead of running each step manually, use the orchestration script:

```bash
./run_all.sh -h localhost -p 5432 -d churn_db -U postgres
```

This runs steps 1–14 in order and stops on first failure.

## Staging Inputs (source of truth)

All column names and data types below come directly from `sql/staging/*_clean.sql` views.
Core and analytics scripts must reference these exact names — no renaming, no re-casting.

| Staging View | Grain | Columns |
|---|---|---|
| `staging.customers_clean` | 1 row per customer | `customer_id`, `signup_date_clean` (date), `age_clean` (int), `country_clean` (text), `marketing_channel_clean` (text), `plan_type_clean` (text), `is_student_clean` (text) |
| `staging.subscriptions_clean` | 1 row per subscription | `subscription_id`, `customer_id`, `start_date_clean` (date), `end_date_clean` (date), `status_clean` (text), `cancellation_reason_clean` (text), `renewal_count_clean` (int), `monthly_fee_clean` (numeric) |
| `staging.payments_clean` | 1 row per payment event | `customer_id`, `payment_date_clean` (date), `amount_clean` (numeric), `currency_clean` (text), `payment_method_clean` (text), `late_payment_flag_clean` (text) |
| `staging.usage_clean` | 1 row per usage record | `customer_id`, `usage_date_clean` (date), `logins_clean` (int), `minutes_used_clean` (int), `core_features_used_clean` (int), `is_mobile_user_clean` (text) |
| `staging.churn_labels_clean` | 1 row per customer | `customer_id`, `churn_date_clean` (date), `churn_flag` (int 0/1) |

> **Note:** `staging.churn_labels_clean` is available for reference/comparison but is NOT the
> authoritative churn source. Churn labels are derived from subscription data (see Churn Definition).

## Core Tables

All core objects are **persistent tables** (`DROP TABLE IF EXISTS` + `CREATE TABLE AS`), not views.
Each script must add a primary key constraint and indexes on foreign/join keys after creation.

### Dimensions

**`core.dim_customer`** — 1 row per customer

| Column | Source | Notes |
|---|---|---|
| `customer_id` | `staging.customers_clean` | **PK** |
| `signup_date_clean` | `staging.customers_clean` | Date |
| `age_clean` | `staging.customers_clean` | Integer |
| `country_clean` | `staging.customers_clean` | Text |
| `marketing_channel_clean` | `staging.customers_clean` | Text |
| `plan_type_clean` | `staging.customers_clean` | Text |
| `is_student_clean` | `staging.customers_clean` | Text |
| `churned` | Derived from subscriptions | Integer 0/1 (see Churn Definition) |
| `churn_date` | Derived from subscriptions | Date; NULL when `churned = 0` |

### Facts

**`core.fact_subscriptions`** — 1 row per subscription record

| Column | Source | Notes |
|---|---|---|
| `subscription_id` | `staging.subscriptions_clean` | **PK** (natural key from raw data) |
| `customer_id` | `staging.subscriptions_clean` | **FK** → `core.dim_customer` |
| `start_date_clean` | `staging.subscriptions_clean` | Date |
| `end_date_clean` | `staging.subscriptions_clean` | Date; NULL = still active |
| `status_clean` | `staging.subscriptions_clean` | Text |
| `cancellation_reason_clean` | `staging.subscriptions_clean` | Text |
| `renewal_count_clean` | `staging.subscriptions_clean` | Integer (floored at 0) |
| `monthly_fee_clean` | `staging.subscriptions_clean` | Numeric(10,2) |

**`core.fact_payments`** — 1 row per payment event

| Column | Source | Notes |
|---|---|---|
| `payment_id` | Generated (`ROW_NUMBER()`) | **PK** — surrogate key (raw data has no payment ID) |
| `customer_id` | `staging.payments_clean` | **FK** → `core.dim_customer` |
| `payment_date_clean` | `staging.payments_clean` | Date |
| `amount_clean` | `staging.payments_clean` | Numeric(10,2) |
| `currency_clean` | `staging.payments_clean` | Text |
| `payment_method_clean` | `staging.payments_clean` | Text |
| `late_payment_flag_clean` | `staging.payments_clean` | Text (TRUE/FALSE/UNKNOWN) |

**`core.fact_usage_daily`** — 1 row per customer per day

| Column | Source | Notes |
|---|---|---|
| `customer_id` | `staging.usage_clean` | **Composite PK** part 1; **FK** → `core.dim_customer` |
| `usage_date_clean` | `staging.usage_clean` | **Composite PK** part 2 |
| `logins_clean` | `staging.usage_clean` | Integer |
| `minutes_used_clean` | `staging.usage_clean` | Integer |
| `core_features_used_clean` | `staging.usage_clean` | Integer |
| `is_mobile_user_clean` | `staging.usage_clean` | Text (TRUE/FALSE/UNKNOWN) |

> If multiple raw rows exist for the same `(customer_id, usage_date_clean)`, aggregate
> deterministically: `SUM` for logins/minutes/features, `MAX` for is_mobile_user.

## Churn Definition

- **Type:** Subscription-based churn.
- **Grace window:** 30 days.

### analysis_date

Churn classification requires a reference point in time — the `analysis_date`.
Without it, "has this customer churned?" has no answer because there is no anchor.

Every script that needs `analysis_date` should open with a `params` CTE.
This pattern works in any plain SQL runner (DBeaver, psql, etc.) — no variables or `SET` required.

```sql
WITH params AS (
    SELECT COALESCE(
        NULL::date,                    -- ← replace with DATE '2026-01-01' to override
        (SELECT MAX(end_date_clean)
         FROM staging.subscriptions_clean
         WHERE end_date_clean IS NOT NULL)
    ) AS analysis_date
)
SELECT ... FROM params, other_tables ...
```

**How it works:**

- By default `NULL::date` is passed, so `COALESCE` falls through to the
  data-driven `MAX(end_date_clean)`. The churn boundary automatically adapts
  to whatever data is loaded.
- To pin a fixed date for reproducibility (e.g. a portfolio demo or regression test),
  replace `NULL::date` with a literal like `DATE '2026-01-01'`. The `COALESCE`
  then returns the override and the subquery is ignored.

### Churn rule

```
churned = 1
  WHEN customer's latest end_date_clean < analysis_date - INTERVAL '30 days'

churned = 0
  WHEN customer has no subscriptions (no evidence of churn)
    OR latest end_date_clean IS NULL (subscription still active)
    OR latest end_date_clean >= analysis_date - INTERVAL '30 days'

churn_date = latest end_date_clean   WHEN churned = 1
churn_date = NULL                    WHEN churned = 0
```

- Churn labels are **derived** from `staging.subscriptions_clean`, not copied from `staging.churn_labels_clean`.
- `staging.churn_labels_clean` may be used for validation/comparison only.

## Validation Checklist

- [ ] Row counts match expectations per table
- [ ] No duplicate primary keys (customer_id in dim, composite keys in facts)
- [ ] No NULLs in primary key columns
- [ ] Churned flag is strictly 0 or 1
- [ ] Churn date is NULL when churned = 0
- [ ] Churn date is NOT NULL when churned = 1
- [ ] All foreign keys in facts resolve to dim_customer
- [ ] Date ranges are within plausible bounds

## Edge Cases & Assumptions

- Customers with no subscriptions: treated as not churned (no subscription evidence)
- Customers with multiple subscriptions: use the latest end_date to determine churn
- NULL end_date on a subscription: treated as still active
- Negative renewal_count: floored to 0 (handled in staging)
- Ambiguous date formats (DD/MM vs MM/DD): staging defaults to DD/MM/YYYY

## Troubleshooting

| Problem | Likely Cause | Fix |
|---------|-------------|-----|
| `relation "raw.customers" does not exist` | Setup script not run, or tables still in `public` | Run `sql/setup/setup_database_schemas.sql` |
| `view "staging.*_clean" does not exist` | Staging scripts not executed | Run all `sql/staging/*.sql` in order |
| Duplicate rows in dim_customer | Missing deduplication in core script | Check GROUP BY / DISTINCT logic |
| Churn counts seem wrong | Grace window or analysis_date mismatch | Check that `analysis_date` is derived correctly (or that the hard-coded override falls within the data range); verify the 30-day interval logic |
| NULL dates after cleaning | Unrecognised date format in raw data | Inspect raw values that don't match staging regex patterns |
