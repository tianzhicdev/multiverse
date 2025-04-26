#!/bin/bash

echo "Step 1: Setting up variables"
KEY_ID=6RCN2GN648
ISSUER_ID=69a6de84-f57d-47e3-e053-5b8c7c11a4d1
P8_FILE_PATH=.SubscriptionKey_6RCN2GN648.p8
NOTIFICATION_TYPE=${4:-"CONSUMPTION_REQUEST"}  # Default to CONSUMPTION_REQUEST if not specified
BUNDLE_ID=${5:-"com.tianzhistudio.multiverse"}  # Add your actual bundle ID here

echo "KEY_ID: $KEY_ID"
echo "ISSUER_ID: $ISSUER_ID"
echo "P8_FILE_PATH: $P8_FILE_PATH"
echo "NOTIFICATION_TYPE: $NOTIFICATION_TYPE"
echo "BUNDLE_ID: $BUNDLE_ID"

echo "Step 2: Generating JWT token for authentication"
now=$(date +%s)
echo "Current timestamp: $now"
expiry=$((now + 3600))  # Token valid for 1 hour
echo "Token expiry timestamp: $expiry"

echo "Step 3: Creating JWT header"
header=$(echo -n '{"alg":"ES256","kid":"'$KEY_ID'","typ":"JWT"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
echo "JWT header created $header"

echo "Step 4: Creating JWT payload"
payload=$(echo -n '{"iss":"'$ISSUER_ID'","iat":'$now',"exp":'$expiry',"aud":"appstoreconnect-v1","bid":"'$BUNDLE_ID'"}' | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
echo "JWT payload created $payload"

echo "Step 5: Creating signature"
signature_input="$header.$payload"
echo "Signature input prepared $signature_input"
signature=$(echo -n "$signature_input" | openssl dgst -sha256 -sign "$P8_FILE_PATH" -binary | base64 | tr -d '=' | tr '/+' '_-' | tr -d '\n')
echo "Signature created $signature"

echo "Step 6: Assembling complete JWT"
TOKEN="$signature_input.$signature"
echo "JWT token generated $TOKEN"

echo "Step 7: Sending test notification to Apple"
curl -v -X POST "https://api.storekit-sandbox.itunes.apple.com/inApps/v1/notifications/test" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "notificationType": "'$NOTIFICATION_TYPE'"
  }'

echo "Step 8: Request completed"
echo
