from appstoreserverlibrary.api_client import AppStoreServerAPIClient, APIException
from appstoreserverlibrary.models.Environment import Environment

# Read private key from file
with open("/Users/biubiu/.secrets/.SubscriptionKey_6RCN2GN648.p8", "rb") as key_file:
    private_key = key_file.read()

key_id = "6RCN2GN648"
issuer_id = "69a6de84-f57d-47e3-e053-5b8c7c11a4d1"
bundle_id = "com.tianzhistudio.multiverse"
environment = Environment.SANDBOX

client = AppStoreServerAPIClient(private_key, key_id, issuer_id, bundle_id, environment)

try:    
    response = client.request_test_notification()
    print(response)
except APIException as e:
    print(e)