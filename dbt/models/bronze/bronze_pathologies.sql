{{
    config(
        materialized='table',
        tags=['bronze', 'pathologies']
    )
}}

SELECT
    *,
    CURRENT_TIMESTAMP AS _ingested_at,
    'pathologies_clean.csv' AS _source_file
FROM {{ ref('pathologies_clean') }}