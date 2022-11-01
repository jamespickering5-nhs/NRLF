import copy
from contextlib import contextmanager
from typing import Generator

import boto3
import moto
import pytest
from botocore.exceptions import ClientError
from nrlf.core.errors import DynamoDbError, ItemNotFound
from nrlf.core.model import DocumentPointer
from nrlf.core.repository import (
    Repository,
    _validate_results_within_limits,
    handle_dynamodb_errors,
    to_kebab_case,
)
from nrlf.core.transform import (
    create_document_pointer_from_fhir_json as _create_document_pointer_from_fhir_json,
)
from nrlf.core.types import DynamoDbClient
from nrlf.producer.fhir.r4.tests.test_producer_nrlf_model import read_test_data

DEFAULT_ATTRIBUTE_DEFINITIONS = [
    {"AttributeName": "id", "AttributeType": "S"},
    {"AttributeName": "nhs_number", "AttributeType": "S"},
]
DEFAULT_KEY_SCHEMA = [{"AttributeName": "id", "KeyType": "HASH"}]
TABLE_NAME = to_kebab_case(DocumentPointer.__name__)
API_VERSION = 1
INDEX_NAME = "idx_nhs_number_by_id"
create_document_pointer_from_fhir_json = (
    lambda *args, **kwargs: _create_document_pointer_from_fhir_json(
        *args, api_version=API_VERSION, **kwargs
    )
)


@contextmanager
def mock_dynamodb() -> Generator[DynamoDbClient, None, None]:
    with moto.mock_dynamodb():
        client: DynamoDbClient = boto3.client("dynamodb")
        client.create_table(
            AttributeDefinitions=DEFAULT_ATTRIBUTE_DEFINITIONS,
            TableName=TABLE_NAME,
            KeySchema=DEFAULT_KEY_SCHEMA,
            BillingMode="PAY_PER_REQUEST",
            GlobalSecondaryIndexes=[
                {
                    "IndexName": INDEX_NAME,
                    "KeySchema": [
                        {"AttributeName": "nhs_number", "KeyType": "HASH"},
                        {"AttributeName": "id", "KeyType": "RANGE"},
                    ],
                    "Projection": {
                        "ProjectionType": "ALL",
                    },
                    "ProvisionedThroughput": {
                        "ReadCapacityUnits": 123,
                        "WriteCapacityUnits": 123,
                    },
                },
            ],
        )
        yield client


def test__table_name_prefix():
    repository = Repository(
        item_type=DocumentPointer, client=None, environment_prefix="foo-bar-"
    )
    assert repository.table_name == "foo-bar-document-pointer"


def test_create_document_pointer():
    fhir_json = read_test_data("nrlf")
    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)

    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        response = client.scan(TableName=TABLE_NAME)

    (item,) = response["Items"]
    recovered_item = DocumentPointer(**item)
    assert recovered_item.dict() == core_model.dict()


def test_cant_create_if_item_already_exists():
    fhir_json = read_test_data("nrlf")
    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    with pytest.raises(DynamoDbError), mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        repository.create(item=core_model)


def test_read_document_pointer():
    fhir_json = read_test_data("nrlf")
    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        result = repository.read(
            KeyConditionExpression="id = :id",
            ExpressionAttributeValues={":id": core_model.id.dict()},
        )
    assert core_model == result


def test_read_document_pointer_throws_error_when_items_key_missing():
    fhir_json = read_test_data("nrlf")
    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    with pytest.raises(ItemNotFound), mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        repository.read(
            KeyConditionExpression="id = :id",
            ExpressionAttributeValues={":id": {"S": "badKey"}},
        )


def test_update_document_pointer():
    fhir_json = read_test_data("nrlf")

    updated_fhir_json = read_test_data("nrlf")
    updated_fhir_json["content"][0]["attachment"][
        "url"
    ] = "https://example.org/different_doc.pdf"

    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    updated_core_model = create_document_pointer_from_fhir_json(
        fhir_json=updated_fhir_json
    )

    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        repository.update(item=updated_core_model)
        response = client.scan(TableName=TABLE_NAME)

    (item,) = response["Items"]
    recovered_item = DocumentPointer(**item)
    assert recovered_item.dict() == updated_core_model.dict()


def test_update_document_pointer_doesnt_update_if_item_doesnt_exist():
    updated_fhir_json = read_test_data("nrlf")
    updated_fhir_json["content"][0]["attachment"][
        "url"
    ] = "https://example.org/different_doc.pdf"

    updated_core_model = create_document_pointer_from_fhir_json(
        fhir_json=updated_fhir_json
    )

    with pytest.raises(DynamoDbError), mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.update(item=updated_core_model)


