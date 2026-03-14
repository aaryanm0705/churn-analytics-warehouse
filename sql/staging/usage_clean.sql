-- =============================================================================
-- staging.usage_clean
-- Assumes ALL raw columns are TEXT.  Every cast is guarded.
-- Grain: 1 row per usage record (customer + day)
-- =============================================================================

CREATE OR REPLACE VIEW staging.usage_clean AS
SELECT
    -- customer_id: text -> int (safe)
    NULLIF(regexp_replace(trim(u.customer_id), '[^0-9]', '', 'g'), '')::int
        AS customer_id,

    -- usage_date: text -> date (handles all formats safely)
    CASE
        -- YYYY-MM-DD
        WHEN trim(u.usage_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN to_date(trim(u.usage_date), 'YYYY-MM-DD')

        -- DD-MM-YYYY
        WHEN trim(u.usage_date) ~ '^\d{2}-\d{2}-\d{4}$'
            THEN to_date(trim(u.usage_date), 'DD-MM-YYYY')

        -- DD/MM/YYYY (first part > 12 = definitely a day)
        WHEN trim(u.usage_date) ~ '^\d{2}/\d{2}/\d{4}$'
             AND substring(trim(u.usage_date), 1, 2)::int > 12
            THEN to_date(trim(u.usage_date), 'DD/MM/YYYY')

        -- MM/DD/YYYY (second part > 12 = definitely a day)
        WHEN trim(u.usage_date) ~ '^\d{2}/\d{2}/\d{4}$'
             AND substring(trim(u.usage_date), 4, 2)::int > 12
            THEN to_date(trim(u.usage_date), 'MM/DD/YYYY')

        -- Ambiguous fallback: assume DD/MM/YYYY
        WHEN trim(u.usage_date) ~ '^\d{2}/\d{2}/\d{4}$'
            THEN to_date(trim(u.usage_date), 'DD/MM/YYYY')

        ELSE NULL
    END AS usage_date_clean,

    -- logins: text -> int (guarded)
    CASE
        WHEN trim(u.logins) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN round(trim(u.logins)::numeric, 0)::int
        ELSE NULL
    END AS logins_clean,

    -- minutes_used: text -> int (guarded)
    CASE
        WHEN trim(u.minutes_used) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN round(trim(u.minutes_used)::numeric, 0)::int
        ELSE NULL
    END AS minutes_used_clean,

    -- core_features_used: text -> int (guarded)
    CASE
        WHEN trim(u.core_features_used) ~ '^[0-9]+(\.[0-9]+)?$'
            THEN round(trim(u.core_features_used)::numeric, 0)::int
        ELSE NULL
    END AS core_features_used_clean,

    -- is_mobile_user: text -> TRUE/FALSE/UNKNOWN
    CASE
        WHEN lower(trim(u.is_mobile_user)) IN ('y', 't', 'true', '1', 'yes')
            THEN 'TRUE'
        WHEN lower(trim(u.is_mobile_user)) IN ('n', 'f', 'false', '0', 'no')
            THEN 'FALSE'
        WHEN u.is_mobile_user IS NULL OR trim(u.is_mobile_user) = ''
            THEN 'UNKNOWN'
        ELSE 'UNKNOWN'
    END AS is_mobile_user_clean

FROM raw.usage u;

-- =============================================================================
-- Validation (run manually in DBeaver after creating the view)
-- =============================================================================
-- SELECT 'total_rows' AS check, COUNT(*) AS value FROM staging.usage_clean;
-- SELECT 'null_customer_id' AS check, COUNT(*) AS value FROM staging.usage_clean WHERE customer_id IS NULL;
-- SELECT 'min_date' AS check, MIN(usage_date_clean)::text AS value FROM staging.usage_clean;
-- SELECT 'max_date' AS check, MAX(usage_date_clean)::text AS value FROM staging.usage_clean;
-- SELECT 'null_logins' AS check, COUNT(*) AS value FROM staging.usage_clean WHERE logins_clean IS NULL;
-- SELECT 'mobile_dist' AS check, is_mobile_user_clean, COUNT(*) AS value FROM staging.usage_clean GROUP BY is_mobile_user_clean;
