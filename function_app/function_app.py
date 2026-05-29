import json
import os
import uuid
from datetime import datetime, timezone

import azure.functions as func
from azure.cosmos import CosmosClient, exceptions


app = func.FunctionApp(http_auth_level=func.AuthLevel.ANONYMOUS)


def get_container():
    connection_string = os.environ["COSMOS_CONNECTION_STRING"]
    database_name = os.environ["COSMOS_DATABASE_NAME"]
    container_name = os.environ["COSMOS_CONTAINER_NAME"]

    client = CosmosClient.from_connection_string(connection_string)
    database = client.get_database_client(database_name)
    return database.get_container_client(container_name)


def json_response(payload, status_code=200):
    return func.HttpResponse(
        body=json.dumps(payload),
        status_code=status_code,
        mimetype="application/json",
    )


@app.function_name(name="get_items")
@app.route(route="items", methods=["GET"])
def get_items(req: func.HttpRequest) -> func.HttpResponse:
    container = get_container()
    items = list(container.query_items(query="SELECT * FROM c", enable_cross_partition_query=True))
    return json_response(items)


@app.function_name(name="add_item")
@app.route(route="items", methods=["POST"])
def add_item(req: func.HttpRequest) -> func.HttpResponse:
    try:
        payload = req.get_json()
    except ValueError:
        return json_response({"error": "Request body must be valid JSON."}, status_code=400)

    item_name = str(payload.get("item_name", "")).strip()
    if not item_name:
        return json_response({"error": "item_name is required."}, status_code=400)

    item = {
        "id": str(uuid.uuid4()),
        "item_name": item_name,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }

    container = get_container()
    container.upsert_item(item)
    return json_response(item, status_code=201)


@app.function_name(name="delete_item")
@app.route(route="items/{item_id}", methods=["DELETE"])
def delete_item(req: func.HttpRequest) -> func.HttpResponse:
    item_id = str(req.route_params.get("item_id", "")).strip()
    if not item_id:
        return json_response({"error": "item_id is required."}, status_code=400)

    container = get_container()

    found_items = list(
        container.query_items(
            query="SELECT TOP 1 c.id, c.item_name FROM c WHERE c.id = @item_id",
            parameters=[{"name": "@item_id", "value": item_id}],
            enable_cross_partition_query=True,
        )
    )

    if not found_items:
        return json_response({"error": f"Item '{item_id}' was not found."}, status_code=404)

    item = found_items[0]

    try:
        container.delete_item(item=item["id"], partition_key=item["item_name"])
    except exceptions.CosmosResourceNotFoundError:
        return json_response({"error": f"Item '{item_id}' was not found."}, status_code=404)

    return func.HttpResponse(status_code=204)


@app.function_name(name="delete_all_items")
@app.route(route="items", methods=["DELETE"])
def delete_all_items(req: func.HttpRequest) -> func.HttpResponse:
    container = get_container()
    items = list(container.query_items(query="SELECT c.id, c.item_name FROM c", enable_cross_partition_query=True))

    deleted_count = 0
    for item in items:
        container.delete_item(item=item["id"], partition_key=item["item_name"])
        deleted_count += 1

    return json_response({"deleted_count": deleted_count}, status_code=200)
