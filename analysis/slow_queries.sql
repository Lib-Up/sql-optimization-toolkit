-- ============================================
-- Slow Query Analysis for PostgreSQL
-- Identifies currently running slow queries
-- and historical slow query patterns
-- ============================================

-- ======================
-- PART 1: Currently Running Slow Queries
-- ======================

SELECT 
    pid,
    usename AS username,
    datname AS database,
    now() - query_start AS duration,
    state,
    wait_event_type,
    wait_event,
    LEFT(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
    AND now() - query_start > interval '1 second'
    AND pid != pg_backend_pid()  -- Exclude this query itself
ORDER BY duration DESC;

-- ======================
-- PART 2: Slow Query Statistics
-- Requires pg_stat_statements extension
-- ======================

-- Check if pg_stat_statements is installed
-- If not, run: CREATE EXTENSION pg_stat_statements;

SELECT 
    calls,
    ROUND(total_exec_time::numeric, 2) AS total_time_ms,
    ROUND(mean_exec_time::numeric, 2) AS avg_time_ms,
    ROUND(max_exec_time::numeric, 2) AS max_time_ms,
    ROUND(min_exec_time::numeric, 2) AS min_time_ms,
    ROUND((total_exec_time / sum(total_exec_time) OVER ()) * 100, 2) AS percent_total_time,
    LEFT(query, 120) AS query_preview
FROM pg_stat_statements
WHERE mean_exec_time > 100  -- Queries averaging > 100ms
ORDER BY mean_exec_time DESC
LIMIT 20;

-- ======================
-- PART 3: Top Time-Consuming Queries
-- ======================

SELECT 
    calls,
    ROUND(total_exec_time::numeric / 1000, 2) AS total_time_seconds,
    ROUND(mean_exec_time::numeric, 2) AS avg_time_ms,
    ROUND((total_exec_time / sum(total_exec_time) OVER ()) * 100, 2) AS percent_of_total,
    LEFT(query, 100) AS query_preview
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- ======================
-- PART 4: Queries with High I/O
-- ======================

SELECT 
    calls,
    shared_blks_hit AS cache_hits,
    shared_blks_read AS disk_reads,
    CASE 
        WHEN (shared_blks_hit + shared_blks_read) > 0 
        THEN ROUND((shared_blks_hit::numeric / (shared_blks_hit + shared_blks_read)) * 100, 2)
        ELSE 0 
    END AS cache_hit_ratio,
    ROUND(mean_exec_time::numeric, 2) AS avg_time_ms,
    LEFT(query, 100) AS query_preview
FROM pg_stat_statements
WHERE (shared_blks_hit + shared_blks_read) > 0
ORDER BY shared_blks_read DESC
LIMIT 20;

-- ======================
-- PART 5: Most Frequently Called Queries
-- ======================

SELECT 
    calls,
    ROUND(mean_exec_time::numeric, 2) AS avg_time_ms,
    ROUND(total_exec_time::numeric / 1000, 2) AS total_time_seconds,
    LEFT(query, 100) AS query_preview
FROM pg_stat_statements
ORDER BY calls DESC
LIMIT 20;

-- ======================
-- NOTES
-- ======================

-- To reset statistics (use with caution):
-- SELECT pg_stat_statements_reset();

-- To see all available columns:
-- \d pg_stat_statements

-- To enable pg_stat_statements if not already:
-- 1. Add to postgresql.conf: shared_preload_libraries = 'pg_stat_statements'
-- 2. Restart PostgreSQL
-- 3. CREATE EXTENSION pg_stat_statements;
