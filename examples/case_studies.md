# SQL Optimization Case Studies

Real-world examples of database optimization with measurable results.

---

## Case Study 1: Order Query Optimization

### Problem Statement

An e-commerce platform was experiencing slow customer order lookups. The query was taking 2.5 seconds on average, causing poor user experience.

### Initial Query
```sql
SELECT * 
FROM orders 
WHERE customer_id = 123;
```

### Analysis
```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE customer_id = 123;

-- Result:
-- Seq Scan on orders (cost=0.00..125000.00 rows=50 width=128)
--   Filter: (customer_id = 123)
-- Planning Time: 0.123 ms
-- Execution Time: 2547.891 ms
```

**Problems Identified:**
- Sequential scan on 5 million row table
- No index on `customer_id` column
- Fetching all columns with `SELECT *`

### Solution Implemented
```sql
-- Step 1: Create index on customer_id
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- Step 2: Optimize query to select only needed columns
SELECT id, order_date, total, status 
FROM orders 
WHERE customer_id = 123;

-- Step 3: Update table statistics
ANALYZE orders;
```

### Results After Optimization
```sql
EXPLAIN ANALYZE 
SELECT id, order_date, total, status 
FROM orders 
WHERE customer_id = 123;

-- Result:
-- Index Scan using idx_orders_customer_id (cost=0.43..8.45 rows=50 width=24)
--   Index Cond: (customer_id = 123)
-- Planning Time: 0.156 ms
-- Execution Time: 48.234 ms
```

### Performance Improvement

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Execution Time | 2,547 ms | 48 ms | **53x faster** |
| Scan Type | Sequential | Index | ✅ |
| Rows Scanned | 5,000,000 | 50 | 99.999% reduction |
| Index Size | - | 120 MB | Small overhead |

### ROI Analysis

- **Development Time:** 15 minutes
- **Performance Gain:** 53x faster
- **User Impact:** Improved page load time from 3s to 0.1s
- **Cost:** Minimal (120MB disk space)

### Key Takeaways

1. ✅ Always index foreign key columns
2. ✅ Avoid `SELECT *` - fetch only needed columns
3. ✅ Use `EXPLAIN ANALYZE` to identify issues
4. ✅ Update statistics after creating indexes

---

## Case Study 2: Complex JOIN Optimization

### Problem Statement

A reporting query joining three large tables was taking 8 seconds to execute, causing timeout issues in the web application.

### Initial Query
```sql
SELECT 
    o.id,
    o.order_date,
    o.total,
    c.name AS customer_name,
    c.email,
    p.name AS product_name,
    oi.quantity
FROM orders o
LEFT JOIN customers c ON c.id = o.customer_id
LEFT JOIN order_items oi ON oi.order_id = o.id
LEFT JOIN products p ON p.id = oi.product_id
WHERE o.order_date >= '2024-01-01';
```

### Analysis
```sql
EXPLAIN ANALYZE [query above]

-- Problems:
-- 1. Sequential scan on orders (no index on order_date)
-- 2. Sequential scan on order_items
-- 3. Multiple hash joins causing high memory usage
-- Execution Time: 8234.567 ms
```

**Bottlenecks:**
- No index on `orders.order_date`
- No index on `order_items.order_id`
- No index on `order_items.product_id`

### Solution Implemented
```sql
-- Create indexes for WHERE clause
CREATE INDEX idx_orders_order_date ON orders(order_date);

-- Create indexes for JOIN conditions
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Create covering index for best performance
CREATE INDEX idx_orders_date_customer 
ON orders(order_date, customer_id) 
INCLUDE (id, total);

-- Update statistics
ANALYZE orders;
ANALYZE order_items;
ANALYZE customers;
ANALYZE products;
```

### Results After Optimization
```sql
EXPLAIN ANALYZE [same query]

-- Now using index scans:
-- Index Scan using idx_orders_date_customer
-- Nested Loop joins instead of Hash joins
-- Execution Time: 312.456 ms
```

### Performance Improvement

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Execution Time | 8,234 ms | 312 ms | **26x faster** |
| Join Method | Hash Join | Nested Loop | More efficient |
| I/O Operations | High | Low | 95% reduction |
| Memory Usage | 256 MB | 32 MB | 87% reduction |

