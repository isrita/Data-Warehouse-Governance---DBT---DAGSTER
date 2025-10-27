from dagster import AssetExecutionContext, OpExecutionContext, op, job, asset
from dagster_dbt import DbtCliResource
from pathlib import Path

DBT_PROJECT_DIR = Path(__file__).parent.parent / "dbt"

@op
def run_bronze_layer(context: OpExecutionContext, dbt: DbtCliResource):
    """Ejecutar capa Bronze"""
    context.log.info("Starting Bronze layer...")
    result = dbt.cli(["seed"]).wait()
    context.log.info("Seeds loaded")
    result = dbt.cli(["run", "--select", "tag:bronze"]).wait()
    context.log.info("Bronze models created")
    return "bronze_complete"

@op
def run_silver_layer(context: OpExecutionContext, dbt: DbtCliResource, bronze_complete: str):
    """Ejecutar capa Silver"""
    context.log.info("Starting Silver layer...")
    result = dbt.cli(["run", "--select", "tag:silver"]).wait()
    context.log.info("Silver models created")
    return "silver_complete"

@op
def run_gold_layer(context: OpExecutionContext, dbt: DbtCliResource, silver_complete: str):
    """Ejecutar capa Gold"""
    context.log.info("Starting Gold layer...")
    result = dbt.cli(["run", "--select", "tag:gold"]).wait()
    context.log.info("Gold models created")
    return "gold_complete"

@op
def run_dbt_tests(context: OpExecutionContext, dbt: DbtCliResource, gold_complete: str):
    """Ejecutar tests de DBT"""
    context.log.info("Running DBT tests...")
    result = dbt.cli(["test"]).wait()
    context.log.info("Tests completed")
    return "tests_complete"