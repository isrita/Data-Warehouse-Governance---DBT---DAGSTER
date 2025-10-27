# Data Warehouse Governance - Koltin

### Stack Tecnológico

- **Orquestación:** Dagster
- **Transformación:** DBT (Data Build Tool)
- **Storage:** DuckDB (OLAP)
- **Testing:** DBT native tests + custom macros
- **LLM:** Groq API (Llama 3.3-70b) para extracción de diagnósticos


## 1. Arquitectura Medallion

### Bronze Layer
**Propósito:** Raw data ingestion sin transformaciones
- **Naming:** `bronze_<source_name>`
- **Formato:** DuckDB tables
- **Materialización:** Table

**Testing strategy:**
- Row count > 0
- Primary keys no duplicados
- Columnas críticas not null

**Tablas implementadas:**
```
bronze_certificates     → 100 registros
bronze_terms           → 257 registros  
bronze_consultas       → 350 registros
bronze_claims          → 51 registros
bronze_pathologies     → 12,423 códigos CIE-10
```

### Silver Layer
**Propósito:** Datos limpios, normalizados y conformados
- **Naming:** `silver_<entity_name>`
- **Formato:** DuckDB tables
- **Materialización:** Table

**Transformaciones aplicadas:**
- **Type casting:** Conversión de strings a tipos apropiados (INTEGER, DATE, TIMESTAMP)
- **Column renaming:** Estandarización a snake_case (FirstName → first_name)
- **Field concatenation:** Creación de campos derivados (full_name = first_name + last_name)
- **JSON parsing:** Extracción de campos estructurados de closure_json cuando existe
- **Metadata propagation:** Preservación de _ingested_at y _source_file para lineage

**Tablas implementadas:**
```
silver_members         → Clientes únicos con demografía normalizada
silver_terms          → Períodos de membresía con fechas casteadas
silver_consultas      → Consultas con JSON parseado y tipos correctos
silver_claims         → Siniestros con fechas y códigos normalizados
silver_diagnosticos   → Catálogo CIE-10 con nomenclatura estándar
```

**Testing strategy:**
- Integridad referencial (FKs válidas)
- Business rules (ej: start_date < end_date)
- Accepted values para enums
- Rangos válidos (ej: age >= 65)

### Gold Layer
**Propósito:** Esquema estrella para analisis
- **Naming:** `fact_<process>` / `dim_<entity>`
- **Formato:** DuckDB tables
- **Materialización:** Table
- **Grain:** Una fila por interacción

**Tipos de interacción:**
- `INICIO_MEMBRESIA`: Entry point del miembro (257)
- `CONSULTA`: Atención médica presencial/virtual (350)
- `SINIESTRO`: Uso del seguro (51)

**Dimensiones temporales:**
- Year, month, quarter, day_of_week
- Permite análisis de estacionalidad

**Foreign keys:**
- member_id → dim_members
- certificate_number → silver_members

---

#### dim_diagnosticos (12,423 códigos)
Dimensión de diagnósticos CIE-10 con estadísticas de edad.

**Campos clave:**
- `cie10_code`: Código estándar internacional (PK)
- `diagnosis_name`: Descripción en español
- `cie10_category`: Letra inicial (clasificación)
- `avg_age_at_diagnosis`: Edad promedio al diagnóstico
- `total_patients`: Pacientes únicos afectados
- `total_occurrences`: Incidencia total

**Fuentes:**
1. Claims estructurados (51 casos)
2. LLM extraction (70 casos inferidos)

#### dim_members (100 miembros)
Dimensión de clientes con atributos demográficos.

**Campos:**
- member_id (SK), certificate_number (NK)
- age, gender, member_type
- Status flags (activo/inactivo)

#### fact_diagnoses_inferidos (350 registros, 70 extraídos)
Fact table de diagnósticos extraídos mediante LLM de textos clínicos no estructurados.

**Metodología:**
- Input: Campo `closure_json` de consultas médicas
- Modelo: Groq Llama 3.3-70b (free tier)
- Output: Código CIE-10 + confidence score (0-100)

**Resultados:**
- Procesadas: 325/350 (93% - rate limit en últimas 25)
- Extraídas: 70 diagnósticos válidos (20%)
- Confianza promedio: 85-90%
- Alta confianza (>80%): 44 casos (63% de extraídos)

## 2. Nomenclatura

**Tablas:**
```
{layer}_{entity}          → bronze_claims, silver_members
{table_type}_{entity}     → fact_interacciones, dim_diagnosticos
```

### Columnas
- PKs: `<table>_id` o `<entity>_key`
- FKs: `<referenced_table>_id`
- Timestamps: `<action>_at` (created_at, updated_at)
- Flags: `is_<condition>`, `has_<attribute>`
- Fechas: `<event>_date`

## 3. Testing Strategy

### Pirámide de Testing

**Distribución:**
```
Not Null          → 15 tests (columnas críticas)
Unique            → 10 tests (PKs, UKs)
Relationships     → 5 tests (FKs)
Accepted Values   → 4 tests (enums)
Custom Logic      → 2 tests (business rules)
```

