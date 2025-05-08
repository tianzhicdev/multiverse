from flask import Flask, request, jsonify
import logging
from appstoreserverlibrary.api_client import AppStoreServerAPIClient, APIException
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.models.NotificationTypeV2 import NotificationTypeV2
from appstoreserverlibrary.signed_data_verifier import VerificationException, SignedDataVerifier

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
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

                

                # Process different notification types
                notification_type = decoded_payload.notificationType
                response_message = "Successfully processed purchase notification"
                
                if notification_type == NotificationTypeV2.SUBSCRIBED:
                    logger.info("Processing SUBSCRIBED notification")
                    # Add subscription to user account logic here
                
                elif notification_type == NotificationTypeV2.DID_RENEW:
                    # Handle subscription renewal
                    logger.info("Processing DID_RENEW notification")
                    # Update subscription renewal date logic here
                
                elif notification_type == NotificationTypeV2.DID_FAIL_TO_RENEW:
                    # Handle failed renewal
                    logger.info("Processing DID_FAIL_TO_RENEW notification")
                
                elif notification_type == NotificationTypeV2.CONSUMPTION_REQUEST:
                    # Handle one-time purchase
                    logger.info("Processing CONSUMPTION_REQUEST notification")
                    # Add consumable items to user account logic here
                
                elif notification_type == NotificationTypeV2.ONE_TIME_CHARGE:
                    # Handle one-time charge
                    logger.info("Processing ONE_TIME_CHARGE notification")
                    
                    # Decode the signedTransactionInfo
                    try:
                        transaction_info = decoded_payload.data.signedTransactionInfo
                        if transaction_info:
                            # Decode the JWS transaction payload
                            transaction_payload = signed_data_verifier.verify_and_decode_transaction(transaction_info)
                            logger.info(f"Decoded transaction: {transaction_payload}")
                            
                            # Process transaction details
                            product_id = transaction_payload.productId
                            transaction_id = transaction_payload.transactionId
                            purchase_date = transaction_payload.purchaseDate
                            
                            # Add logic to grant the consumable item to user based on product_id
                            logger.info(f"Granting product {product_id} from transaction {transaction_id}")
                            # TODO: Update database to credit user account with purchased item
                    except VerificationException as e:
                        logger.error(f"Transaction verification error: {str(e)}")
                    except Exception as e:
                        logger.error(f"Error processing transaction: {str(e)}")
                    
                elif notification_type == NotificationTypeV2.REFUND:
                    # Handle refund
                    logger.info("Processing REFUND notification")
                
                elif notification_type == NotificationTypeV2.TEST:
                    # Handle test notification
                    logger.info("Processing TEST notification")
                return jsonify({
                    'status': 'success',
                    'message': response_message
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