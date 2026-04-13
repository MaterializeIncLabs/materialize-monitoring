#!/bin/bash
# Metrics Validation Script
# Validates that all metrics are being collected from SQL Exporter

set -e

SQL_EXPORTER_URL="${SQL_EXPORTER_URL:-http://localhost:9399}"
PROMETHEUS_URL="${PROMETHEUS_URL:-http://localhost:9090}"

echo "=================================================="
echo "Materialize Monitoring - Metrics Validation"
echo "=================================================="
echo ""

# Check if SQL Exporter is responding
echo "[1/5] Checking SQL Exporter health..."
if curl -f -s "${SQL_EXPORTER_URL}/metrics" > /dev/null; then
    echo "✓ SQL Exporter is healthy and responding"
else
    echo "✗ SQL Exporter is not responding at ${SQL_EXPORTER_URL}"
    exit 1
fi

# Count metrics exposed by SQL Exporter
echo ""
echo "[2/5] Counting metrics from SQL Exporter..."
METRIC_COUNT=$(curl -s "${SQL_EXPORTER_URL}/metrics" | grep -E "^materialize_" | grep -v "^#" | wc -l)
echo "✓ Found ${METRIC_COUNT} metric samples from SQL Exporter"

# Check for specific metric families
echo ""
echo "[3/5] Validating metric families..."
METRICS=(
    "materialize_cluster_replicas_count"
    "materialize_replica_uptime_container_start_time_seconds"
    "materialize_cluster_replica_usage_cpu_percent"
    "materialize_cluster_replica_usage_memory_percent"
    "materialize_cluster_replica_usage_disk_percent"
    "materialize_source_statistics_updates_committed"
    "materialize_query_latency_max_latency"
    "materialize_object_freshness_approx_lag_ms"
)

MISSING_METRICS=0
for metric in "${METRICS[@]}"; do
    if curl -s "${SQL_EXPORTER_URL}/metrics" | grep -q "^${metric}"; then
        echo "✓ ${metric} is present"
    else
        echo "✗ ${metric} is MISSING"
        MISSING_METRICS=$((MISSING_METRICS + 1))
    fi
done

if [ $MISSING_METRICS -gt 0 ]; then
    echo ""
    echo "Warning: ${MISSING_METRICS} metric(s) missing. This may be expected if no data is available yet."
fi

# Check if Prometheus is scraping
echo ""
echo "[4/5] Checking Prometheus scraping status..."
if curl -f -s "${PROMETHEUS_URL}/-/healthy" > /dev/null; then
    echo "✓ Prometheus is healthy"

    # Check if Prometheus has targets
    TARGETS=$(curl -s "${PROMETHEUS_URL}/api/v1/targets" | grep -o '"health":"up"' | wc -l)
    echo "✓ Prometheus has ${TARGETS} healthy target(s)"
else
    echo "⚠ Prometheus health check failed (this is okay if Prometheus is not running)"
fi

# Check metric cardinality
echo ""
echo "[5/5] Analyzing metric cardinality..."
UNIQUE_METRICS=$(curl -s "${SQL_EXPORTER_URL}/metrics" | grep -E "^materialize_" | grep -v "^#" | sed 's/{.*//' | sort -u | wc -l)
echo "✓ Found ${UNIQUE_METRICS} unique metric names"
echo ""

# Estimate total cardinality for Datadog
LABEL_CARDINALITY=$(curl -s "${SQL_EXPORTER_URL}/metrics" | grep -E "^materialize_" | grep -v "^#" | wc -l)
echo "Estimated metric cardinality: ${LABEL_CARDINALITY} time series"
if [ $LABEL_CARDINALITY -lt 2000 ]; then
    echo "✓ Well within Datadog's 2000 metric limit"
else
    echo "⚠ Warning: Approaching or exceeding Datadog's 2000 metric limit"
fi

echo ""
echo "=================================================="
echo "Validation Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  - View metrics: ${SQL_EXPORTER_URL}/metrics"
echo "  - View Prometheus: ${PROMETHEUS_URL}"
echo "  - View Grafana: http://localhost:3000"
echo "  - Check Datadog Agent: docker logs datadog-agent"
