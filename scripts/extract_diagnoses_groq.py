import duckdb
import os
from groq import Groq
import json
from pathlib import Path

DB_PATH = Path(__file__).parent.parent / "dbt" / "koltin_dwh.duckdb"
GROQ_API_KEY = os.getenv("GROQ_API_KEY")

if not GROQ_API_KEY:
    raise ValueError(" Set GROQ_API_KEY environment variable")

client = Groq(api_key=GROQ_API_KEY)

def load_cie10_catalog():
    """Cargar catálogo CIE-10"""
    conn = duckdb.connect(str(DB_PATH))
    catalog = conn.execute("""
        SELECT cie10_code, diagnosis_name, cie10_category
        FROM main_gold.dim_diagnosticos
        ORDER BY cie10_code
    """).fetchall()
    conn.close()
    return catalog

def extract_diagnosis_groq(text: str, specialty: str, cie10_sample: str) -> dict:
    """Extraer diagnóstico con Groq"""
    
    prompt = f"""Eres un médico especializado en codificación CIE-10.

Analiza esta consulta de {specialty} y extrae el diagnóstico.

TEXTO DE CONSULTA:
{text}

CÓDIGOS CIE-10 DISPONIBLES (ejemplos):
{cie10_sample}

RESPONDE SOLO CON JSON (sin markdown):
{{
    "diagnosis_text": "descripción del diagnóstico",
    "cie10_code": "código exacto (ej: J06.9)",
    "confidence": 85
}}"""

    try:
        response = client.chat.completions.create(
            model="llama-3.3-70b-versatile", 
            messages=[{"role": "user", "content": prompt}],
            temperature=0.3,
            max_tokens=300
        )
        
        response_text = response.choices[0].message.content.strip()
        
        if '```json' in response_text:
            response_text = response_text.split('```json')[1].split('```')[0]
        elif '```' in response_text:
            response_text = response_text.split('```')[1].split('```')[0]
        
        result = json.loads(response_text.strip())
        
        return {
            "diagnosis_text": result.get("diagnosis_text"),
            "cie10_code": result.get("cie10_code"),
            "confidence": result.get("confidence", 70),
            "reasoning": "Groq Llama 3.1 extraction"
        }
        
    except Exception as e:
        print(f"  Error: {e}")
        return {
            "diagnosis_text": None,
            "cie10_code": None,
            "confidence": 0,
            "reasoning": str(e)
        }

def process_all_consultas():
    """Procesar todas las consultas"""
    
    print("📚 Cargando catálogo CIE-10...")
    cie10_catalog = load_cie10_catalog()
    cie10_sample = "\n".join([f"- {code}: {name}" for code, name, _ in cie10_catalog[:50]])
    print(f"✓ {len(cie10_catalog)} códigos cargados")
    
    conn = duckdb.connect(str(DB_PATH))
    
    consultas = conn.execute("""
        SELECT consulta_id, member_id, consultation_date, specialty, closure_json
        FROM main_silver.silver_consultas
        WHERE closure_json IS NOT NULL
    """).fetchall()
    
    print(f" Procesando {len(consultas)} consultas con Groq...")
    
    results = []
    for i, (c_id, m_id, c_date, specialty, closure) in enumerate(consultas, 1):
        print(f"[{i}/{len(consultas)}] Consulta {c_id} ({specialty})...", end=" ")
        
        diagnosis = extract_diagnosis_groq(closure, specialty, cie10_sample)
        
        results.append({
            "consulta_id": c_id,
            "member_id": m_id,
            "consultation_date": str(c_date),
            "specialty": specialty,
            "extracted_diagnosis": diagnosis["diagnosis_text"],
            "extracted_cie10": diagnosis["cie10_code"],
            "confidence_score": diagnosis["confidence"],
            "extraction_reasoning": diagnosis["reasoning"]
        })
        
        if diagnosis['cie10_code']:
            print(f"✓ {diagnosis['cie10_code']} ({diagnosis['confidence']}%)")
        else:
            print("  No code extracted")
    
    # Guardar en DuckDB
    print(" Guardando resultados...")
    
    conn.execute("DROP TABLE IF EXISTS main_gold.fact_diagnoses_inferidos")
    
    conn.execute("""
        CREATE TABLE main_gold.fact_diagnoses_inferidos (
            consulta_id INTEGER,
            member_id INTEGER,
            consultation_date DATE,
            specialty VARCHAR,
            extracted_diagnosis VARCHAR,
            extracted_cie10 VARCHAR,
            confidence_score INTEGER,
            extraction_reasoning VARCHAR,
            _extracted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    
    for r in results:
        conn.execute("""
            INSERT INTO main_gold.fact_diagnoses_inferidos 
            (consulta_id, member_id, consultation_date, specialty, 
             extracted_diagnosis, extracted_cie10, confidence_score, extraction_reasoning)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            r['consulta_id'], r['member_id'], r['consultation_date'], 
            r['specialty'], r['extracted_diagnosis'], r['extracted_cie10'],
            r['confidence_score'], r['extraction_reasoning']
        ])
    
    conn.close()
    
    with_cie10 = sum(1 for r in results if r['extracted_cie10'])
    high_conf = sum(1 for r in results if r['confidence_score'] > 70)
    
    print(f" Completado:")
    print(f"   Total: {len(results)}")
    print(f"   Con CIE-10: {with_cie10}")
    print(f"   Alta confianza (>70): {high_conf}")
    
    return results

if __name__ == "__main__":
    process_all_consultas()