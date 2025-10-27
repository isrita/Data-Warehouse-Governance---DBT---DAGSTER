# Data-Warehouse-Governance---DBT---DAGSTER

# Koltin Health - Data Warehouse

Pipeline end-to-end de Data Engineering para Koltin, plataforma de seguros médicos y membresías de medicina preventiva para adultos mayores (+65 años).

## Contexto del Proyecto

Koltin es una compañía encargada de brindar un seguro médico y una membresía con atención de medicina preventiva para Grandes Personas (personas de más de 65 años). Este DataWarehouse procesa diferentes tipos de data de nuestros miembros para habilitar analytics sobre interacciones clínicas y gestión de riesgos.

### Fuentes de Datos

1. **Certificados** - Información de los clientes
2. **Terms** - Información de los períodos en que alguien estuvo en Koltin
3. **Consultas Médicas** - Información obtenida cuando una persona se atiende con un médico de Koltin (dos versiones por evolución del sistema)
4. **Siniestros** - Cuando la persona usa su seguro porque tuvo un siniestro

## Arquitectura

Pipeline basado en el patrón **Medallion Architecture** con tres capas:

Bronze (Raw) → Silver (Clean) → Gold (Analytics)

**Stack Tecnológico:**
- **Orquestación:** Dagster
- **Transformación:** DBT (Data Build Tool)
- **Storage:** DuckDB
- **Testing:** 36 tests automatizados
- **LLM:** Groq API (Llama 3.3-70b)

## Entregables Implementados

### 1. Pipeline DBT con Pruebas
-  14 modelos (5 bronze + 5 silver + 4 gold)
-  36 tests automatizados (100% passing)
-  Lineage completo documentado

### 2. Documentación de Políticas del DWH
-  GOVERNANCE.md - Políticas completas de gobernanza
-  Nomenclatura, testing strategy, retención de datos
-  Documentación inline en todos los modelos

### 3. Tabla de Interacciones Clínicas
-  `fact_interacciones_clinicas` (658 registros)
-  Tipos: INICIO_MEMBRESIA, CONSULTA, SINIESTRO
-  Permite análisis del journey completo del paciente

### 4. Tabla de Diagnósticos
-  `dim_diagnosticos` (12,423 códigos CIE-10)
-  **Incluye edad al momento del diagnóstico**
-  Estadísticas: total pacientes, ocurrencias, edad promedio/min/max

### 5. Otras Tablas Relevantes
-  `dim_members` - Dimensión de miembros
-  `fact_diagnoses_inferidos` - Diagnósticos extraídos por LLM

### 6. Bonus Track: LLM para Extracción de Diagnósticos
-  70 diagnósticos CIE-10 extraídos de textos clínicos no estructurados
-  Confianza promedio: 85-90%
-  Script automatizado con Groq API

## Instalación y Configuración

### Prerequisitos
- Python 3.9+
- Git

### 1. Clonar el Repositorio

git clone [https://github.com/isrita/koltin-dwh.git](https://github.com/isrita/Data-Warehouse-Governance---DBT---DAGSTER)
cd koltin-dwh


### 2. Crear Entorno Virtual

# Windows
python -m venv venv
.\venv\Scripts\Activate.ps1

### 3. Instalar Dependencias

pip install dbt-duckdb dagster dagster-dbt dagster-webserver groq python-dotenv

### 4. Configurar DBT

cd dbt
dbt deps
dbt seed

## Ejecutar el Pipeline

### Opción 1: Pipeline Completo con Dagster (Recomendado)

# Desde la raíz del proyecto
dagster dev -m koltin_dagster

Luego abre http://localhost:3000 y ejecuta el job `full_dwh_pipeline`.

![DAGSTER]([https://raw.githubusercontent.com/isrita/Data-Warehouse-Governance---DBT---DAGSTER/main/pipelinedagster.png](https://github.com/user-attachments/assets/449ecb96-c885-4bc4-b5b7-48045e390316))


### Opción 2: Solo DBT

cd dbt

dbt run
dbt test

# Por capas
dbt run --select tag:bronze
dbt run --select tag:silver
dbt run --select tag:gold

## Bonus Track: Extracción con LLM

El proyecto incluye un pipeline de extracción automática de diagnósticos CIE-10 desde textos clínicos no estructurados usando Groq API.

### Configuración

# 1. Obtener API key gratuita en https://console.groq.com
# 2. Configurar variable de entorno
export GROQ_API_KEY="tu-api-key"

# Windows PowerShell
$env:GROQ_API_KEY = "tu-api-key"

### Ejecución

python scripts/extract_diagnoses_groq.py

**Resultados:**
- 325/350 consultas procesadas (rate limit en últimas 25)
- 70 diagnósticos extraídos (20% de recall)
- Confianza promedio: 85-90%


## Estructura del Proyecto

| Directorio | Descripción |
|------------|-------------|
| `dbt/models/bronze/` | **Bronze Layer** - Raw data ingestion (5 modelos) |
| `dbt/models/silver/` | **Silver Layer** - Cleaned & normalized (5 modelos) |
| `dbt/models/gold/` | **Gold Layer** - Analytics-ready (4 modelos) |
| `dbt/seeds/` | Archivos CSV fuente (5 archivos) |
| `koltin_dagster/` | **Orchestration** - Jobs, assets y schedules |
| `scripts/` | Scripts Python (LLM extraction) |
| `docs/images/` | Imágenes para documentación |
| `GOVERNANCE.md` |  Políticas de gobernanza del DWH |

---

## Casos de Uso Habilitados

1. **Patient Journey Analysis** - Historia completa del paciente
2. **Incidencia por Diagnóstico** - Análisis epidemiológico
3. **Utilización del Seguro** - Métricas de siniestros
4. **Análisis de Estacionalidad** - Patrones temporales
5. **Extracción Automática** - Diagnósticos desde texto libre

---

## Autor

**Israel Jesus Bonilla**  
Data Engineer  
[LinkedIn](https://www.linkedin.com/in/israel-bonilla-de-la-cruz/) | [GitHub](https://github.com/isrita)
