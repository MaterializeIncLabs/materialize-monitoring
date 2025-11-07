#!/bin/bash
# Upload Materialize Dashboard to Datadog
# Requires DD_API_KEY and DD_APP_KEY environment variables

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_FILE="${SCRIPT_DIR}/../materialize-overview-dashboard.json"
DD_SITE="${DD_SITE:-datadoghq.com}"

echo "=================================================="
echo "Datadog Dashboard Upload"
echo "=================================================="
echo ""

# Check for required environment variables
if [ -z "$DD_API_KEY" ]; then
    echo "Error: DD_API_KEY environment variable is not set"
    echo "Get your API key from: https://app.datadoghq.com/organization-settings/api-keys"
    exit 1
fi

if [ -z "$DD_APP_KEY" ]; then
    echo "Error: DD_APP_KEY environment variable is not set"
    echo "Get your Application key from: https://app.datadoghq.com/organization-settings/application-keys"
    exit 1
fi

# Check if dashboard file exists
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "Error: Dashboard file not found at ${DASHBOARD_FILE}"
    exit 1
fi

echo "Dashboard file: ${DASHBOARD_FILE}"
echo "Datadog site: ${DD_SITE}"
echo ""

# Validate JSON
echo "[1/2] Validating dashboard JSON..."
if command -v jq &> /dev/null; then
    if jq empty "$DASHBOARD_FILE" 2>/dev/null; then
        echo "✓ Dashboard JSON is valid"
    else
        echo "✗ Dashboard JSON is invalid"
        exit 1
    fi
else
    echo "⚠ jq not found, skipping JSON validation"
fi

# Upload dashboard
echo ""
echo "[2/2] Uploading dashboard to Datadog..."
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    "https://api.${DD_SITE}/api/v1/dashboard" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}" \
    -H "Content-Type: application/json" \
    -d @"${DASHBOARD_FILE}")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Dashboard uploaded successfully!"

    if command -v jq &> /dev/null; then
        DASHBOARD_ID=$(echo "$BODY" | jq -r '.id')
        DASHBOARD_URL=$(echo "$BODY" | jq -r '.url')
        echo ""
        echo "Dashboard ID: ${DASHBOARD_ID}"
        echo "Dashboard URL: https://app.${DD_SITE}${DASHBOARD_URL}"
    else
        echo ""
        echo "Response: ${BODY}"
    fi
else
    echo "✗ Dashboard upload failed (HTTP ${HTTP_CODE})"
    echo ""
    echo "Response: ${BODY}"
    exit 1
fi

echo ""
echo "=================================================="
echo "Upload Complete!"
echo "=================================================="
