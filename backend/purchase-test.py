from appstoreserverlibrary.api_client import AppStoreServerAPIClient, APIException
from appstoreserverlibrary.models.Environment import Environment
import json

# Read private key from file
with open("/Users/biubiu/.secrets/.SubscriptionKey_6RCN2GN648.p8", "rb") as key_file:
    private_key = key_file.read()

key_id = "6RCN2GN648"
issuer_id = "69a6de84-f57d-47e3-e053-5b8c7c11a4d1"
bundle_id = "com.tianzhistudio.multiverse"
environment = Environment.SANDBOX

client = AppStoreServerAPIClient(private_key, key_id, issuer_id, bundle_id, environment)

def test_simple_notification():
    try:    
        response = client.request_test_notification()
        print(f"Basic test notification response: {response}")
        return response
    except APIException as e:
        print(f"Error in basic test: {e}")
        return None

def test_subscription_scenarios():
    """Test various subscription notification scenarios"""
    
    # Define test cases with notification type and product ID
    test_cases = [
        # Initial subscription events
        ("SUBSCRIBED", "subscription.photons.500"),
        ("DID_RENEW", "subscription.photons.500"),

        # One-time purchases
        ("DID_PURCHASE", "consumable.photons.100"),
        
        # ("DID_FAIL_TO_RENEW", "subscription.photons.500"),
        # Grace period and expiration
        # ("GRACE_PERIOD_EXPIRED", "subscription.photons.1200"),
        # ("EXPIRED", "subscription.photons.1200"),
        
        # Subscription changes
        # ("DID_CHANGE_RENEWAL_STATUS", "subscription.photons.500"),
        # ("DID_CHANGE_RENEWAL_PREF", "subscription.photons.1200"),
        
        # Refunds and billing issues
        # ("REFUND", "subscription.photons.500"),
        # ("REFUND_DECLINED", "subscription.photons.500"),
        # ("CONSUMPTION_REQUEST", "subscription.photons.500"),
        # ("RENEWAL_EXTENDED", "subscription.photons.500"),
        
        # ("REVOKE", "consumable.photons.100"),
        # ("PRICE_INCREASE", "subscription.photons.1200"),
        
        # # Offer redemption
        # ("OFFER_REDEEMED", "subscription.photons.500")
    ]
    
    results = {}
    
    for event_type, product_id in test_cases:
        try:
            print(f"Testing: {event_type} for {product_id}")
            response = client.request_test_notification(
                notification_type=event_type,
                subtype=None  # Optional parameter
            )
            results[f"{event_type}_{product_id}"] = {
                "success": True,
                "test_notification_token": response.testNotificationToken if hasattr(response, "testNotificationToken") else str(response)
            }
        except APIException as e:
            results[f"{event_type}_{product_id}"] = {
                "success": False,
                "error": str(e)
            }
        except Exception as e:
            results[f"{event_type}_{product_id}"] = {
                "success": False,
                "error": f"Unexpected error: {str(e)}"
            }
    
    # Print formatted results
    print("\n=== SUBSCRIPTION TEST RESULTS ===")
    for test_name, result in results.items():
        status = "✅ SUCCESS" if result["success"] else "❌ FAILED"
        print(f"{test_name}: {status}")
        if result["success"]:
            print(f"  Token: {result['test_notification_token']}")
        else:
            print(f"  Error: {result['error']}")
    
    return results

if __name__ == "__main__":
    print("Running simple notification test...")
    test_simple_notification()
    
    print("\nRunning comprehensive subscription scenarios...")
    test_results = test_subscription_scenarios()
    
    # Save results to file
    with open("subscription_test_results.json", "w") as f:
        json.dump(test_results, f, indent=2)
    
    print("\nTest results saved to subscription_test_results.json")