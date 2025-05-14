import azure.functions as func
import requests
# from azure.identity import DefaultAzureCredential
import os
import logging
from azure.functions.decorators import FunctionApp, route


from azure.identity import ClientSecretCredential

credential = ClientSecretCredential(
    tenant_id=os.environ["AZURE_TENANT_ID"],
    client_id=os.environ["AZURE_CLIENT_ID"],
    client_secret=os.environ["AZURE_CLIENT_SECRET"]
)


app = FunctionApp()

@app.function_name(name="replicateSalesforce")
@app.route(route="replicateSalesforce", auth_level=func.AuthLevel.ANONYMOUS)
def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Replicate Salesforce Function triggered.')

    try:
        req_body = req.get_json()
        object_name = req_body.get("objectName")
        if not object_name:
            raise ValueError("Missing 'objectName'")
    except Exception as e:
        return func.HttpResponse(f"Invalid request: {e}", status_code=400)

    # Load required values from environment
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    resource_group = os.environ["AZURE_RESOURCE_GROUP"]
    data_factory_name = os.environ["DATA_FACTORY_NAME"]
    pipeline_name = os.environ["ADF_PIPELINE_NAME"]

    # credential = DefaultAzureCredential()
    token = credential.get_token("https://management.azure.com/.default").token

    url = (
        f"https://management.azure.com/subscriptions/{subscription_id}/resourceGroups/{resource_group}"
        f"/providers/Microsoft.DataFactory/factories/{data_factory_name}/pipelines/{pipeline_name}/createRun"
        f"?api-version=2018-06-01"
    )

    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    payload = {
        "parameters": {
            "objectName": object_name
        }
    }

    try:
        logging.info(f"Calling ADF pipeline URL: {url}")
        response = requests.post(url, headers=headers, json=payload, timeout=10)
    except requests.exceptions.Timeout:
        return func.HttpResponse("ADF API call timed out", status_code=504)

    if response.status_code == 200:
        run_id = response.json().get("runId")
        return func.HttpResponse(f"Pipeline triggered successfully. Run ID: {run_id}", status_code=200)
    else:
        logging.error(response.text)
        return func.HttpResponse(f"Failed to trigger pipeline: {response.text}", status_code=500)
