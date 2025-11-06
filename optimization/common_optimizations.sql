-- ============================================
-- Common SQL Query Optimizations
-- Before/After examples of frequent optimization patterns
-- ============================================

-- ======================
-- OPTIMIZATION 1: Avoid NOT IN with NULLs
-- ======================

-- ❌ BEFORE: Using NOT IN (slow and buggy with NULLs)
-- If blocked_customers contains any NULL, this returns no rows!
SELECT * 
FROM orders 
WHERE customer_id NOT IN (SELECT id FROM blocked_customers);

-- ✅ AFTER: Using NOT EXISTS (faster and handles NULLs correctly)
SELECT o.* 
FROM orders o
WHERE NOT EXISTS (
    SELECT 1 
    FROM blocked_customers bc 
    WHERE bc.id = o.customer_id
);

-- Alternative: Use LEFT JOIN with NULL check
SELECT o.*
FROM orders o
LEFT JOIN blocked_customers bc ON bc.id = o.customer_id
WHERE bc.id IS NULL;

-- ======================
-- OPTIMIZATION 2: Use IN instead of OR
-- ======================

-- ❌ BEFORE: Using OR (prevents index usage in some cases)
SELECT * 
FROM products 
WHERE category = 'Electronics' 
   OR category = 'Computers'
   OR category = 'Phones';

-- ✅ AFTER: Using IN (can use index efficiently)
SELECT * 
FROM products 
WHERE category IN ('Electronics', 'Computers', 'Phones');

-- ======================
-- OPTIMIZATION 3: Avoid Functions on Indexed Columns
-- ======================

-- ❌ BEFORE: Function on indexed column (prevents index usage)
SELECT * 
FROM users 
WHERE LOWER(email) = 'test@example.com';

-- ✅ AFTER: Store data in correct case or create functional index
-- Option 1: Query adjustment (if data is consistent)
SELECT * 
FROM users 
WHERE email = 'test@example.com';

-- Option 2: Create functional index
-- CREATE INDEX idx_users_email_lower ON users (LOWER(email));
-- Then the original query will use the index

-- ======================
-- OPTIMIZATION 4: SELECT Specific Columns
-- ======================

-- ❌ BEFORE: SELECT * (retrieves unnecessary data)
SELECT * 
FROM orders 
WHERE status = 'pending';

-- ✅ AFTER: Select only needed columns (less I/O, less memory)
SELECT id, customer_id, total, created_at 
FROM orders 
WHERE status = 'pending';

-- ======================
-- OPTIMIZATION 5: Use EXISTS instead of COUNT
-- ======================

-- ❌ BEFORE: Using COUNT to check existence (scans all matching rows)
SELECT CASE WHEN (SELECT COUNT(*) FROM orders WHERE customer_id = 123) > 0 
       THEN 'Has orders' 
       ELSE 'No orders' 
       END;

-- ✅ AFTER: Using EXISTS (stops at first match)
SELECT CASE WHEN EXISTS (SELECT 1 FROM orders WHERE customer_id = 123)
       THEN 'Has orders'
       ELSE 'No orders'
       END;

-- ======================
-- OPTIMIZATION 6: Avoid LIKE with Leading Wildcard
-- ======================

-- ❌ BEFORE: Leading wildcard (cannot use index)
SELECT * 
FROM products 
WHERE name LIKE '%phone%';

-- ✅ AFTER: Use full-text search or rewrite query
-- Option 1: If you can avoid leading wildcard
SELECT * 
FROM products 
WHERE name LIKE 'phone%';

-- Option 2: Use full-text search (PostgreSQL)
-- CREATE INDEX idx_products_name_fts ON products USING gin(to_tsvector('english', name));
-- SELECT * FROM products WHERE to_tsvector('english', name) @@ to_tsquery('phone');

-- ======================
-- OPTIMIZATION 7: Use UNION ALL instead of UNION
-- ======================

-- ❌ BEFORE: UNION (removes duplicates, slower)
SELECT customer_id FROM orders
UNION
SELECT customer_id FROM archived_orders;

-- ✅ AFTER: UNION ALL (no deduplication if not needed)
SELECT customer_id FROM orders
UNION ALL
SELECT customer_id FROM archived_orders;

-- Use UNION ALL when you know there are no duplicates
-- or when duplicates are acceptable

-- ======================
-- OPTIMIZATION 8: Optimize JOIN Order
-- ======================

-- ❌ BEFORE: Small table joined to large table without proper indexing
SELECT o.*, c.name
FROM orders o
JOIN customers c ON c.id = o.customer_id
WHERE o.created_at >= '2024-01-01';

-- ✅ AFTER: Filter first, then join
SELECT o.*, c.name
FROM (
    SELECT * FROM orders WHERE created_at >= '2024-01-01'
) o
JOIN customers c ON c.id = o.customer_id;

