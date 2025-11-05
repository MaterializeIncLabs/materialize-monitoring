#!/bin/bash
# Validate Datadog Dashboard JSON
# Checks for proper structure and required fields

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_FILE="${SCRIPT_DIR}/../materialize-overview-dashboard.json"

echo "=================================================="
echo "Datadog Dashboard Validation"
echo "=================================================="
echo ""

# Check if dashboard file exists
if [ ! -f "$DASHBOARD_FILE" ]; then
    echo "✗ Dashboard file not found at ${DASHBOARD_FILE}"
    exit 1
fi

echo "Dashboard file: ${DASHBOARD_FILE}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required for validation"
    echo "Install with: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Validate JSON syntax
echo "[1/5] Validating JSON syntax..."
if jq empty "$DASHBOARD_FILE" 2>/dev/null; then
    echo "✓ JSON syntax is valid"
else
    echo "✗ JSON syntax is invalid"
    exit 1
fi

# Check required fields
echo ""
echo "[2/5] Checking required dashboard fields..."
REQUIRED_FIELDS=("title" "layout_type" "widgets")
MISSING_FIELDS=0

for field in "${REQUIRED_FIELDS[@]}"; do
    if jq -e ".${field}" "$DASHBOARD_FILE" > /dev/null 2>&1; then
        echo "✓ Field '${field}' is present"
    else
        echo "✗ Field '${field}' is MISSING"
        MISSING_FIELDS=$((MISSING_FIELDS + 1))
    fi
done

if [ $MISSING_FIELDS -gt 0 ]; then
    echo ""
    echo "Error: ${MISSING_FIELDS} required field(s) missing"
    exit 1
fi

# Check widget count
echo ""
echo "[3/5] Analyzing widgets..."
WIDGET_COUNT=$(jq '.widgets | length' "$DASHBOARD_FILE")
echo "✓ Found ${WIDGET_COUNT} widget(s)"

# Validate widget structure
echo ""
echo "[4/5] Validating widget structure..."
INVALID_WIDGETS=0
for i in $(seq 0 $((WIDGET_COUNT - 1))); do
    WIDGET_TYPE=$(jq -r ".widgets[$i].definition.type" "$DASHBOARD_FILE" 2>/dev/null || echo "unknown")
    if [ "$WIDGET_TYPE" = "null" ] || [ "$WIDGET_TYPE" = "unknown" ]; then
        echo "✗ Widget $i has invalid or missing type"
        INVALID_WIDGETS=$((INVALID_WIDGETS + 1))
    else
        echo "✓ Widget $i: type=${WIDGET_TYPE}"
    fi
done

if [ $INVALID_WIDGETS -gt 0 ]; then
    echo ""
    echo "Warning: ${INVALID_WIDGETS} widget(s) have invalid structure"
fi

# Check for Materialize-specific metrics
echo ""
echo "[5/5] Checking for Materialize metrics..."
MATERIALIZE_METRICS=$(jq -r '[.. | .queries[]?.query? // empty] | unique | .[]' "$DASHBOARD_FILE" 2>/dev/null | grep -c "materialize" || echo "0")

if [ "$MATERIALIZE_METRICS" -gt 0 ]; then
    echo "✓ Found ${MATERIALIZE_METRICS} reference(s) to Materialize metrics"
else
    echo "⚠ No Materialize metrics found in dashboard queries"
fi

# Summary
echo ""
echo "=================================================="
echo "Validation Summary"
echo "=================================================="
echo "Dashboard title: $(jq -r '.title' "$DASHBOARD_FILE")"
echo "Layout type: $(jq -r '.layout_type' "$DASHBOARD_FILE")"
echo "Widget count: ${WIDGET_COUNT}"
echo "Invalid widgets: ${INVALID_WIDGETS}"
echo "Materialize metrics: ${MATERIALIZE_METRICS}"
echo ""

if [ $INVALID_WIDGETS -eq 0 ]; then
    echo "✓ Dashboard is valid and ready for upload!"
    exit 0
else
    echo "⚠ Dashboard has issues but may still be uploadable"
    exit 0
fi
