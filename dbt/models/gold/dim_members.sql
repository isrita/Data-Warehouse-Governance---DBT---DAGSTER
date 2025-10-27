{{
    config(
        materialized='table',
        tags=['gold', 'dimension']
    )
}}

SELECT
    member_id AS member_key,
    member_id,
    certificate_number,
    full_name,
    email,
    age,
    CASE 
        WHEN age < 65 THEN '<65'
        WHEN age BETWEEN 65 AND 74 THEN '65-74'
        WHEN age BETWEEN 75 AND 84 THEN '75-84'
        ELSE '85+'
    END AS age_group,
    birth_date,
    city,
    gender,
    _ingested_at
FROM {{ ref('silver_members') }}