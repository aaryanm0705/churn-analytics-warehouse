-- =============================================================================
-- staging.customers_clean
-- Assumes ALL raw columns are TEXT.  Every cast is guarded.
-- Grain: 1 row per customer
-- =============================================================================

CREATE OR REPLACE VIEW staging.customers_clean AS
SELECT
    -- customer_id: text -> int (safe)
    NULLIF(regexp_replace(trim(c.customer_id), '[^0-9]', '', 'g'), '')::int
        AS customer_id,

    -- signup_date: text -> date (multiple formats)
    CASE
        WHEN trim(c.signup_date) ~ '^\d{2}/\d{2}/\d{4}$'
            THEN to_date(trim(c.signup_date), 'DD/MM/YYYY')
        WHEN trim(c.signup_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN to_date(trim(c.signup_date), 'YYYY-MM-DD')
        WHEN trim(c.signup_date) ~ '^\d{2}-\d{2}-\d{4}$'
            THEN to_date(trim(c.signup_date), 'DD-MM-YYYY')
        ELSE NULL
    END AS signup_date_clean,

    -- age: text -> int (safe)
    CASE
        WHEN trim(c.age) ~ '^[0-9]+$'
            THEN trim(c.age)::int
        ELSE NULL
    END AS age_clean,

    -- country: normalise text values
    CASE
        WHEN lower(trim(c.country)) IN ('de', 'germany')        THEN 'DE'
        WHEN lower(trim(c.country)) IN ('fr', 'france')         THEN 'FR'
        WHEN lower(trim(c.country)) IN ('uk', 'united kingdom') THEN 'UK'
        WHEN lower(trim(c.country)) IN ('nl', 'netherlands')    THEN 'NL'
        WHEN lower(trim(c.country)) IN ('pl', 'poland')         THEN 'PL'
        WHEN lower(trim(c.country)) IN ('it', 'italy')          THEN 'IT'
        WHEN c.country IS NULL OR trim(c.country) = ''           THEN 'UNKNOWN'
        ELSE 'OTHER'
    END AS country_clean,

    -- marketing_channel: normalise (NULL-safe)
    CASE
        WHEN lower(trim(COALESCE(c.marketing_channel, ''))) IN ('instagram ads', 'insta_ads', 'insta')
            THEN 'instagram'
        WHEN lower(trim(COALESCE(c.marketing_channel, ''))) IN ('google', 'google_ads')
            THEN 'google'
        WHEN lower(trim(COALESCE(c.marketing_channel, ''))) IN ('linkedin', 'linkedin ads')
            THEN 'linkedin'
        WHEN lower(trim(COALESCE(c.marketing_channel, ''))) IN ('unkwn', 'unknown')
            THEN 'unknown'
        WHEN c.marketing_channel IS NULL OR trim(c.marketing_channel) = ''
            THEN 'unknown'
        ELSE 'other'
    END AS marketing_channel_clean,

    -- plan_type: normalise
    CASE
        WHEN lower(trim(c.plan_type)) = 'pro'        THEN 'pro'
        WHEN lower(trim(c.plan_type)) = 'basic'      THEN 'basic'
        WHEN lower(trim(c.plan_type)) = 'enterprise' THEN 'enterprise'
        WHEN lower(trim(c.plan_type)) = 'starter'    THEN 'starter'
        WHEN c.plan_type IS NULL OR trim(c.plan_type) = '' THEN 'unknown'
        ELSE 'unknown'
    END AS plan_type_clean,

    -- is_student: text -> categorised label
    CASE
        WHEN lower(trim(c.is_student)) IN ('yes', 'y', '1', 'true')
            THEN 'student'
        WHEN lower(trim(c.is_student)) IN ('no', 'n', '0', 'false')
            THEN 'not_student'
        WHEN c.is_student IS NULL OR trim(c.is_student) = ''
            THEN 'unknown'
        ELSE 'unknown'
    END AS is_student_clean

FROM raw.customers c;

-- =============================================================================
-- Validation (run manually in DBeaver after creating the view)
-- =============================================================================
-- SELECT 'total_rows' AS check, COUNT(*) AS value FROM staging.customers_clean;
-- SELECT 'null_customer_id' AS check, COUNT(*) AS value FROM staging.customers_clean WHERE customer_id IS NULL;
-- SELECT 'min_signup' AS check, MIN(signup_date_clean)::text AS value FROM staging.customers_clean;
-- SELECT 'max_signup' AS check, MAX(signup_date_clean)::text AS value FROM staging.customers_clean;
-- SELECT 'null_age' AS check, COUNT(*) AS value FROM staging.customers_clean WHERE age_clean IS NULL;
-- SELECT 'unknown_country' AS check, COUNT(*) AS value FROM staging.customers_clean WHERE country_clean = 'UNKNOWN';
