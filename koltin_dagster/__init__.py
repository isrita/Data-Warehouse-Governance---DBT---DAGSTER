from dagster import Definitions, ScheduleDefinition, DefaultScheduleStatus
from dagster_dbt import DbtCliResource
from pathlib import Path
import sys

current_dir = Path(__file__).parent
sys.path.insert(0, str(current_dir))

import jobs

DBT_PROJECT_DIR = current_dir.parent / "dbt"

dbt_resource = DbtCliResource(
    project_dir=str(DBT_PROJECT_DIR),
    profiles_dir=str(DBT_PROJECT_DIR),
    target="dev",
)

daily_schedule = ScheduleDefinition(
    name="koltin_daily_refresh",
    job=jobs.full_dwh_pipeline,
    cron_schedule="0 6 * * *",
    default_status=DefaultScheduleStatus.STOPPED,
)

weekly_schedule = ScheduleDefinition(
    name="koltin_weekly_refresh",
    job=jobs.full_dwh_pipeline,
    cron_schedule="0 2 * * 0",
    default_status=DefaultScheduleStatus.STOPPED,
)

defs = Definitions(
    jobs=[
        jobs.full_dwh_pipeline,
        jobs.bronze_only,
    ],
    schedules=[
        daily_schedule,
        weekly_schedule,
    ],
    resources={"dbt": dbt_resource},
)