### Additional Optimizations

The query was further improved by filtering earlier:
```sql
-- Optimized version: filter before joining
SELECT 
    o.id,
    o.order_date,
    o.total,
    c.name AS customer_name,
    c.email,
    p.name AS product_name,
    oi.quantity
FROM (
    SELECT id, order_date, total, customer_id
    FROM orders
    WHERE order_date >= '2024-01-01'
) o
LEFT JOIN customers c ON c.id = o.customer_id
LEFT JOIN order_items oi ON oi.order_id = o.id
LEFT JOIN products p ON p.id = oi.product_id;
```

**Final Execution Time:** 287 ms (**29x faster than original**)

### Key Takeaways

1. ✅ Index all JOIN columns
2. ✅ Index WHERE clause columns
3. ✅ Consider covering indexes for frequently accessed columns
4. ✅ Filter data as early as possible
5. ✅ Update statistics after bulk data changes

---

## Case Study 3: Aggregation Query with Materialized View

### Problem Statement

A dashboard query calculating customer statistics was taking 15 seconds, making the dashboard unusable. The query was run 100+ times per day.

### Initial Query
```sql
SELECT 
    customer_id,
    COUNT(*) AS order_count,
    SUM(total) AS total_spent,
    AVG(total) AS avg_order_value,
    MAX(order_date) AS last_order_date,
    MIN(order_date) AS first_order_date
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 10
ORDER BY total_spent DESC;
```

### Analysis
```sql
EXPLAIN ANALYZE [query above]

-- Sequential scan + aggregation on 5M rows
-- Hash Aggregate: 14.8GB disk usage
-- Execution Time: 15234.789 ms
```

**Problems:**
- Aggregating 5 million rows every time
- No caching mechanism
- High memory and I/O usage

### Solution Implemented
```sql
-- Create materialized view
CREATE MATERIALIZED VIEW customer_order_stats AS
SELECT 
    customer_id,
    COUNT(*) AS order_count,
    SUM(total) AS total_spent,
    AVG(total) AS avg_order_value,
    MAX(order_date) AS last_order_date,
    MIN(order_date) AS first_order_date,
    NOW() AS last_updated
FROM orders
GROUP BY customer_id;

-- Create index on materialized view
CREATE INDEX idx_customer_stats_spent 
ON customer_order_stats(total_spent DESC);

CREATE INDEX idx_customer_stats_count 
ON customer_order_stats(order_count);

-- Refresh strategy (scheduled job)
-- Option 1: Complete refresh nightly
-- REFRESH MATERIALIZED VIEW customer_order_stats;

-- Option 2: Concurrent refresh (non-blocking)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_stats;
```

### New Query
```sql
SELECT * 
FROM customer_order_stats
WHERE order_count > 10
ORDER BY total_spent DESC;
```

### Results After Optimization
```sql
EXPLAIN ANALYZE [new query]

-- Index Scan using idx_customer_stats_spent
-- Execution Time: 8.234 ms
```

### Performance Improvement

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| Execution Time | 15,234 ms | 8 ms | **1,900x faster** |
| I/O Operations | Very High | Minimal | 99.9% reduction |
| CPU Usage | High | Minimal | 99% reduction |
| Memory Usage | 14.8 GB | < 1 MB | Dramatic reduction |

### Refresh Strategy
```sql
-- Scheduled refresh (cron job every hour)
-- 0 * * * * psql -d mydb -c "REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_stats;"

-- Or create a function for incremental updates
CREATE OR REPLACE FUNCTION refresh_customer_stats() 
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY customer_order_stats;
    RAISE NOTICE 'Customer stats refreshed at %', NOW();
END;
$$ LANGUAGE plpgsql;
```

### Trade-offs

**Advantages:**
- ✅ 1900x faster queries
- ✅ Reduced server load
- ✅ Better user experience

**Disadvantages:**
- ❌ Data slightly stale (up to 1 hour old)
- ❌ Refresh requires resources
- ❌ Additional storage (200 MB)

**Solution:** For this use case, hourly updates were acceptable. For real-time needs, consider incremental materialized views or trigger-based updates.

### Key Takeaways

