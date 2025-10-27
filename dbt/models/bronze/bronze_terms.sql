{{
    config(
        materialized='table',
        tags=['bronze', 'terms']
    )
}}

SELECT
    *,
    CURRENT_TIMESTAMP AS _ingested_at,
    'terms_dummy.csv' AS _source_file
FROM {{ ref('terms_dummy') }}