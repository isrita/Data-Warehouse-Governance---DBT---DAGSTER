{{
    config(
        materialized='table',
        tags=['gold', 'fact']
    )
}}

WITH consultas_interactions AS (
    SELECT
        'CONSULTA' AS interaction_type,
        CAST(c.consulta_id AS VARCHAR) AS interaction_id,
        c.member_id,
        m.certificate_number,
        c.consultation_date AS interaction_date,
        c.specialty,
        c.doctor_id,
        NULL AS cie10_code,
        NULL AS claim_id,
        c.closure_json,
        c._ingested_at
    FROM {{ ref('silver_consultas') }} c
    LEFT JOIN {{ ref('silver_members') }} m ON c.member_id = m.member_id
),

claims_interactions AS (
    SELECT
        'SINIESTRO' AS interaction_type,
        c.claim_id AS interaction_id,
        m.member_id,
        c.certificate_number,
        c.occurrence_date AS interaction_date,
        NULL AS specialty,
        NULL AS doctor_id,
        c.cie10_code,
        c.claim_id,
        NULL AS closure_json,
        c._ingested_at
    FROM {{ ref('silver_claims') }} c
    LEFT JOIN {{ ref('silver_members') }} m ON c.certificate_number = m.certificate_number
),

terms_interactions AS (
    SELECT
        'INICIO_MEMBRESIA' AS interaction_type,
        CAST(t.term_id AS VARCHAR) AS interaction_id,
        t.member_id,
        m.certificate_number,
        t.start_date AS interaction_date,
        NULL AS specialty,
        NULL AS doctor_id,
        NULL AS cie10_code,
        NULL AS claim_id,
        NULL AS closure_json,
        t._ingested_at
    FROM {{ ref('silver_terms') }} t
    LEFT JOIN {{ ref('silver_members') }} m ON t.member_id = m.member_id
),

all_interactions AS (
    SELECT * FROM consultas_interactions
    UNION ALL
    SELECT * FROM claims_interactions
    UNION ALL
    SELECT * FROM terms_interactions
)

SELECT
    ROW_NUMBER() OVER (ORDER BY interaction_date, interaction_id) AS interaction_key,
    *,
    YEAR(interaction_date) AS year,
    MONTH(interaction_date) AS month,
    DAYOFWEEK(interaction_date) AS day_of_week
FROM all_interactions
ORDER BY interaction_date