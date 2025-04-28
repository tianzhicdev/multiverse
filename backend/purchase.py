from flask import Flask, request, jsonify
import logging
from appstoreserverlibrary.api_client import AppStoreServerAPIClient, APIException
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.models.NotificationTypeV2 import NotificationTypeV2
from appstoreserverlibrary.signed_data_verifier import VerificationException, SignedDataVerifier

# Configure logging
logger = logging.getLogger(__name__)

def load_root_certificates():
    with open("/usr/local/.secrets/apple/AppleRootCA-G3.cer", "rb") as f:
        return [f.read()]

def register_routes(app):
    @app.route('/purchase', methods=['POST'])
    def process_purchase():
        try:
            # Log the purchase request
            logger.info("Received purchase request")
            logger.info(f"Request headers: {dict(request.headers)}")
            logger.info(f"Request data: {request.get_json()}")
            
            # Apple Server Notification processing
            data = request.get_json()
            
            # Read private key from file
            with open("/usr/local/.secrets/apple/.SubscriptionKey_6RCN2GN648.p8", "rb") as key_file:
                private_key = key_file.read()

            key_id = "6RCN2GN648"
            issuer_id = "69a6de84-f57d-47e3-e053-5b8c7c11a4d1"
            bundle_id = "com.tianzhistudio.multiverse"
            environment = Environment.SANDBOX
            app_apple_id = None  # Only required for Production environment
            
            # Initialize the SignedDataVerifier
            root_certificates = load_root_certificates()  # Load root certificates if needed
            enable_online_checks = True
            signed_data_verifier = SignedDataVerifier(root_certificates, enable_online_checks, 
                                                    environment, bundle_id, app_apple_id)
            
            # Process the signed notification payload
            try:
                # Extract signedPayload from the request
                signed_payload = data.get('signedPayload')
                if not signed_payload:
                    return jsonify({
                        'status': 'error',
                        'message': 'Missing signedPayload in request'
                    }), 400
                    
                # Decode and verify the JWS payload
                decoded_payload = signed_data_verifier.verify_and_decode_notification(signed_payload)
                logger.info(f"Decoded payload: {decoded_payload}")
                # actrual decoded
                # INFO:__main__:Decoded payload: ResponseBodyV2DecodedPayload(notificationType=<NotificationTypeV2.TEST: 'TEST'>, rawNotificationType='TEST', subtype=None, rawSubtype=None, notificationUUID='26fd6e37-a93d-4858-8ff7-7a5718d9c8e3', data=Data(environment=<Environment.SANDBOX: 'Sandbox'>, rawEnvironment='Sandbox', appAppleId=None, bundleId='com.tianzhistudio.multiverse', bundleVersion=None, signedTransactionInfo=None, signedRenewalInfo=None, status=None, rawStatus=None, consumptionRequestReason=None, rawConsumptionRequestReason=None), version='2.0', signedDate=1745723653645, summary=None, externalPurchaseToken=None)
                
                
                return jsonify({
                    'status': 'success',
                    'message': f'Successfully processed purchase notification'
                }), 200
                
            except VerificationException as e:
                logger.error(f"Apple notification verification error: {str(e)}")
                return jsonify({
                    'status': 'error',
                    'message': f'Failed to verify Apple notification: {str(e)}'
                }), 400
                
        except Exception as e:
            logger.error(f"Purchase processing error: {str(e)}")
            return jsonify({
                'status': 'error',
                'message': f'Purchase processing failed: {str(e)}'
            }), 500 