-- ============================================
-- Table Statistics and Analysis for PostgreSQL
-- Comprehensive table size, row count, and bloat analysis
-- ============================================

-- ======================
-- PART 1: Table Size Overview
-- Complete breakdown of table and index sizes
-- ======================

SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - 
                   pg_relation_size(schemaname||'.'||tablename)) AS indexes_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - 
                   pg_relation_size(schemaname||'.'||tablename) -
                   COALESCE(pg_total_relation_size(schemaname||'.'||tablename||'_toast'), 0)) AS toast_size,
    n_live_tup AS row_count,
    n_dead_tup AS dead_rows,
    ROUND(100 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_row_percent,
    last_vacuum,
    last_autovacuum,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 30;

-- ======================
-- PART 2: Largest Tables
-- Top 20 largest tables by total size
-- ======================

SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
    pg_total_relation_size(schemaname||'.'||tablename) AS size_bytes,
    n_live_tup AS row_count,
    ROUND(pg_total_relation_size(schemaname||'.'||tablename)::numeric / 
          NULLIF(n_live_tup, 0), 2) AS bytes_per_row
FROM pg_stat_user_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

-- ======================
-- PART 3: Tables with Most Dead Tuples
-- Candidates for VACUUM
-- ======================

SELECT 
    schemaname,
    tablename,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_percent,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS table_size,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE n_dead_tup > 0
ORDER BY n_dead_tup DESC
LIMIT 20;

-- ======================
-- PART 4: Table Bloat Estimation
-- Approximate bloat in tables
-- ======================

SELECT
    schemaname,
    tablename,
    ROUND(100 * (pg_relation_size(schemaname||'.'||tablename) - 
          (n_live_tup * 
           (SELECT current_setting('block_size')::numeric / 
            (SELECT max(avg_width) FROM pg_stats WHERE tablename = t.tablename))
          )) / NULLIF(pg_relation_size(schemaname||'.'||tablename), 0), 2) AS estimated_bloat_percent,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size,
    n_live_tup AS row_count
FROM pg_stat_user_tables t
WHERE pg_relation_size(schemaname||'.'||tablename) > 1048576  -- > 1MB
ORDER BY estimated_bloat_percent DESC NULLS LAST
LIMIT 20;

-- ======================
-- PART 5: Index Sizes per Table
-- How much space indexes take per table
-- ======================

SELECT 
    t.schemaname,
    t.tablename,
    COUNT(i.indexname) AS index_count,
    pg_size_pretty(pg_total_relation_size(t.schemaname||'.'||t.tablename) - 
                   pg_relation_size(t.schemaname||'.'||t.tablename)) AS total_index_size,
    pg_size_pretty(pg_relation_size(t.schemaname||'.'||t.tablename)) AS table_size,
    ROUND(100 * (pg_total_relation_size(t.schemaname||'.'||t.tablename) - 
                 pg_relation_size(t.schemaname||'.'||t.tablename))::numeric / 
          NULLIF(pg_total_relation_size(t.schemaname||'.'||t.tablename), 0), 2) AS index_percent
FROM pg_stat_user_tables t
LEFT JOIN pg_stat_user_indexes i ON t.schemaname = i.schemaname AND t.tablename = i.tablename
GROUP BY t.schemaname, t.tablename
ORDER BY (pg_total_relation_size(t.schemaname||'.'||t.tablename) - 
          pg_relation_size(t.schemaname||'.'||t.tablename)) DESC
LIMIT 20;

-- ======================
-- PART 6: Row Count and Table Activity
-- Insert/Update/Delete activity
-- ======================

SELECT 
    schemaname,
    tablename,
    n_live_tup AS current_rows,
    n_tup_ins AS total_inserts,
    n_tup_upd AS total_updates,
    n_tup_del AS total_deletes,
    n_tup_hot_upd AS hot_updates,
    CASE 
        WHEN n_tup_upd > 0 
        THEN ROUND(100 * n_tup_hot_upd::numeric / n_tup_upd, 2)
        ELSE 0 
    END AS hot_update_percent,
    last_vacuum,
    last_autovacuum,
    vacuum_count,
    autovacuum_count
FROM pg_stat_user_tables
ORDER BY (n_tup_ins + n_tup_upd + n_tup_del) DESC
LIMIT 20;

-- ======================
-- PART 7: Database-wide Statistics
-- Overall database size and object counts
-- ======================

SELECT 
    'Total Database Size' AS metric,
    pg_size_pretty(pg_database_size(current_database())) AS value
UNION ALL
SELECT 
    'Total Tables',
    COUNT(*)::text
FROM pg_stat_user_tables
UNION ALL
SELECT 
    'Total Indexes',
    COUNT(*)::text
FROM pg_stat_user_indexes
UNION ALL
SELECT 
    'Total Rows (estimated)',
    SUM(n_live_tup)::text
FROM pg_stat_user_tables
UNION ALL
SELECT 
    'Total Dead Rows',
    SUM(n_dead_tup)::text
FROM pg_stat_user_tables
UNION ALL
SELECT 
    'Tables Needing VACUUM',
    COUNT(*)::text
FROM pg_stat_user_tables
WHERE n_dead_tup > n_live_tup * 0.1;

-- ======================
-- PART 8: Growth Trend (if you have historical data)
-- Requires periodic saving of statistics
-- ======================

-- Create a table to track historical statistics:
-- CREATE TABLE table_size_history (
--     recorded_at timestamp DEFAULT now(),
--     schemaname text,
--     tablename text,
--     total_size bigint,
--     row_count bigint
-- );

-- Insert current statistics:
-- INSERT INTO table_size_history (schemaname, tablename, total_size, row_count)
-- SELECT schemaname, tablename, 
--        pg_total_relation_size(schemaname||'.'||tablename),
--        n_live_tup
-- FROM pg_stat_user_tables;

-- Query growth over time:
-- SELECT 
--     tablename,
--     pg_size_pretty(MAX(total_size) - MIN(total_size)) AS size_growth,
--     MAX(row_count) - MIN(row_count) AS row_growth,
--     MIN(recorded_at) AS first_recorded,
--     MAX(recorded_at) AS last_recorded
-- FROM table_size_history
-- GROUP BY tablename
-- ORDER BY (MAX(total_size) - MIN(total_size)) DESC;

-- ======================
-- PART 9: Tables That Need ANALYZE
-- Tables with outdated statistics
-- ======================

SELECT 
    schemaname,
    tablename,
    n_live_tup AS row_count,
    n_mod_since_analyze AS rows_modified_since_analyze,
    CASE 
        WHEN n_live_tup > 0 
        THEN ROUND(100 * n_mod_since_analyze::numeric / n_live_tup, 2)
        ELSE 0 
    END AS percent_modified,
    last_analyze,
    last_autoanalyze
FROM pg_stat_user_tables
WHERE n_mod_since_analyze > n_live_tup * 0.1  -- > 10% modified
    OR last_analyze IS NULL
ORDER BY n_mod_since_analyze DESC
LIMIT 20;

-- ======================
-- MAINTENANCE RECOMMENDATIONS
-- ======================

-- To vacuum a specific table:
-- VACUUM ANALYZE tablename;

-- To vacuum all tables:
-- VACUUM ANALYZE;

-- To vacuum with full table rewrite (reclaims space):
-- VACUUM FULL tablename;  -- CAUTION: Locks table, can be slow

-- To update statistics only:
-- ANALYZE tablename;

-- To reindex a table:
-- REINDEX TABLE tablename;

-- To reindex all tables in schema:
-- REINDEX SCHEMA public;