-- Even better: Ensure indexes exist
-- CREATE INDEX idx_orders_created_at ON orders(created_at);
-- CREATE INDEX idx_orders_customer_id ON orders(customer_id);
-- CREATE INDEX idx_customers_id ON customers(id);

-- ======================
-- OPTIMIZATION 9: Avoid Subqueries in SELECT
-- ======================

-- ❌ BEFORE: Subquery for each row (N+1 problem)
SELECT 
    c.id,
    c.name,
    (SELECT COUNT(*) FROM orders WHERE customer_id = c.id) AS order_count
FROM customers c;

-- ✅ AFTER: Use JOIN or window function
SELECT 
    c.id,
    c.name,
    COUNT(o.id) AS order_count
FROM customers c
LEFT JOIN orders o ON o.customer_id = c.id
GROUP BY c.id, c.name;

-- ======================
-- OPTIMIZATION 10: Use LIMIT to Reduce Result Set
-- ======================

-- ❌ BEFORE: Fetching all rows when only few needed
SELECT * 
FROM products 
ORDER BY created_at DESC;

-- ✅ AFTER: Use LIMIT (especially for pagination)
SELECT * 
FROM products 
ORDER BY created_at DESC
LIMIT 20;

-- For pagination:
SELECT * 
FROM products 
ORDER BY created_at DESC
LIMIT 20 OFFSET 40;  -- Page 3

-- ======================
-- OPTIMIZATION 11: Optimize WHERE with Multiple Conditions
-- ======================

-- ❌ BEFORE: Non-selective condition first
SELECT * 
FROM orders 
WHERE status = 'completed'  -- Matches 90% of rows
  AND customer_id = 123;    -- Matches 0.01% of rows

-- ✅ AFTER: Most selective condition first (when no index)
SELECT * 
FROM orders 
WHERE customer_id = 123     -- Most selective first
  AND status = 'completed';

-- Best: Create composite index
-- CREATE INDEX idx_orders_customer_status ON orders(customer_id, status);

-- ======================
-- OPTIMIZATION 12: Avoid OR with Different Columns
-- ======================

-- ❌ BEFORE: OR with different columns (difficult to optimize)
SELECT * 
FROM orders 
WHERE customer_id = 123 
   OR status = 'pending';

-- ✅ AFTER: Use UNION ALL with separate queries
SELECT * FROM orders WHERE customer_id = 123
UNION ALL
SELECT * FROM orders WHERE status = 'pending' AND customer_id != 123;

-- ======================
-- OPTIMIZATION 13: Use Appropriate Data Types
-- ======================

-- ❌ BEFORE: Storing numbers as strings
-- CREATE TABLE products (
--     id INT,
--     price VARCHAR(20)  -- Bad: storing number as string
-- );

-- ✅ AFTER: Use proper numeric type
-- CREATE TABLE products (
--     id INT,
--     price DECIMAL(10,2)  -- Good: proper numeric type
-- );

-- ======================
-- OPTIMIZATION 14: Batch INSERT Operations
-- ======================

-- ❌ BEFORE: Individual INSERTs in loop
-- INSERT INTO logs (message) VALUES ('Log 1');
-- INSERT INTO logs (message) VALUES ('Log 2');
-- INSERT INTO logs (message) VALUES ('Log 3');
-- ... (1000 times)

-- ✅ AFTER: Batch INSERT
INSERT INTO logs (message) VALUES 
    ('Log 1'),
    ('Log 2'),
    ('Log 3'),
    ('Log 4'),
    -- ... up to reasonable batch size (e.g., 1000 rows)
    ('Log 1000');

-- ======================
-- OPTIMIZATION 15: Use Partial Indexes
-- ======================

-- ❌ BEFORE: Full index on large table
-- CREATE INDEX idx_orders_status ON orders(status);

-- ✅ AFTER: Partial index for specific common queries
-- Index only pending orders (if that's what you query most)
CREATE INDEX idx_orders_pending ON orders(customer_id) 
WHERE status = 'pending';

-- This index is smaller and faster for queries like:
-- SELECT * FROM orders WHERE status = 'pending' AND customer_id = 123;

-- ======================
-- GENERAL TIPS
-- ======================

-- 1. Always use EXPLAIN ANALYZE to verify improvements
-- EXPLAIN ANALYZE SELECT ...;

-- 2. Update table statistics after major changes
-- ANALYZE tablename;

-- 3. Monitor slow query logs
-- Check postgresql.conf: log_min_duration_statement

-- 4. Use prepared statements to reduce parsing overhead

-- 5. Consider connection pooling for high-traffic applications

-- 6. Regular VACUUM to prevent table bloat

-- 7. Monitor cache hit ratios (should be > 95%)
