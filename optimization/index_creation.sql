-- ============================================
-- Index Creation Best Practices
-- Examples of different index types and strategies
-- ============================================

-- ======================
-- INDEX TYPE 1: Single Column B-tree Index
-- Most common index type for equality and range queries
-- ======================

-- Basic single column index
CREATE INDEX idx_orders_customer_id 
ON orders(customer_id);

-- When to use:
-- - Equality searches: WHERE customer_id = 123
-- - IN queries: WHERE customer_id IN (1, 2, 3)
-- - Range queries: WHERE customer_id > 100
-- - Sorting: ORDER BY customer_id

-- ======================
-- INDEX TYPE 2: Composite/Multi-Column Index
-- Index on multiple columns - order matters!
-- ======================

-- Composite index (most selective column first)
CREATE INDEX idx_orders_status_customer_date 
ON orders(status, customer_id, created_at);

-- This index can be used for queries like:
-- ✅ WHERE status = 'pending'
-- ✅ WHERE status = 'pending' AND customer_id = 123
-- ✅ WHERE status = 'pending' AND customer_id = 123 AND created_at > '2024-01-01'

-- But NOT efficiently for:
-- ❌ WHERE customer_id = 123 (first column not specified)
-- ❌ WHERE created_at > '2024-01-01' (first columns not specified)

-- Rule: Index can be used for queries that match columns from left to right

-- ======================
-- INDEX TYPE 3: Partial Index
-- Index only a subset of rows (smaller, faster)
-- ======================

-- Index only pending orders
CREATE INDEX idx_orders_pending 
ON orders(customer_id, created_at) 
WHERE status = 'pending';

-- Benefits:
-- - Smaller index size
-- - Faster maintenance
-- - Perfect for queries like:
--   SELECT * FROM orders WHERE status = 'pending' AND customer_id = 123;

-- More examples:
CREATE INDEX idx_active_users 
ON users(email) 
WHERE active = true;

CREATE INDEX idx_recent_orders 
ON orders(customer_id) 
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days';

-- ======================
-- INDEX TYPE 4: Unique Index
-- Enforces uniqueness and provides index benefits
-- ======================

-- Unique index on email
CREATE UNIQUE INDEX idx_users_email_unique 
ON users(email);

-- Unique composite index
CREATE UNIQUE INDEX idx_user_sessions_unique 
ON user_sessions(user_id, session_token);

-- ======================
-- INDEX TYPE 5: Covering Index (INCLUDE clause)
-- PostgreSQL 11+ - includes extra columns for index-only scans
-- ======================

-- Index on customer_id that "covers" total and created_at
CREATE INDEX idx_orders_customer_covering 
ON orders(customer_id) 
INCLUDE (total, created_at, status);

-- Query can be satisfied entirely from the index (no table access needed):
-- SELECT customer_id, total, created_at, status 
-- FROM orders 
-- WHERE customer_id = 123;

-- ======================
-- INDEX TYPE 6: Expression/Functional Index
-- Index on the result of an expression or function
-- ======================

-- Index on lowercase email
CREATE INDEX idx_users_email_lower 
ON users(LOWER(email));

-- Now this query can use the index:
-- SELECT * FROM users WHERE LOWER(email) = 'test@example.com';

-- Index on extracted year
CREATE INDEX idx_orders_year 
ON orders(EXTRACT(YEAR FROM created_at));

-- Index on JSON field (PostgreSQL)
CREATE INDEX idx_users_preferences_theme 
ON users((preferences->>'theme'));

-- ======================
-- INDEX TYPE 7: Text Search Index (GIN)
-- For full-text search capabilities
-- ======================

-- Create GIN index for full-text search
CREATE INDEX idx_products_name_fulltext 
ON products 
USING gin(to_tsvector('english', name));

-- Query using the index:
-- SELECT * FROM products 
-- WHERE to_tsvector('english', name) @@ to_tsquery('phone');

-- Multi-column text search
CREATE INDEX idx_products_search 
ON products 
USING gin(to_tsvector('english', name || ' ' || description));