1. ✅ Use materialized views for expensive aggregations
2. ✅ Index materialized views like regular tables
3. ✅ Use CONCURRENTLY for non-blocking refreshes
4. ✅ Schedule refreshes during low-traffic periods
5. ✅ Balance freshness vs performance needs

---

## Case Study 4: Eliminating N+1 Query Problem

### Problem Statement

An API endpoint was loading customer data with their orders, resulting in 1 query to get customers + N queries to get orders for each customer. For 100 customers, this meant 101 queries!

### Initial Code (Pseudo-code)
```sql
-- Query 1: Get customers
SELECT * FROM customers LIMIT 100;

-- Then for each customer (100 times):
SELECT * FROM orders WHERE customer_id = ?;
```

**Total:** 101 queries, ~500ms total time

### Solution Implemented
```sql
-- Single query with LEFT JOIN
SELECT 
    c.id AS customer_id,
    c.name,
    c.email,
    o.id AS order_id,
    o.order_date,
    o.total,
    o.status
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE c.id IN (1, 2, 3, ..., 100)  -- List of customer IDs
ORDER BY c.id, o.order_date DESC;
```

### Alternative: Using JSON Aggregation
```sql
-- PostgreSQL: Aggregate orders into JSON array
SELECT 
    c.id,
    c.name,
    c.email,
    COALESCE(
        json_agg(
            json_build_object(
                'order_id', o.id,
                'order_date', o.order_date,
                'total', o.total,
                'status', o.status
            ) ORDER BY o.order_date DESC
        ) FILTER (WHERE o.id IS NOT NULL),
        '[]'
    ) AS orders
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
WHERE c.id IN (1, 2, 3, ..., 100)
GROUP BY c.id, c.name, c.email;
```

### Performance Improvement

| Metric | Before (N+1) | After (JOIN) | Improvement |
|--------|--------------|--------------|-------------|
| Number of Queries | 101 | 1 | **101x fewer** |
| Total Time | 500 ms | 45 ms | **11x faster** |
| Network Overhead | High | Minimal | 99% reduction |
| Database Load | High | Low | Significant reduction |

### Key Takeaways

1. ✅ Always fetch related data in a single query when possible
2. ✅ Use JOINs or JSON aggregation
3. ✅ Watch for N+1 patterns in ORM code
4. ✅ Use query profiling tools to detect N+1 issues

---

## General Optimization Principles

Based on these case studies, here are the key principles:

### 1. **Measure First**
- Always use `EXPLAIN ANALYZE` before optimizing
- Identify the actual bottleneck
- Set baseline metrics

### 2. **Index Strategically**
- Index foreign keys
- Index WHERE clause columns
- Index ORDER BY columns
- Consider composite indexes

### 3. **Optimize Query Structure**
- Select only needed columns
- Filter early in the query
- Use appropriate JOIN types
- Avoid N+1 queries

### 4. **Consider Caching**
- Materialized views for aggregations
- Application-level caching
- Database query cache (MySQL)

### 5. **Monitor and Maintain**
- Regular VACUUM and ANALYZE
- Monitor slow query logs
- Review and remove unused indexes
- Update statistics

### 6. **Test at Scale**
- Test with production-like data volumes
- Simulate concurrent users
- Measure under load

---

## Tools and Resources

### Analysis Tools
- `EXPLAIN ANALYZE` - Query execution plans
- `pg_stat_statements` - Query statistics (PostgreSQL)
- `SHOW PROFILE` - Query profiling (MySQL)
- pgAdmin, MySQL Workbench - Visual tools

### Monitoring Tools
- pg_stat_monitor - Enhanced PostgreSQL monitoring
- PMM (Percona Monitoring and Management)
- Datadog, New Relic - APM solutions

### Learning Resources
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Use The Index, Luke!](https://use-the-index-luke.com/)
- [Explain.depesz.com](https://explain.depesz.com/)
- [MySQL Performance Blog](https://www.percona.com/blog/)

---

## Next Steps

1. Review your slowest queries
2. Run EXPLAIN ANALYZE on them
3. Apply appropriate optimization techniques
4. Measure improvements
5. Document your changes
6. Monitor ongoing performance

**Remember:** Every database is different. Always test optimizations in a staging environment before applying to production!