def test_supersede_creates_new_item_and_deletes_existing():

    fhir_json = read_test_data("nrlf")
    core_model_for_create = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    core_model_for_create.id.__root__ = (
        "ACUTE MENTAL HEALTH UNIT & DAY HOSPITAL|1234567891"
    )
    core_model_for_delete = create_document_pointer_from_fhir_json(fhir_json=fhir_json)

    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model_for_delete)
        repository.supersede(
            create_item=core_model_for_create,
            delete_item_id=core_model_for_delete.id.dict(),
        )

        response_for_created_item = repository.read(
            KeyConditionExpression="id = :id",
            ExpressionAttributeValues={":id": core_model_for_create.id.dict()},
        )
        try:
            repository.read(
                KeyConditionExpression="id = :id",
                ExpressionAttributeValues={":id": core_model_for_delete.id.dict()},
            )
        except ItemNotFound as error:
            assert error.args[0] == "Item could not be found"

    assert response_for_created_item == core_model_for_create


def test_supersede_id_exists_raises_transaction_canceled_exception():

    fhir_json = read_test_data("nrlf")
    core_model_for_create = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    core_model_for_create.id.__root__ = (
        "ACUTE MENTAL HEALTH UNIT & DAY HOSPITAL|1234567891"
    )

    core_model_for_delete = create_document_pointer_from_fhir_json(fhir_json=fhir_json)

    with pytest.raises(Exception), mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model_for_delete)
        repository.create(item=core_model_for_create)
        repository.supersede(
            create_item=core_model_for_create,
            delete_item_id=core_model_for_delete.id.dict(),
        )


def test_hard_delete():
    fhir_json = read_test_data("nrlf")
    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)

    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        repository.hard_delete(core_model.id.dict())
        response = client.scan(TableName=TABLE_NAME)
    assert len(response["Items"]) == 0


def test_wont_hard_delete_if_item_doesnt_exist():
    with pytest.raises(DynamoDbError), mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.hard_delete(id={"S": "no"})


@handle_dynamodb_errors()
def raise_exception(exception):
    raise exception


@pytest.mark.parametrize(
    ["exception_param", "expected_exception"],
    (
        [Exception, Exception],
        [TypeError, TypeError],
        [ValueError, ValueError],
        [
            ClientError({"Error": {"Code": "ConditionalCheckFailedException"}}, "test"),
            DynamoDbError,
        ],
    ),
)
def test_wrapper_exception_handler(exception_param, expected_exception):
    with pytest.raises(expected_exception):
        raise_exception(exception_param)


def test_search_returns_multiple_values_with_same_nhs_number():
    fhir_json = read_test_data("nrlf")
    fhir_json_2 = copy.deepcopy(fhir_json)
    fhir_json_2["id"] = "spam|1243356678"

    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    core_model_2 = create_document_pointer_from_fhir_json(fhir_json=fhir_json_2)

    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        repository.create(item=core_model_2)
        items = repository.search(
            index_name=INDEX_NAME,
            KeyConditionExpression="nhs_number = :nhs_number",
            ExpressionAttributeValues={":nhs_number": {"S": "9278693472"}},
        )
    assert len(items) == 2


def test_search_returns_single_value():
    fhir_json = read_test_data("nrlf")
    fhir_json_2 = copy.deepcopy(fhir_json)
    fhir_json_2["subject"]["identifier"]["value"] = "3137554160"
    fhir_json_2["id"] = "spam|1243356678"

    core_model = create_document_pointer_from_fhir_json(fhir_json=fhir_json)
    core_model_2 = create_document_pointer_from_fhir_json(fhir_json=fhir_json_2)

    with mock_dynamodb() as client:
        repository = Repository(item_type=DocumentPointer, client=client)
        repository.create(item=core_model)
        repository.create(item=core_model_2)
        items = repository.search(
            index_name=INDEX_NAME,
            KeyConditionExpression="nhs_number = :nhs_number",
            ExpressionAttributeValues={":nhs_number": {"S": "9278693472"}},
        )

    assert len(items) == 1


def test_validate_results_less_than_100_items():
    array_size = 99
    items = [""] * array_size
    request_results = {"Items": items, "Count": array_size, "ScannedCount": array_size}
    result = _validate_results_within_limits(request_results)
    assert result == request_results


def test_validate_results_throws_exception_when_more_than_100_items():
    array_size = 101
    items = [""] * array_size
    request_results = {"Items": items, "Count": array_size, "ScannedCount": array_size}

    with pytest.raises(Exception) as error:
        _validate_results_within_limits(request_results)
        assert (
            error.value
            == "DynamoDB has returned too many results, pagination not implemented yet"
        )


def test_validate_results_throws_exception_when_last_evaluated_key_exists():
    array_size = 98
    items = [""] * array_size
    request_results = {
        "Items": items,
        "Count": array_size,
        "ScannedCount": array_size,
        "LastEvaluatedKey": array_size,
    }

    with pytest.raises(Exception) as error:
        _validate_results_within_limits(request_results)
        assert (
            error.value
            == "DynamoDB has returned too many results, pagination not implemented yet"
        )
