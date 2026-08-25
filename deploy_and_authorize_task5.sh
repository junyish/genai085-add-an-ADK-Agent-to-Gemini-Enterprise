#!/usr/bin/env bash
# ==============================================================================
# Streamlined, Error-Proof Command-Line Flow for Lab GENAI085 Task 5
# ==============================================================================
# Combines JSON payload generation, Authorization Resource registration,
# ADK Agent registration in Gemini Enterprise, and Reasoning Engine IAM bindings.
# ==============================================================================

set -e

# === 1. USER VARIABLES (Replace with your actual values) ===
: "${APP_ID:?Error: Set APP_ID environment variable}"
: "${REASONING_ENGINE_ID:?Error: Set REASONING_ENGINE_ID environment variable}"
: "${OAUTH_CLIENT_ID:?Error: Set OAUTH_CLIENT_ID environment variable}"
: "${OAUTH_CLIENT_SECRET:?Error: Set OAUTH_CLIENT_SECRET environment variable}"
: "${OAUTH_AUTH_URI:?Error: Set OAUTH_AUTH_URI environment variable}"

# === 2. AUTOMATICALLY DERIVED PROJECT & REGION VARIABLES ===
export PROJECT_ID=$(gcloud config get-value project)
export PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
export LOCATION_APP="global"
export LOCATION_RE="us-central1"
export AUTH_ID="bigquery-agent-auth"
export OAUTH_TOKEN_URI="https://oauth2.googleapis.com/token"

# Format Reasoning Engine resource path
export ADK_DEPLOYMENT_ID="projects/${PROJECT_NUMBER}/locations/${LOCATION_RE}/reasoningEngines/${REASONING_ENGINE_ID}"
export REASONING_ENGINE_SA="service-${PROJECT_NUMBER}@gcp-sa-aiplatform-re.iam.gserviceaccount.com"

echo "=========================================================="
echo "Project ID:           ${PROJECT_ID}"
echo "Project Number:       ${PROJECT_NUMBER}"
echo "App ID:               ${APP_ID}"
echo "Reasoning Engine ID:  ${REASONING_ENGINE_ID}"
echo "=========================================================="

# ---------------------------------------------------------
# A. CREATE AND SEND THE AUTHORIZATION PAYLOAD
# ---------------------------------------------------------
echo "[1/3] Creating and registering Authorization Resource..."
cat <<AUTH_EOF > auth_payload.json
{
  "name": "projects/${PROJECT_NUMBER}/locations/${LOCATION_APP}/authorizations/${AUTH_ID}",
  "displayName": "BigQuery Agent Auth",
  "serverSideOauth2": {
    "clientId": "${OAUTH_CLIENT_ID}",
    "clientSecret": "${OAUTH_CLIENT_SECRET}",
    "authorizationUri": "${OAUTH_AUTH_URI}",
    "tokenUri": "${OAUTH_TOKEN_URI}"
  }
}
AUTH_EOF

curl -sS -X POST    -H "Authorization: Bearer $(gcloud auth print-access-token)"    -H "Content-Type: application/json"    -H "X-Goog-User-Project: ${PROJECT_ID}"    "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_NUMBER}/locations/${LOCATION_APP}/authorizations?authorizationId=${AUTH_ID}"    -d @auth_payload.json > /dev/null
echo "✔ Authorization Resource successfully registered."

# ---------------------------------------------------------
# B. CREATE AND SEND THE AGENT PAYLOAD
# ---------------------------------------------------------
echo "[2/3] Creating and registering ADK Agent in Gemini Enterprise..."
cat <<AGENT_EOF > agent_payload.json
{
   "displayName": "BigQuery Agent",
   "description": "Queries BigQuery data to assist with pool installation requests.",
   "adkAgentDefinition": {
      "provisionedReasoningEngine": {
         "reasoningEngine": "${ADK_DEPLOYMENT_ID}"
      }
   },
   "authorizationConfig": {
      "toolAuthorizations": [
         "projects/${PROJECT_NUMBER}/locations/${LOCATION_APP}/authorizations/${AUTH_ID}"
      ]
   }
}
AGENT_EOF

curl -sS -X POST    -H "Authorization: Bearer $(gcloud auth print-access-token)"    -H "Content-Type: application/json"    -H "X-Goog-User-Project: ${PROJECT_ID}"    "https://discoveryengine.googleapis.com/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_APP}/collections/default_collection/engines/${APP_ID}/assistants/default_assistant/agents"    -d @agent_payload.json > /dev/null
echo "✔ ADK Agent successfully registered in Gemini Enterprise assistant."

# ---------------------------------------------------------
# C. GRANT IAM PERMISSIONS TO REASONING ENGINE SA
# ---------------------------------------------------------
echo "[3/3] Granting IAM permissions to Reasoning Engine Service Account..."
gcloud projects add-iam-policy-binding "$PROJECT_ID"     --member="serviceAccount:${REASONING_ENGINE_SA}"     --role="roles/bigquery.user"     --condition=None > /dev/null

gcloud projects add-iam-policy-binding "$PROJECT_ID"     --member="serviceAccount:${REASONING_ENGINE_SA}"     --role="roles/bigquery.dataEditor"     --condition=None > /dev/null

echo "✔ BigQuery IAM permissions successfully granted."
echo "=========================================================="
echo "🎉 Task 5 Complete! You can now click 'Check my progress'."
echo "=========================================================="
