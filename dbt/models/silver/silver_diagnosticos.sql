{{
    config(
        materialized='table',
        tags=['silver', 'diagnosticos']
    )
}}

SELECT
    id AS diagnosis_id,
    code AS cie10_code,
    name AS diagnosis_name,
    _ingested_at,
    _source_file
FROM {{ ref('bronze_pathologies') }}