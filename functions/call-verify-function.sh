#!/bin/bash
# Script to call Firebase Callable Function to verify emails
# Run this in Google Cloud Shell

PROJECT_ID="events-app3"
REGION="asia-southeast1"
FUNCTION_NAME="manuallyVerifyEmails"

echo "Calling Firebase Function: $FUNCTION_NAME"
echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""

# Get the access token
TOKEN=$(gcloud auth print-access-token)

# Call the function using Firebase Callable Functions format
curl -X POST \
  "https://$REGION-$PROJECT_ID.cloudfunctions.net/$FUNCTION_NAME" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data": {}}'

echo ""
echo "Done!"
