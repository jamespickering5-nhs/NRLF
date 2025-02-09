from enum import Enum
from logging import Logger
from typing import Any

from lambda_pipeline.types import FrozenDict, LambdaContext, PipelineData

from nrlf.core.common_steps import (
    make_common_log_action,
    parse_headers,
    parse_path_id,
    read_subject_from_path,
)
from nrlf.core.model import APIGatewayProxyEventModel, DocumentPointer
from nrlf.core.repository import Repository
from nrlf.core.validators import json_loads, validate_document_reference_string

log_action = make_common_log_action()


class LogReference(Enum):
    READ001 = "Reading document reference"


@log_action(log_reference=LogReference.READ001)
def read_document_reference(
    data: PipelineData,
    context: LambdaContext,
    event: APIGatewayProxyEventModel,
    dependencies: FrozenDict[str, Any],
    logger: Logger,
) -> PipelineData:
    repository: Repository = dependencies["repository"]
    pointer_types = data["pointer_types"]

    document_pointer: DocumentPointer = repository.read_item(
        data["pk"], type=pointer_types
    )

    validate_document_reference_string(document_pointer.document.__root__)

    return PipelineData(**json_loads(document_pointer.document.__root__))


steps = [
    read_subject_from_path,
    parse_headers,
    parse_path_id,
    read_document_reference,
]
