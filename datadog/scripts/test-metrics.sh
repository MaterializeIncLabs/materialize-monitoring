#!/bin/bash
# Test Datadog Metrics
# Checks if metrics are being sent to Datadog successfully

set -e

DD_SITE="${DD_SITE:-datadoghq.com}"

echo "=================================================="
echo "Datadog Metrics Testing"
echo "=================================================="
echo ""

# Check for DD_API_KEY
if [ -z "$DD_API_KEY" ]; then
    echo "Warning: DD_API_KEY environment variable is not set"
    echo "Cannot query Datadog API without credentials"
    echo ""
    echo "For local testing, check Docker logs instead:"
    echo "  docker logs datadog-agent | grep -i openmetrics"
    exit 0
fi

if [ -z "$DD_APP_KEY" ]; then
    echo "Warning: DD_APP_KEY environment variable is not set"
    echo "Cannot query Datadog API without credentials"
    echo ""
    echo "For local testing, check Docker logs instead:"
    echo "  docker logs datadog-agent | grep -i openmetrics"
    exit 0
fi

echo "Datadog site: ${DD_SITE}"
echo ""

# Get current timestamp and 1 hour ago
NOW=$(date +%s)
ONE_HOUR_AGO=$((NOW - 3600))

# Query for Materialize metrics
echo "[1/3] Querying Datadog for Materialize metrics..."
RESPONSE=$(curl -s -X GET \
    "https://api.${DD_SITE}/api/v1/metrics?from=${ONE_HOUR_AGO}&host=materialize-monitoring-local" \
    -H "DD-API-KEY: ${DD_API_KEY}" \
    -H "DD-APPLICATION-KEY: ${DD_APP_KEY}")

if command -v jq &> /dev/null; then
    METRIC_COUNT=$(echo "$RESPONSE" | jq '.metrics | length' 2>/dev/null || echo "0")
    echo "✓ Found ${METRIC_COUNT} metric(s) from Materialize host"

    # List some Materialize metrics
    echo ""
    echo "[2/3] Materialize metrics available:"
    echo "$RESPONSE" | jq -r '.metrics[]? | select(startswith("materialize"))' 2>/dev/null | head -10 || echo "No Materialize metrics found yet"
else
    echo "⚠ jq not found, cannot parse response"
    echo "Raw response: ${RESPONSE}"
fi

# Check OpenMetrics integration status
echo ""
echo "[3/3] Checking local Datadog Agent status..."
if docker ps | grep -q datadog-agent; then
    echo "✓ Datadog Agent container is running"
    echo ""
    echo "Checking OpenMetrics check status..."
    docker exec datadog-agent agent status 2>/dev/null | grep -A 20 "openmetrics" || echo "OpenMetrics check not found in agent status"
else
    echo "⚠ Datadog Agent container is not running"
    echo "Start it with: docker-compose up -d datadog-agent"
fi

echo ""
echo "=================================================="
echo "Testing Complete!"
echo "=================================================="
echo ""
echo "To view metrics in Datadog:"
echo "  https://app.${DD_SITE}/metric/explorer?exp_metric=materialize"
echo ""
echo "To check local agent logs:"
echo "  docker logs datadog-agent | grep -i openmetrics"
echo "  docker logs datadog-agent | grep -i materialize"
