{{
    config(
        materialized='table',
        tags=['gold', 'fact', 'llm']
    )
}}


SELECT * FROM main_gold.fact_diagnoses_inferidos