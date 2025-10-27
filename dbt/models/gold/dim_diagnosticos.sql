{{
    config(
        materialized='table',
        tags=['gold', 'dimension']
    )
}}

WITH catalogo_cie10 AS (
    SELECT DISTINCT
        cie10_code,
        diagnosis_name,
        SUBSTRING(cie10_code, 1, 1) AS cie10_category,
        _ingested_at
    FROM {{ ref('silver_diagnosticos') }}
    WHERE cie10_code IS NOT NULL
),

diagnosticos_con_edad_claims AS (
    SELECT 
        c.cie10_code,
        m.member_id,
        m.age AS age_at_diagnosis,
        c.occurrence_date AS diagnosis_date
    FROM {{ ref('silver_claims') }} c
    LEFT JOIN {{ ref('silver_members') }} m 
        ON c.certificate_number = m.certificate_number
    WHERE c.cie10_code IS NOT NULL
),

diagnosticos_con_edad_llm AS (
    SELECT 
        f.extracted_cie10 AS cie10_code,
        f.member_id,
        m.age AS age_at_diagnosis,
        f.consultation_date AS diagnosis_date
    FROM {{ ref('fact_diagnoses_inferidos') }} f
    LEFT JOIN {{ ref('silver_members') }} m 
        ON f.member_id = m.member_id
    WHERE f.extracted_cie10 IS NOT NULL
),

todos_diagnosticos_con_edad AS (
    SELECT * FROM diagnosticos_con_edad_claims
    UNION ALL
    SELECT * FROM diagnosticos_con_edad_llm
)

SELECT
    ROW_NUMBER() OVER (ORDER BY cat.cie10_code) AS diagnosis_key,
    cat.cie10_code,
    cat.diagnosis_name,
    cat.cie10_category,
    COUNT(DISTINCT diag.member_id) AS total_patients,
    COUNT(diag.member_id) AS total_occurrences,
    ROUND(AVG(diag.age_at_diagnosis), 1) AS avg_age_at_diagnosis,
    MIN(diag.age_at_diagnosis) AS min_age_at_diagnosis,
    MAX(diag.age_at_diagnosis) AS max_age_at_diagnosis,
    MIN(diag.diagnosis_date) AS first_occurrence_date,
    MAX(diag.diagnosis_date) AS last_occurrence_date,
    CURRENT_TIMESTAMP AS _created_at
FROM catalogo_cie10 cat
LEFT JOIN todos_diagnosticos_con_edad diag 
    ON cat.cie10_code = diag.cie10_code
GROUP BY 
    cat.cie10_code, 
    cat.diagnosis_name, 
    cat.cie10_category,
    cat._ingested_at
ORDER BY total_patients DESC NULLS LAST, cat.cie10_code