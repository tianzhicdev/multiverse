from flask import Flask, request, jsonify
import logging
from src.common.logging_config import setup_logger
import re
from appstoreserverlibrary.api_client import AppStoreServerAPIClient, APIException
from appstoreserverlibrary.models.Environment import Environment
from appstoreserverlibrary.models.JWSTransactionDecodedPayload import JWSTransactionDecodedPayload
from appstoreserverlibrary.models.NotificationTypeV2 import NotificationTypeV2
from appstoreserverlibrary.signed_data_verifier import VerificationException, SignedDataVerifier
from src.common.helper import add_credits

# Configure logger using centralized logging config
logger = setup_logger(__name__, 'purchase.log')

def load_root_certificates():
    with open("/usr/local/.secrets/apple/AppleRootCA-G3.cer", "rb") as f:
        return [f.read()]

def decode_transaction(signed_transaction_info, signed_data_verifier):
    """
    Decode the signed transaction information.
    
    Args:
        signed_transaction_info: The signed transaction data from Apple
        signed_data_verifier: The SignedDataVerifier instance
        
    Returns:
        dict: Decoded transaction payload or None if no transaction info is available
    """
    if not signed_transaction_info:
        logger.info("No signed transaction information available")
        return None
        
    try:
        # Decode the JWS transaction payload
        transaction_payload = signed_data_verifier.verify_and_decode_signed_transaction(signed_transaction_info)
        logger.info(f"Decoded transaction: {transaction_payload}")
        return transaction_payload
    except VerificationException as e:
        logger.error(f"Transaction verification error: {str(e)}")
        return None
    except Exception as e:
        logger.error(f"Error processing transaction: {str(e)}")
        return None

