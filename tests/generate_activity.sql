-- Test Activity Generation for Materialize Monitoring
-- This script generates query activity to populate latency metrics
-- Run this periodically or in a loop to simulate realistic query patterns

-- Simple SELECT queries on materialized views
SELECT COUNT(*) FROM test_counter_sum;
SELECT MAX(counter), MIN(counter), AVG(counter) FROM test_counter_sum;
SELECT * FROM test_counter_sum WHERE modulo = 5 LIMIT 100;

-- Queries on auction data
SELECT COUNT(*) FROM test_auction_stats;
SELECT seller, auction_count, avg_bid FROM test_auction_stats ORDER BY avg_bid DESC LIMIT 10;

-- Join queries
SELECT
    c.counter,
    c.doubled,
    c.modulo
FROM test_counter_sum c
WHERE c.counter > 100
LIMIT 50;

-- Aggregation queries
SELECT
    modulo,
    COUNT(*) as count,
    AVG(counter) as avg_counter
FROM test_counter_sum
GROUP BY modulo
ORDER BY modulo;

-- Complex query with filtering
SELECT
    seller,
    auction_count,
    avg_bid,
    CASE
        WHEN avg_bid > 50 THEN 'high'
        WHEN avg_bid > 20 THEN 'medium'
        ELSE 'low'
    END as bid_category
FROM test_auction_stats
WHERE auction_count > 5
ORDER BY auction_count DESC
LIMIT 20;

\echo 'Query activity generated successfully!'