**Cobertura por capa:**
- Bronze: Tests básicos (row count, not null en PKs)
- Silver: Tests de integridad + business rules
- Gold: Tests de relaciones + data quality

**Ejecución:**
dbt test                    # Todos los tests
dbt test --select silver   # Por capa
dbt test --select fact_*   # Por patrón

**SLA:** 100% tests passing antes de promoción a producción.

## Data Quality Rules

### Bronze → Silver

1. **Deduplicación:** Por business key (no technical ID)
2. **Type safety:** Casting explícito con manejo de errores
3. **Nullability:** Campos obligatorios validados
4. **Referential integrity:** FKs deben existir en parent

### Silver → Gold

1. **Granularidad:** Definida explícitamente (grain statement)
2. **Completeness:** No left joins con missing keys críticos
3. **Consistency:** Agregaciones verificadas contra source
4. **Timeliness:** Watermarks para CDC (futuro)

### Tolerancia a Errores

- **Bronze:** Zero tolerance (falla el job)
- **Silver:** Log warnings, continúa (retry manual)
- **Gold:** Fail fast (datos incorrectos impactan analytics)

## Orchestration con Dagster

### Jobs Implementados

**1. full_dwh_pipeline**
Pipeline end-to-end con dependencies:
```
bronze → silver → gold → llm_extraction → tests
```
Tiempo de ejecución: ~2 minutos
SLA: 99.5% uptime

**2. bronze_only**
Ingestion rápida sin transformaciones.
Uso: Debugging, cargas urgentes

**3. llm_extraction_only**
Extracción de diagnósticos con LLM.
Prerequisito: Silver layer existente

### Schedules

**Diario (6:00 AM):**
- full_dwh_pipeline
- Actualiza todas las capas
- Notificaciones vía Slack on failure

**Semanal (Domingo 2:00 AM):**
- Refresh completo + vacuum
- Recreación de aggregates
- Health checks

### Monitoring

Dashboard en Dagster UI (localhost:3000):
- Run history con logs
- Asset lineage graph
- Failure alerts
- Execution time trends

## CIE-10: International Classification of Diseases

**Estructura:**
Formato: [Letra][Números].[Decimal]
Ejemplo: I10 = Hipertensión esencial
         E11.9 = Diabetes tipo 2 sin complicaciones
         M81.0 = Osteoporosis post-menopáusica
    
**Categorías principales:**
- A-B: Infecciosas
- C-D: Neoplasias
- E: Endocrinas (diabetes, obesidad)
- I: Circulatorias (hipertensión)
- J: Respiratorias
- M: Musculoesqueléticas
- Z: Factores de riesgo y contactos

## LLM-Powered Diagnosis Extraction

Pipeline de NLP usando LLMs para extracción automática:

1. **Input:** Campo `closure_json` de silver_consultas
2. **Prompt engineering:** Context con catálogo CIE-10 + few-shot examples
3. **Model:** Groq Llama 3.3-70b (latency: ~500ms, cost: $0/350 consultas)
4. **Output:** JSON con `{cie10_code, diagnosis_text, confidence}`
5. **Validation:** Cross-check contra dim_diagnosticos

### Resultados Producción
Input:     350 consultas médicas
Processed: 325 (93% - rate limit en últimas 25)
Extracted: 70 códigos CIE-10 válidos (20%)
Quality:   
  - Alta confianza (>80%): 44 casos
  - Media confianza (50-80%): 18 casos
  - Baja confianza (<50%): 8 casos

## Resultados Finales del Proyecto

### Métricas de Entrega

**Arquitectura:**
Capas:           3 (Bronze, Silver, Gold)
Modelos DBT:     14 (5 bronze + 5 silver + 4 gold)
Seeds:           5 archivos CSV
Tests:           36 (100% passing)
Cobertura:       100% tablas testeadas

**Datos Procesados:**
Registros totales:         13,181
Interacciones clínicas:    658
Diagnósticos CIE-10:       12,423 códigos
Miembros únicos:           100
Diagnósticos inferidos:    70 (20% tasa extracción)
Diagnósticos con edad:     6 (sample limitado)

**Performance:**
Pipeline completo:         2 min
Bronze layer:              15 seg
Silver layer:              30 seg
Gold layer:                45 seg
LLM extraction:            5-7 min (325 requests)
Tests:                     20 seg

**Calidad:**
Tests passing:             100%
Data freshness:            Diario (6 AM)
Lineage coverage:          100%
Documentation:             13/14 modelos documentados

### Entregables Completados

- [x] Pipeline DBT con arquitectura medallion
- [x] 36 tests automatizados (100% passing)
- [x] Documentación de gobernanza (este documento)
- [x] fact_interacciones_clinicas (658 registros, 3 tipos)
- [x] dim_diagnosticos con edad (12,423 códigos)
- [x] dim_members (100 miembros)
- [x] Bonus: LLM extraction (70 diagnósticos)
- [x] Dagster orchestration (3 jobs, 2 schedules)
- [x] Health checks y monitoring