def process_purchase_request(environment):
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
        app_apple_id = None  # Only required for Production environment
        
        # Initialize the SignedDataVerifier
        root_certificates = load_root_certificates()  # Load root certificates if needed
        enable_online_checks = True
        signed_data_verifier = SignedDataVerifier(root_certificates, enable_online_checks, 
                                                environment, bundle_id, app_apple_id)
        
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

            # Get notification type
            notification_type = decoded_payload.notificationType
            
            # Extract transaction info right away if available
            transaction_payload = None
            if hasattr(decoded_payload, 'data'):
                # Extract any renewal info or original transaction info if available
                
                # Decode the transaction info if it exists
                if hasattr(decoded_payload.data, 'signedTransactionInfo'):
                    transaction_payload = decode_transaction(
                        decoded_payload.data.signedTransactionInfo, 
                        signed_data_verifier
                    )
                    
                    if transaction_payload:
                        logger.info(f"Transaction data extracted: Product {transaction_payload.productId}, "
                                   f"Transaction {transaction_payload.transactionId}")

            # Process different notification types
            response_message = "Successfully processed purchase notification"
            
            if notification_type == NotificationTypeV2.SUBSCRIBED:
                logger.info("Processing SUBSCRIBED notification")
                # Add subscription to user account logic here
                if transaction_payload:
                    product_id = transaction_payload.productId
                    transaction_id = transaction_payload.transactionId
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    logger.info(f"Subscription started for product {product_id}, transaction {transaction_id}, appAccountToken: {app_account_token}")
                    
                    # Add credits if the product is premium
                    if product_id == 'premium':
                        # Use app_account_token as user_id
                        add_credits(app_account_token, 500, "Premium subscription started", transaction_id)
            
            elif notification_type == NotificationTypeV2.DID_RENEW:
                # Handle subscription renewal
                logger.info("Processing DID_RENEW notification")
                # Update subscription renewal date logic here
                if transaction_payload:
                    product_id = transaction_payload.productId
                    transaction_id = transaction_payload.transactionId
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    logger.info(f"Subscription renewed for product {product_id}, transaction {transaction_id}, appAccountToken: {app_account_token}")
                    
                    # Add credits if the product is premium
                    if product_id == 'premium':
                        # Use app_account_token as user_id
                        add_credits(app_account_token, 500, "Premium subscription renewed", transaction_id)
            
            elif notification_type == NotificationTypeV2.DID_FAIL_TO_RENEW:
                # Handle failed renewal
                logger.info("Processing DID_FAIL_TO_RENEW notification")
                if transaction_payload:
                    product_id = transaction_payload.productId
                    transaction_id = transaction_payload.transactionId
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    logger.info(f"Subscription failed to renew for product {product_id}, transaction {transaction_id}, appAccountToken: {app_account_token}")
            
            elif notification_type == NotificationTypeV2.CONSUMPTION_REQUEST:
                # Handle one-time purchase
                logger.info("Processing CONSUMPTION_REQUEST notification")
                # Add consumable items to user account logic here
                if transaction_payload:
                    product_id = transaction_payload.productId
                    transaction_id = transaction_payload.transactionId
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    logger.info(f"Consumption request for product {product_id}, transaction {transaction_id}, appAccountToken: {app_account_token}")
            
            elif notification_type == NotificationTypeV2.ONE_TIME_CHARGE:
                # Handle one-time charge
                logger.info("Processing ONE_TIME_CHARGE notification")
                if transaction_payload:
                    product_id = transaction_payload.productId
                    transaction_id = transaction_payload.transactionId
                    purchase_date = transaction_payload.purchaseDate
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    
                    # Add logic to grant the consumable item to user based on product_id
                    logger.info(f"Granting product {product_id} from transaction {transaction_id}, appAccountToken: {app_account_token}")
                    
                    # Check if this is a photons purchase
                    photons_match = re.match(r'photons(\d+)', product_id)
                    if photons_match:
                        credits = int(photons_match.group(1))
                        # Use app_account_token as user_id
                        add_credits(app_account_token, credits, f"Purchase of {product_id}", transaction_id)
                
            elif notification_type == NotificationTypeV2.REFUND:
                # Handle refund
                logger.info("Processing REFUND notification")
                if transaction_payload:
                    product_id = transaction_payload.productId
                    transaction_id = transaction_payload.transactionId
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    logger.info(f"Refund processed for product {product_id}, transaction {transaction_id}, appAccountToken: {app_account_token}")
            
            elif notification_type == NotificationTypeV2.TEST:
                # Handle test notification
                logger.info("Processing TEST notification")
                if transaction_payload:
                    product_id = transaction_payload.productId
                    app_account_token = getattr(transaction_payload, 'appAccountToken', 'None')
                    logger.info(f"Test notification with transaction data received: product {product_id}, appAccountToken: {app_account_token}")
                    
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

def register_routes(app):
    @app.route('/purchase', methods=['POST'])
    def process_purchase():
        return process_purchase_request(Environment.PRODUCTION)
        
    @app.route('/purchase-sandbox', methods=['POST'])
    def process_purchase_sandbox():
        return process_purchase_request(Environment.SANDBOX)
        
    @app.route('/one-time-purchase', methods=['POST'])
    def one_time_purchase():
        try:
            data = request.get_json()
            
            # Extract required parameters
            transaction_id = data.get('transaction_id')
            credits = data.get('credits')
            user_id = data.get('user_id')
            
            # Validate required parameters
            if not transaction_id or not credits or not user_id:
                return jsonify({
                    'status': 'error',
                    'message': 'Missing required parameters: transaction_id, credits, and user_id are required'
                }), 400
                
            # Validate credits is a number
            try:
                credits = int(credits)
            except ValueError:
                return jsonify({
                    'status': 'error',
                    'message': 'Credits must be a valid number'
                }), 400
                
            # Add credits to user account
            add_credits(user_id, credits, f"One-time purchase of {credits} credits", transaction_id)
            
            return jsonify({
                'status': 'success',
                'message': f'Successfully added {credits} credits to user {user_id}'
            }), 200
            
        except Exception as e:
            logger.error(f"One-time purchase error: {str(e)}")
            return jsonify({
                'status': 'error',
                'message': f'One-time purchase failed: {str(e)}'
            }), 500