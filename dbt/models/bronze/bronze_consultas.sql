{{
    config(
        materialized='table',
        tags=['bronze', 'consultas']
    )
}}

SELECT
    *,
    CURRENT_TIMESTAMP AS _ingested_at,
    'consultas_dummy.csv' AS _source_file
FROM {{ ref('consultas_dummy') }}