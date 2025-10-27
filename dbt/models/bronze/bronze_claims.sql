{{
    config(
        materialized='table',
        tags=['bronze', 'claims']
    )
}}

SELECT
    *,
    CURRENT_TIMESTAMP AS _ingested_at,
    'claims_dummy.csv' AS _source_file
FROM {{ ref('claims_dummy') }}