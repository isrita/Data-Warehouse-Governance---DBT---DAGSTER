{{
    config(
        materialized='table',
        tags=['silver', 'consultas']
    )
}}

SELECT
    id AS consulta_id,
    certificate_number AS member_id, 
    CAST(fecha_consulta AS DATE) AS consultation_date,
    specialty,
    placed_by AS doctor_id,
    closure AS closure_json,
    _ingested_at,
    _source_file
FROM {{ ref('bronze_consultas') }}