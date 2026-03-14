-- =============================================================================
-- staging.subscriptions_clean
-- Assumes ALL raw columns are TEXT.  Every cast is guarded.
-- Grain: 1 row per subscription
-- =============================================================================

CREATE OR REPLACE VIEW staging.subscriptions_clean AS
SELECT
    -- subscription_id: text -> int (safe)
    NULLIF(regexp_replace(trim(s.subscription_id), '[^0-9]', '', 'g'), '')::int
        AS subscription_id,

    -- customer_id: text -> int (safe)
    NULLIF(regexp_replace(trim(s.customer_id), '[^0-9]', '', 'g'), '')::int
        AS customer_id,

    -- start_date: text -> date
    CASE
        WHEN trim(s.start_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN to_date(trim(s.start_date), 'YYYY-MM-DD')
        WHEN trim(s.start_date) ~ '^\d{2}-\d{2}-\d{4}$'
            THEN to_date(trim(s.start_date), 'DD-MM-YYYY')
        WHEN trim(s.start_date) ~ '^\d{2}/\d{2}/\d{4}$'
            THEN to_date(trim(s.start_date), 'DD/MM/YYYY')
        ELSE NULL
    END AS start_date_clean,

    -- end_date: text -> date
    CASE
        WHEN trim(s.end_date) ~ '^\d{2}-\d{2}-\d{4}$'
            THEN to_date(trim(s.end_date), 'DD-MM-YYYY')
        WHEN trim(s.end_date) ~ '^\d{2}/\d{2}/\d{4}$'
            THEN to_date(trim(s.end_date), 'DD/MM/YYYY')
        WHEN trim(s.end_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN to_date(trim(s.end_date), 'YYYY-MM-DD')
        ELSE NULL
    END AS end_date_clean,

    -- status: normalise (NULL-safe)
    CASE
        WHEN lower(trim(COALESCE(s.status, ''))) = 'active'    THEN 'active'
        WHEN lower(trim(COALESCE(s.status, ''))) = 'cancelled' THEN 'cancelled'
        WHEN lower(trim(COALESCE(s.status, ''))) = 'churned'   THEN 'churned'
        WHEN s.status IS NULL OR trim(s.status) = ''            THEN 'unknown'
        ELSE 'other'
    END AS status_clean,

    -- cancellation_reason: grouped categories
    CASE
        WHEN s.cancellation_reason IS NULL
             OR trim(s.cancellation_reason) = ''
             OR lower(trim(s.cancellation_reason)) = 'n/a'
            THEN 'unknown'
        WHEN lower(trim(s.cancellation_reason)) = 'too expensive'
            THEN 'high_price'
        WHEN lower(trim(s.cancellation_reason)) = 'lack of use'
            THEN 'low_usage'
        WHEN lower(trim(s.cancellation_reason)) = 'switched to competitor'
            THEN 'competition'
        WHEN lower(trim(s.cancellation_reason)) = 'technical issues'
            THEN 'technical_issues'
        WHEN lower(trim(s.cancellation_reason)) = 'other'
            THEN 'other'
        ELSE 'other'
    END AS cancellation_reason_clean,

    -- renewal_count: text -> int, floor negatives to 0
    CASE
        WHEN trim(s.renewal_count) ~ '^-?[0-9]+$'
            THEN GREATEST(trim(s.renewal_count)::int, 0)
        ELSE NULL
    END AS renewal_count_clean,

    -- monthly_fee: text -> numeric (handles commas, currency symbols)
    CASE
        WHEN s.monthly_fee IS NULL OR trim(s.monthly_fee) = ''
            THEN NULL
        WHEN regexp_replace(trim(s.monthly_fee), '[^0-9\.,]', '', 'g')
             ~ '^[0-9]+([,.][0-9]+)?$'
            THEN replace(
                    regexp_replace(trim(s.monthly_fee), '[^0-9\.,]', '', 'g'),
                    ',',
                    '.'
                 )::numeric(10,2)
        ELSE NULL
    END AS monthly_fee_clean

FROM raw.subscriptions s;

-- =============================================================================
-- Validation (run manually in DBeaver after creating the view)
-- =============================================================================
-- SELECT 'total_rows' AS check, COUNT(*) AS value FROM staging.subscriptions_clean;
-- SELECT 'null_subscription_id' AS check, COUNT(*) AS value FROM staging.subscriptions_clean WHERE subscription_id IS NULL;
-- SELECT 'null_customer_id' AS check, COUNT(*) AS value FROM staging.subscriptions_clean WHERE customer_id IS NULL;
-- SELECT 'min_start' AS check, MIN(start_date_clean)::text AS value FROM staging.subscriptions_clean;
-- SELECT 'max_end' AS check, MAX(end_date_clean)::text AS value FROM staging.subscriptions_clean;
-- SELECT 'null_end_date' AS check, COUNT(*) AS value FROM staging.subscriptions_clean WHERE end_date_clean IS NULL;
-- SELECT 'status_dist' AS check, status_clean, COUNT(*) AS value FROM staging.subscriptions_clean GROUP BY status_clean;
