{{
    config(
        materialized='table',
        tags=['silver', 'members']
    )
}}

SELECT
    id AS member_id,
    nombre AS full_name,
    email,
    YEAR(CURRENT_DATE) - YEAR(CAST(fecha_nacimiento AS DATE)) AS age, 
    ciudad AS city,
    CAST(fecha_nacimiento AS DATE) AS birth_date,
    numero_certificado AS certificate_number,
    sexo AS gender,
    _ingested_at,
    _source_file
FROM {{ ref('bronze_certificates') }}