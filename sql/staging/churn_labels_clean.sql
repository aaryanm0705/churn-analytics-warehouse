-- =============================================================================
-- staging.churn_labels_clean
-- Assumes ALL raw columns are TEXT.  Every cast is guarded.
-- Grain: 1 row per customer
-- Note: this view is for reference/comparison only.
--       Authoritative churn labels are derived in analytics.churn_labels.
-- =============================================================================

CREATE OR REPLACE VIEW staging.churn_labels_clean AS
SELECT
    -- customer_id: text -> int (safe)
    NULLIF(regexp_replace(trim(cl.customer_id), '[^0-9]', '', 'g'), '')::int
        AS customer_id,

    -- churn_date: text -> date
    CASE
        WHEN trim(cl.churn_date) ~ '^\d{2}-\d{2}-\d{4}$'
            THEN to_date(trim(cl.churn_date), 'DD-MM-YYYY')
        WHEN trim(cl.churn_date) ~ '^\d{4}-\d{2}-\d{2}$'
            THEN to_date(trim(cl.churn_date), 'YYYY-MM-DD')
        ELSE NULL
    END AS churn_date_clean,

    -- churn_flag: text -> int 0/1 (guarded)
    CASE
        WHEN trim(cl.churn_flag) IN ('1', 'true', 'yes', 'y')  THEN 1
        WHEN trim(cl.churn_flag) IN ('0', 'false', 'no', 'n')  THEN 0
        ELSE NULL
    END AS churn_flag

FROM raw.churn_labels cl;

-- =============================================================================
-- Validation (run manually in DBeaver after creating the view)
-- =============================================================================
-- SELECT 'total_rows' AS check, COUNT(*) AS value FROM staging.churn_labels_clean;
-- SELECT 'null_customer_id' AS check, COUNT(*) AS value FROM staging.churn_labels_clean WHERE customer_id IS NULL;
-- SELECT 'churn_flag_dist' AS check, churn_flag, COUNT(*) AS value FROM staging.churn_labels_clean GROUP BY churn_flag;
-- SELECT 'min_churn_date' AS check, MIN(churn_date_clean)::text AS value FROM staging.churn_labels_clean;
-- SELECT 'max_churn_date' AS check, MAX(churn_date_clean)::text AS value FROM staging.churn_labels_clean;
-- SELECT 'null_flag' AS check, COUNT(*) AS value FROM staging.churn_labels_clean WHERE churn_flag IS NULL;
