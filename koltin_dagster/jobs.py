from dagster import job, ScheduleDefinition, DefaultScheduleStatus
from assets import run_bronze_layer, run_silver_layer, run_gold_layer, run_dbt_tests

@job
def full_dwh_pipeline():
    bronze = run_bronze_layer()
    silver = run_silver_layer(bronze)
    gold = run_gold_layer(silver)
    run_dbt_tests(gold)

@job
def bronze_only():
    run_bronze_layer()

dwh_daily_schedule = ScheduleDefinition(
    job=full_dwh_pipeline,
    cron_schedule="0 6 * * *",
    default_status=DefaultScheduleStatus.STOPPED,
)

dwh_weekly_schedule = ScheduleDefinition(
    job=full_dwh_pipeline,
    cron_schedule="0 2 * * 0",
    default_status=DefaultScheduleStatus.STOPPED,
)