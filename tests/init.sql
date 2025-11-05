-- Test Data Initialization for Materialize Monitoring
-- This script creates test clusters, sources, and sinks to generate realistic metrics
-- Run this script after starting the local Materialize instance

-- Create test clusters with specific sizes
CREATE CLUSTER test_cluster_small SIZE = '25cc';
CREATE CLUSTER test_cluster_medium SIZE = '50cc';

-- Create a test source (load generator for continuous data)
CREATE SOURCE test_load_gen
  IN CLUSTER test_cluster_small
  FROM LOAD GENERATOR COUNTER
  (TICK INTERVAL '1s');

-- Create a test materialized view to simulate computation
CREATE MATERIALIZED VIEW test_counter_sum
  IN CLUSTER test_cluster_medium
  AS
  SELECT
    counter,
    counter * 2 as doubled,
    counter % 10 as modulo
  FROM test_load_gen;

-- Create an index for query testing
CREATE INDEX idx_counter ON test_counter_sum(counter);

-- Create another source with different characteristics
CREATE SOURCE test_auction_gen
  IN CLUSTER test_cluster_small
  FROM LOAD GENERATOR AUCTION
  (TICK INTERVAL '500ms');

-- Create a view for auction data
CREATE MATERIALIZED VIEW test_auction_stats
  IN CLUSTER test_cluster_medium
  AS
  SELECT
    seller,
    COUNT(*) as auction_count,
    AVG(bid) as avg_bid
  FROM test_auction_gen
  GROUP BY seller;

-- Show created objects
\echo 'Test clusters created:'
SHOW CLUSTERS;

\echo 'Test sources created:'
SHOW SOURCES;

\echo 'Test views created:'
SHOW MATERIALIZED VIEWS;

\echo ''
\echo 'Test data initialization complete!'
\echo 'Metrics should now be available from:'
\echo '  - Clusters: test_cluster_small (25cc), test_cluster_medium (50cc)'
\echo '  - Sources: test_load_gen, test_auction_gen'
\echo '  - Views: test_counter_sum, test_auction_stats'
