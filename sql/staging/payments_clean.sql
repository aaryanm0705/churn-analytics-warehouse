-- =============================================================================
-- staging.payments_clean
-- Assumes ALL raw columns are TEXT.  Every cast is guarded.
-- Grain: 1 row per payment event
-- =============================================================================

CREATE OR REPLACE VIEW staging.payments_clean AS
SELECT
    -- customer_id: text -> int (safe)
    NULLIF(regexp_replace(trim(p.customer_id), '[^0-9]', '', 'g'), '')::int
        AS customer_id,

    -- payment_date: text -> date (multiple formats)
    CASE
        WHEN trim(p.payment_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN to_date(trim(p.payment_date), 'YYYY-MM-DD')
        WHEN trim(p.payment_date) ~ '^\d{2}-\d{2}-\d{4}$'
            THEN to_date(trim(p.payment_date), 'DD-MM-YYYY')
        WHEN trim(p.payment_date) ~ '^\d{2}/\d{2}/\d{4}$'
            THEN to_date(trim(p.payment_date), 'DD/MM/YYYY')
        ELSE NULL
    END AS payment_date_clean,

    -- amount: text -> numeric (guarded)
    CASE
        WHEN trim(p.amount) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN trim(p.amount)::numeric(10,2)
        ELSE NULL
    END AS amount_clean,

    -- currency: normalise case
    CASE
        WHEN p.currency IS NULL OR trim(p.currency) = ''
            THEN 'UNKNOWN'
        ELSE upper(trim(p.currency))
    END AS currency_clean,

    -- payment_method: bucket to clean categories (NULL-safe)
    CASE
        WHEN lower(trim(COALESCE(p.payment_method, ''))) IN ('paypal')
            THEN 'paypal'
        WHEN lower(trim(COALESCE(p.payment_method, ''))) IN ('credit_card', 'credit card', 'cc')
            THEN 'credit_card'
        WHEN lower(trim(COALESCE(p.payment_method, ''))) IN ('bank_transfer', 'bank transfer')
            THEN 'bank_transfer'
        WHEN p.payment_method IS NULL OR trim(p.payment_method) = ''
            THEN 'unknown'
        ELSE 'other'
    END AS payment_method_clean,

    -- late_payment_flag: text -> TRUE/FALSE/UNKNOWN
    CASE
        WHEN lower(trim(p.late_payment_flag)) IN ('0', 'false', 'f', 'no', 'n')
            THEN 'FALSE'
        WHEN lower(trim(p.late_payment_flag)) IN ('1', 'true', 't', 'yes', 'y')
            THEN 'TRUE'
        WHEN p.late_payment_flag IS NULL OR trim(p.late_payment_flag) = ''
            THEN 'UNKNOWN'
        ELSE 'UNKNOWN'
    END AS late_payment_flag_clean

FROM raw.payments p;

-- =============================================================================
-- Validation (run manually in DBeaver after creating the view)
-- =============================================================================
-- SELECT 'total_rows' AS check, COUNT(*) AS value FROM staging.payments_clean;
-- SELECT 'null_customer_id' AS check, COUNT(*) AS value FROM staging.payments_clean WHERE customer_id IS NULL;
-- SELECT 'min_date' AS check, MIN(payment_date_clean)::text AS value FROM staging.payments_clean;
-- SELECT 'max_date' AS check, MAX(payment_date_clean)::text AS value FROM staging.payments_clean;
-- SELECT 'null_amount' AS check, COUNT(*) AS value FROM staging.payments_clean WHERE amount_clean IS NULL;
-- SELECT 'late_flag_dist' AS check, late_payment_flag_clean, COUNT(*) AS value FROM staging.payments_clean GROUP BY late_payment_flag_clean;
