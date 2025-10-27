{{
    config(
        materialized='table',
        tags=['silver', 'terms']
    )
}}

SELECT
    id AS term_id,
    certificate_number AS member_id, 
    CAST(fecha_inicio_vigencia AS DATE) AS start_date,
    CAST(fecha_fin_periodo AS DATE) AS end_date,
    DATEDIFF('day', CAST(fecha_inicio_vigencia AS DATE), CAST(fecha_fin_periodo AS DATE)) AS duration_days,
    _ingested_at,
    _source_file
FROM {{ ref('bronze_terms') }}