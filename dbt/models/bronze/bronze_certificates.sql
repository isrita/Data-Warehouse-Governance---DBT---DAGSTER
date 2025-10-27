{{
    config(
        materialized='table',
        tags=['bronze', 'certificates']
    )
}}

SELECT
    *,
    CURRENT_TIMESTAMP AS _ingested_at,
    'certificate_dummy.csv' AS _source_file
FROM {{ ref('certificate_dummy') }}