# Materialize Monitoring

A repository to incubate and share monitoring configurations and visualizations for Materialize database.

This repository supports monitoring for **all Materialize deployments**:
- **Materialize Cloud** - Fully managed service
- **Self-managed Materialize** - On-premises or custom cloud deployments

And provides dashboards for **two monitoring platforms**:
- **Grafana** (with Prometheus) - Original configuration
- **Datadog** - New addition with full dashboard support

## Table of Contents

- [Quick Start (Local Development)](#quick-start-local-development)
- [Grafana Setup](#grafana-setup)
- [Datadog Setup](#datadog-setup)
- [Production Deployment](#production-deployment)
- [Testing and Validation](#testing-and-validation)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)

---

## Quick Start (Local Development)

Get started with a complete local monitoring environment including Materialize, Grafana, and Datadog:

### Prerequisites

- Docker and Docker Compose
- (Optional) `jq` for JSON validation: `brew install jq` (macOS) or `apt-get install jq` (Linux)

### 1. Start the Environment

```bash
# Clone the repository
git clone <repository-url>
cd materialize-monitoring

# Copy environment template (optional - defaults work for local dev)
cp .env.example .env

# Start all services
docker-compose up -d

# Check service health
docker-compose ps
```

This starts:
- **Materialize** on `localhost:6875`
- **SQL Exporter** on `localhost:9399`
- **Prometheus** on `localhost:9090`
- **Grafana** on `localhost:3000` (admin/admin)
- **Datadog Agent** (collects metrics for Datadog)

### 2. Initialize Test Data

```bash
# Connect to Materialize and run initialization script
docker exec -i materialize psql -U materialize -d materialize < tests/init.sql

# Generate some query activity
docker exec -i materialize psql -U materialize -d materialize < tests/generate_activity.sql
```

### 3. Validate Metrics

```bash
# Run validation script
./tests/validate_metrics.sh
```

### 4. Access Dashboards

- **Grafana**: http://localhost:3000 (login: admin/admin)
  - The Materialize Overview dashboard is automatically provisioned

- **Prometheus**: http://localhost:9090
  - Query metrics directly with PromQL

- **SQL Exporter Metrics**: http://localhost:9399/metrics
  - Raw Prometheus-format metrics

---

## Grafana Setup

### Local Development

Grafana is automatically configured when using `docker-compose up`. The dashboard is provisioned at startup.

### Production Deployment

These instructions work for both **Materialize Cloud** and **self-managed Materialize** deployments.

1. **Set up SQL Exporter**:
   ```bash
   # Edit sql_exporter/config.yml with your Materialize connection details
   # Connection string format:
   # postgres://USER:PASSWORD@HOST:PORT/DATABASE?sslmode=require
   #
   # Examples:
   #
   # Materialize Cloud:
   #   postgres://user%40domain.com:pass@server.us-east-1.aws.materialize.cloud:6875/materialize?sslmode=require
   #
   # Self-managed Materialize:
   #   postgres://user:pass@your-materialize-host:6875/materialize?sslmode=require
   #
   # IMPORTANT: Escape special characters in username/password:
   #   @ becomes %40
   #   : becomes %3A
   #   Example: user@domain.com becomes user%40domain.com
   ```

2. **Deploy SQL Exporter**:
   ```bash
   docker run -d \
     -p 9399:9237 \
     -v $(pwd)/sql_exporter/config.yml:/config.yml:ro \
     ghcr.io/justwatchcom/sql_exporter:latest \
     -config.file=/config.yml
   ```

3. **Configure Prometheus** to scrape the SQL Exporter (see `prometheus/prometheus.yml`)

4. **Import Dashboard**:
   - In Grafana, go to Dashboards > Import
   - Upload `grafana/materialize-overview-dashboard.json`
   - Select your Prometheus datasource

### Dashboard Features

The Grafana dashboard includes 13 panels monitoring:
- Cluster replicas and their sizes
- CPU, Memory, and Disk utilization
- Replica uptime
- Source health (update rates, offset lag, rehydration latency)
- Sink health (uncommitted messages)
- Query latency (min/max/avg per cluster)
- Object freshness (data lag)

---

## Datadog Setup

This setup follows the [official Materialize Datadog documentation](https://materialize.com/docs/manage/monitor/cloud/datadog/) and works for both **Materialize Cloud** and **self-managed** deployments.

### Local Development with Datadog

1. **Get Datadog API Key** (optional for local testing):
   - Visit: https://app.datadoghq.com/organization-settings/api-keys
   - Create or copy an API key

2. **Configure Environment**:
   ```bash
   # Edit .env file
   cp .env.example .env

   # Set your Datadog API key (or leave empty for local testing)
   DD_API_KEY=your_api_key_here
   DD_SITE=datadoghq.com  # Change based on your region
   ```

3. **Start Services**:
   ```bash
   docker-compose up -d
   ```

4. **Verify Datadog Agent**:
   ```bash
   # Check agent status
   docker exec datadog-agent agent status

   # Check OpenMetrics integration
   docker exec datadog-agent agent status | grep -A 20 openmetrics

   # View agent logs
   docker logs datadog-agent | grep -i materialize
   ```

5. **Test Metrics Collection**:
   ```bash
   # Run validation script
   ./datadog/scripts/test-metrics.sh
   ```

### Production Datadog Deployment

These instructions apply to both **Materialize Cloud** and **self-managed Materialize** installations. The SQL Exporter connects via standard PostgreSQL protocol, so the setup is identical regardless of where Materialize is hosted.

1. **Set up SQL Exporter** (same as Grafana setup above):
   - Edit `sql_exporter/config.yml` with your Materialize connection string
   - For Materialize Cloud: Use the connection string from the "Connect" link in your dashboard
   - For self-managed: Use your Materialize host and credentials

2. **Install Datadog Agent** on the host where SQL Exporter runs:
   - Follow: https://docs.datadoghq.com/agent/

3. **Configure OpenMetrics Check**:
   ```bash
   # Copy configuration
   sudo cp datadog/conf.d/openmetrics.d/conf.yaml \
     /etc/datadog-agent/conf.d/openmetrics.d/conf.yaml

   # Update the endpoint to point to your SQL Exporter
   # Edit: openmetrics_endpoint: http://<SQL_EXPORTER_HOST>:9399/metrics

   # Restart agent
   sudo systemctl restart datadog-agent
   ```

4. **Upload Dashboard**:
   ```bash
   # Set credentials
   export DD_API_KEY=your_api_key
   export DD_APP_KEY=your_app_key
   export DD_SITE=datadoghq.com

   # Validate dashboard JSON
   ./datadog/scripts/validate-dashboard.sh

   # Upload to Datadog
   ./datadog/scripts/upload-dashboard.sh
   ```

### Datadog Dashboard Features

The Datadog dashboard includes 17 widgets monitoring:
- Total cluster replicas (query value)
- Average CPU, Memory, Disk utilization (query values)
- CPU/Memory/Disk utilization by replica (time series)
- Heap memory utilization (time series)
- Source update rates (time series)
- Source offset lag (time series)
- Source rehydration latency (time series)
- Sink uncommitted messages (time series)
- Max/avg query latency by cluster (time series)
- Object freshness lag (time series)
- Replica uptime (time series)

### Datadog Metric Namespace

All metrics are prefixed with `materialize.`:
- `materialize.cluster_replicas.count`
- `materialize.cluster_replica_usage.cpu_percent`
- `materialize.cluster_replica_usage.memory_percent`
- `materialize.cluster_replica_usage.disk_percent`
- `materialize.source_statistics.updates_committed`
- `materialize.query_latency.max_latency`
- And more...

### Metric Cardinality

The current configuration exposes approximately 24 base metrics with various labels, resulting in 200-500 total time series - **well within Datadog's 2000 metric limit per agent**.

---

## Production Deployment

### Deployment Overview

The monitoring setup works identically for both **Materialize Cloud** and **self-managed Materialize** deployments. The SQL Exporter connects via PostgreSQL protocol (port 6875 by default) and executes SQL queries against Materialize's internal catalog views.

### Cloud vs Self-Managed Considerations

| Aspect | Materialize Cloud | Self-Managed Materialize |
|--------|-------------------|--------------------------|
| **Connection** | Use connection string from dashboard | Use your host/port configuration |
| **SSL/TLS** | `sslmode=require` (required) | `sslmode=require` (recommended) or `sslmode=disable` |
| **Port** | 6875 (standard) | 6875 (default) or custom |
| **Credentials** | Cloud user or service account | Your configured users |
| **Network** | Public endpoint or PrivateLink | Your network configuration |
| **Firewall** | Outbound access to `*.materialize.cloud:6875` | Access to your Materialize host |

### Deployment Checklist

**For Materialize Cloud:**
- [ ] Create a Materialize service account for monitoring (recommended)
- [ ] Get connection string from "Connect" link in dashboard
- [ ] Escape special characters in username/password (`@` → `%40`, `:` → `%3A`)
- [ ] Ensure outbound access to `*.materialize.cloud:6875`

**For Self-Managed Materialize:**
- [ ] Create a dedicated monitoring user (recommended)
- [ ] Construct connection string: `postgres://USER:PASSWORD@YOUR_HOST:6875/materialize`
- [ ] Ensure network connectivity from SQL Exporter host to Materialize
- [ ] Configure SSL/TLS as appropriate for your environment

**Common Steps (both deployment types):**
- [ ] Update connection string in `sql_exporter/config.yml`
- [ ] Deploy SQL Exporter in your infrastructure
- [ ] Configure Prometheus to scrape SQL Exporter (for Grafana)
- [ ] Install and configure Datadog Agent with OpenMetrics check (for Datadog)
- [ ] Import Grafana dashboard or upload Datadog dashboard
- [ ] Set up alerts based on your SLOs

### Security Best Practices

1. **Use Dedicated Accounts**:
   - Materialize Cloud: Create service accounts via the dashboard
   - Self-managed: Create dedicated monitoring users with read-only access

2. **Credential Management**: Store credentials in environment variables or secret managers (never commit to git)

3. **Network Security**:
   - Restrict access to SQL Exporter metrics endpoint
   - Use private networking when possible (VPC peering, PrivateLink, etc.)

4. **SSL/TLS**:
   - Materialize Cloud: Always use `sslmode=require`
   - Self-managed: Use `sslmode=require` in production

5. **Principle of Least Privilege**: Grant monitoring accounts only necessary permissions (read access to system catalogs)

---

## Testing and Validation

### Test Data Scripts

**Initialize Test Environment**:
```bash
# Creates test clusters, sources, and materialized views
docker exec -i materialize psql -U materialize -d materialize < tests/init.sql
```

**Generate Query Activity**:
```bash
# Run queries to populate latency metrics
docker exec -i materialize psql -U materialize -d materialize < tests/generate_activity.sql
```

**Run in a Loop** (for continuous testing):
```bash
while true; do
  docker exec -i materialize psql -U materialize -d materialize < tests/generate_activity.sql
  sleep 10
done
```

### Validation Scripts

**Validate Metrics Collection**:
```bash
./tests/validate_metrics.sh
```

This checks:
- SQL Exporter health
- Metric count and families
- Prometheus scraping status
- Metric cardinality (Datadog limit check)

**Validate Datadog Dashboard**:
```bash
./datadog/scripts/validate-dashboard.sh
```

**Test Datadog Metrics**:
```bash
# Requires DD_API_KEY and DD_APP_KEY
./datadog/scripts/test-metrics.sh
```

---

## Architecture

### Metrics Collection Flow

```
┌─────────────────────────────┐
│     Materialize Database    │
│  (Cloud or Self-Managed)    │
└──────────┬──────────────────┘
           │ PostgreSQL Protocol (port 6875)
           │ SQL Queries every 1min
           │
┌──────────▼──────────────────┐
│      SQL Exporter           │
│   (Prometheus format)       │
└──────────┬──────────────────┘
           │ HTTP /metrics endpoint
           │
     ┌─────┴─────┐
     │           │
┌────▼────┐ ┌───▼──────────┐
│Prometheus│ │Datadog Agent │
│         │ │ (OpenMetrics)│
└────┬────┘ └───┬──────────┘
     │          │
┌────▼────┐ ┌──▼────────┐
│ Grafana │ │  Datadog  │
│Dashboard│ │ Dashboard │
└─────────┘ └───────────┘
```

### Component Descriptions

| Component | Purpose | Port | Notes |
|-----------|---------|------|-------|
| Materialize | Database being monitored | 6875 | Cloud or self-managed |
| SQL Exporter | Executes SQL queries, exposes Prometheus metrics | 9399 | Connects via PostgreSQL protocol |
| Prometheus | Time-series database for Grafana | 9090 | Optional (only needed for Grafana) |
| Grafana | Dashboard visualization | 3000 | Optional monitoring platform |
| Datadog Agent | Collects metrics via OpenMetrics, sends to Datadog | 8125/8126 | Optional monitoring platform |

### Collected Metrics

The SQL Exporter runs 9 query sets against Materialize's internal catalog views:

1. **cluster_replicas** - Replica configuration
2. **replica_uptime** - Time since last restart
3. **cluster_replica_usage** - Resource utilization (CPU, memory, disk, credits)
4. **source_statistics** - Source health (updates, lag, rehydration)
5. **sink_statistics** - Sink health (messages committed/staged)
6. **query_latency** - Query performance (min/max/avg latency)
7. **object_freshness** - Data freshness (write frontier, lag)

These queries work identically on both Materialize Cloud and self-managed deployments as they query standard system catalog views.

---

## Troubleshooting

### SQL Exporter Issues

**Problem**: SQL Exporter not collecting metrics

```bash
# Check logs
docker logs sql_exporter

# Verify connection to Materialize
# For local/Docker:
docker exec materialize psql -U materialize -c "SELECT 1"

# For Cloud or self-managed:
psql "postgres://USER:PASSWORD@HOST:6875/materialize?sslmode=require" -c "SELECT 1"

# Check metrics endpoint
curl http://localhost:9399/metrics
```

**Common Issues**:
- Connection string format (check special character escaping)
- Network connectivity to Materialize
- Firewall blocking port 6875
- Invalid credentials
- SSL/TLS certificate issues (try `sslmode=disable` for testing self-managed)

### Grafana Issues

**Problem**: Dashboard shows "No data"

```bash
# Check Prometheus targets
open http://localhost:9090/targets

# Verify Prometheus is scraping SQL Exporter
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | select(.labels.job=="materialize")'
```

### Datadog Issues

**Problem**: Metrics not appearing in Datadog

```bash
# Check agent status
docker exec datadog-agent agent status

# Check OpenMetrics check
docker exec datadog-agent agent status | grep -A 20 openmetrics

# View agent logs
docker logs datadog-agent | grep -E "(openmetrics|materialize|error)"

# Verify SQL Exporter metrics are accessible
curl http://localhost:9399/metrics | grep materialize
```

**Problem**: "Exceeded 2000 metric limit"

The current configuration should stay well under this limit. If you hit it:
- Review metric cardinality: `./tests/validate_metrics.sh`
- Filter metrics in `datadog/conf.d/openmetrics.d/conf.yaml`
- Use more specific metric patterns instead of `.*`

### Materialize Connection Issues

**Problem**: Cannot connect to Materialize

**For Materialize Cloud:**
```bash
# Test connection
psql "postgres://USER:PASSWORD@HOST:6875/materialize?sslmode=require" -c "SELECT mz_version()"

# Common issues:
# - Special characters not escaped (@, :, etc.)
# - Wrong host/region
# - IP not allowlisted (check Cloud dashboard)
# - Invalid credentials
```

**For Self-Managed:**
```bash
# Test connection
psql "postgres://USER:PASSWORD@YOUR_HOST:6875/materialize" -c "SELECT mz_version()"

# Common issues:
# - Materialize not running
# - Firewall blocking port 6875
# - Wrong host/port
# - SSL/TLS configuration mismatch
```

**Problem**: Test data not generating metrics

```bash
# Check clusters exist
docker exec materialize psql -U materialize -c "SHOW CLUSTERS"

# Check sources are running
docker exec materialize psql -U materialize -c "SHOW SOURCES"

# Check materialized views
docker exec materialize psql -U materialize -c "SHOW MATERIALIZED VIEWS"

# Re-run initialization if needed
docker exec -i materialize psql -U materialize -d materialize < tests/init.sql
```

---

## References

- [Materialize Grafana Monitoring](https://materialize.com/docs/manage/monitor/grafana/)
- [Materialize Datadog Monitoring](https://materialize.com/docs/manage/monitor/cloud/datadog/)
- [Prometheus SQL Exporter](https://github.com/burningalchemist/sql_exporter)
- [Datadog OpenMetrics Integration](https://docs.datadoghq.com/integrations/openmetrics/)
- [Materialize System Catalog](https://materialize.com/docs/sql/system-catalog/)

---

## Contributing

Contributions are welcome! Please submit pull requests with:
- New dashboard widgets or panels
- Additional metrics or queries
- Improved documentation
- Bug fixes

---

## File Structure

```
materialize-monitoring/
├── docker-compose.yml              # Local development environment
├── .env.example                    # Environment variable template
├── .gitignore                      # Git ignore rules
├── README.md                       # This file
├── sql_exporter/
│   ├── config.yml                 # Production configuration (Cloud/Self-managed)
│   └── config.local.yml           # Local Docker configuration
├── grafana/
│   ├── materialize-overview-dashboard.json
│   └── provisioning/              # Auto-provisioning configs
│       ├── datasources/
│       │   └── prometheus.yml
│       └── dashboards/
│           └── dashboards.yml
├── prometheus/
│   └── prometheus.yml             # Prometheus configuration
├── datadog/
│   ├── datadog.yaml              # Agent configuration
│   ├── conf.d/
│   │   └── openmetrics.d/
│   │       └── conf.yaml         # OpenMetrics check
│   ├── materialize-overview-dashboard.json
│   └── scripts/
│       ├── upload-dashboard.sh   # Upload to Datadog
│       ├── validate-dashboard.sh # Validate JSON
│       └── test-metrics.sh       # Test metric collection
└── tests/
    ├── init.sql                  # Initialize test data
    ├── generate_activity.sql     # Generate test queries
    └── validate_metrics.sh       # Validate metrics
```

---

## License

[Add your license here]
