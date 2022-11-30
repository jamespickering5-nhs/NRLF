import json

from behave import given, when
from lambda_pipeline.types import LambdaContext
from lambda_utils.tests.unit.utils import make_aws_event

from feature_tests.steps.aws.resources.api import producer_create_api_request
from feature_tests.steps.common.common_utils import (
    authorisation_headers,
    render_fhir_template,
    uuid_headers,
)


@given('Producer "{producer}" does not exist in the system')
def given_producer_not_exist(context, producer: str):
    context.producer_exists = False


@given('Producer "{producer}" does not have permission to create Document Pointers for')
def given_producer_no_permission(context, producer: str):
    context.allowed_types = []


@when(
    'Producer "{producer}" creates a Document Reference from DOCUMENT template as {organisation}'
)
def producer_create_document_pointer_from_template(
    context, producer: str, organisation
):
    body = render_fhir_template(context, context.template)
    headers = {
        "NHSD-Client-RP-Details": json.dumps(
            {
                "app.ASID": producer if context.producer_exists else "",
                "nrl.pointer-types": context.allowed_types,
                "developer.app.id": "application id",
                "developer.app.name": "application name",
            }
        ),
        **uuid_headers(context),
        **authorisation_headers(context, organisation),
    }
    context.sent_document = json.dumps(json.loads(body))
    if context.local_test:
        from api.producer.createDocumentReference.index import handler

        event = make_aws_event(body=body, headers=headers)
        lambda_context = LambdaContext()
        response = handler(event, lambda_context)
        context.response_status_code = response["statusCode"]
        context.response_message = response["body"]
    else:
        response = producer_create_api_request(
            data=body, headers=headers, sandbox=context.sandbox_test
        )
        context.response_status_code = response.status_code
        context.response_message = response.text