-- ======================
-- INDEX TYPE 8: Array Index (GIN)
-- For queries on array columns
-- ======================

-- Index on array column
CREATE INDEX idx_posts_tags 
ON posts 
USING gin(tags);

-- Queries that can use this index:
-- SELECT * FROM posts WHERE tags @> ARRAY['postgresql'];
-- SELECT * FROM posts WHERE tags && ARRAY['database', 'sql'];

-- ======================
-- INDEX TYPE 9: JSONB Index (GIN)
-- For JSONB column queries
-- ======================

-- Index entire JSONB column
CREATE INDEX idx_users_metadata 
ON users 
USING gin(metadata);

-- Specific JSON path index
CREATE INDEX idx_users_metadata_city 
ON users 
USING btree((metadata->>'city'));

-- ======================
-- INDEX TYPE 10: Descending Index
-- For descending sort operations
-- ======================

-- Index for ORDER BY created_at DESC
CREATE INDEX idx_orders_created_desc 
ON orders(created_at DESC);

-- Composite with mixed order
CREATE INDEX idx_orders_status_date_desc 
ON orders(status ASC, created_at DESC);

-- ======================
-- INDEX MAINTENANCE
-- ======================

-- Check index usage
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE indexrelname = 'idx_orders_customer_id';

-- Rebuild a fragmented index
REINDEX INDEX idx_orders_customer_id;

-- Rebuild all indexes on a table
REINDEX TABLE orders;

-- Drop an unused index
DROP INDEX IF EXISTS idx_old_unused_index;

-- ======================
-- INDEX CREATION STRATEGIES
-- ======================

-- Strategy 1: Start with most common queries
-- Identify your top 10 most frequent queries
-- Create indexes to support them

-- Strategy 2: Index foreign keys
-- Always index foreign key columns for JOIN performance
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
CREATE INDEX idx_order_items_product_id ON order_items(product_id);

-- Strategy 3: Index WHERE clause columns
-- If you frequently filter by a column, consider indexing it
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);

-- Strategy 4: Index ORDER BY columns
-- Especially for paginated queries
CREATE INDEX idx_products_created_at_desc ON products(created_at DESC);

-- Strategy 5: Composite indexes for multiple conditions
-- When queries use multiple columns together
CREATE INDEX idx_orders_customer_status_date 
ON orders(customer_id, status, created_at);

-- ======================
-- COMMON PITFALLS TO AVOID
-- ======================

-- ❌ Don't create redundant indexes
-- If you have: idx_orders_customer_id
-- Don't create: idx_orders_customer_id_status (duplicates first column)

-- ❌ Don't over-index
-- Each index has a cost: storage + INSERT/UPDATE/DELETE overhead
-- Only create indexes that are actually used

-- ❌ Don't index low-cardinality columns alone
-- Don't index: status (if only 3-4 values)
-- Do index: user_id (high cardinality)

-- ❌ Don't forget to ANALYZE after creating indexes
ANALYZE orders;

-- ======================
-- TESTING INDEX EFFECTIVENESS
-- ======================

-- Before creating index:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 123;

-- Create index
CREATE INDEX idx_orders_customer_id ON orders(customer_id);

-- After creating index:
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 123;

-- Compare:
-- - Execution time
-- - Number of rows scanned
-- - Use of index scan vs sequential scan

-- ======================
-- INDEX SIZE MONITORING
-- ======================

-- Check index sizes
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
ORDER BY pg_relation_size(indexrelid) DESC;

-- Total index size for a table
SELECT 
    pg_size_pretty(
        pg_total_relation_size('orders') - pg_relation_size('orders')
    ) AS total_index_size;

-- ======================
-- RECOMMENDATIONS
-- ======================

-- 1. Monitor index usage with pg_stat_user_indexes
-- 2. Drop unused indexes (idx_scan = 0)
-- 3. Regular REINDEX for heavily updated tables
-- 4. Use EXPLAIN ANALYZE to verify index usage
-- 5. Consider partial indexes for large tables
-- 6. Update statistics with ANALYZE after index creation
-- 7. Test index impact on INSERT/UPDATE performance
-- 8. Document why each index exists
