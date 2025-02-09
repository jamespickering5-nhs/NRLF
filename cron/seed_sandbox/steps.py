from enum import Enum
from logging import Logger
from pathlib import Path
from types import FunctionType
from typing import Any

from lambda_pipeline.types import FrozenDict, LambdaContext, PipelineData
from lambda_utils.logging import MinimalEventModelForLogging, log_action
from pydantic import BaseModel

from cron.seed_sandbox.validators import validate_items
from nrlf.core.dynamodb_types import to_dynamodb_dict
from nrlf.core.model import DocumentPointer
from nrlf.core.repository import Repository
from nrlf.core.validators import json_load

SANDBOX = "sandbox"
TEMPLATE_PATH_TO_DATA = str(Path(__file__).parent / "data" / "{item_type_name}.json")


class LogReference(Enum):
    SEED001 = "Ensuring that this is a sandbox environment"


def _is_sandbox_lambda(context: LambdaContext, environment: str, prefix: str):
    return all(SANDBOX in name for name in (context.function_name, environment, prefix))


def _seed_step_factory(
    item_type: BaseModel,
    template_path_to_data: str = TEMPLATE_PATH_TO_DATA,
    log: bool = True,
) -> FunctionType:
    item_type_name = item_type.kebab()
    path_to_data = template_path_to_data.format(item_type_name=item_type_name)
    with open(path_to_data) as f:
        raw_items = json_load(f)
    dynamodb_items = map(
        lambda raw_item: {k: to_dynamodb_dict(v) for k, v in raw_item.items()},
        raw_items,
    )
    items = list(map(item_type.parse_obj, dynamodb_items))
    valid_items = validate_items(items=items)

    def seeder(
        data: PipelineData,
        context: LambdaContext,
        event: MinimalEventModelForLogging,
        dependencies: FrozenDict[str, Any],
        logger: Logger,
    ) -> PipelineData:
        repository: Repository = dependencies["repository_factory"](item_type)
        for valid_item in valid_items:
            repository.create(valid_item)
        return PipelineData(message="ok")

    if log:

        class _LogReference(Enum):
            SEED00X = f"Seeding {item_type_name} table"

        seeder = log_action(log_reference=_LogReference.SEED00X)(seeder)
    return seeder


@log_action(log_reference=LogReference.SEED001)
def safeguard(
    data: PipelineData,
    context: LambdaContext,
    event: MinimalEventModelForLogging,
    dependencies: FrozenDict[str, Any],
    logger: Logger,
) -> PipelineData:
    if not _is_sandbox_lambda(
        context=context,
        environment=dependencies["environment"],
        prefix=dependencies["prefix"],
    ):
        raise Exception("This Lambda should only be run on sandbox accounts.")
    return PipelineData()


steps = [
    safeguard,
    _seed_step_factory(item_type=DocumentPointer),
]
