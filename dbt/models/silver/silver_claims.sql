{{
    config(
        materialized='table',
        tags=['silver', 'claims']
    )
}}

SELECT
    SINIESTRO AS claim_id,
    STATE AS state,
    CIE10 AS cie10_code,
    DIAGNOSIS AS diagnosis,
    CASE 
        WHEN TRY_CAST(FECHA_OCURRIDO AS INTEGER) IS NOT NULL 
        THEN DATE '1899-12-30' + INTERVAL (CAST(FECHA_OCURRIDO AS INTEGER)) DAY
        ELSE TRY_STRPTIME(FECHA_OCURRIDO, '%d/%m/%Y')::DATE
    END AS occurrence_date,
    CASE 
        WHEN TRY_CAST(FECHA_PAGO AS INTEGER) IS NOT NULL 
        THEN DATE '1899-12-30' + INTERVAL (CAST(FECHA_PAGO AS INTEGER)) DAY
        ELSE TRY_STRPTIME(FECHA_PAGO, '%d/%m/%Y')::DATE
    END AS payment_date,
    CAUSA AS cause,
    TIPO_PAGO AS payment_type,
    CLASF_PROV AS provider_classification,
    CAST(NumCertificado AS INTEGER) AS certificate_number,
    _ingested_at,
    _source_file
FROM {{ ref('bronze_claims') }}