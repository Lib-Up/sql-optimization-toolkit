-- ============================================
-- Index Recommendations for PostgreSQL
-- Identifies missing indexes and unused indexes
-- ============================================

-- ======================
-- PART 1: Tables Needing Indexes
-- Sequential scans on large tables suggest missing indexes
-- ======================

SELECT 
    schemaname,
    tablename,
    seq_scan AS sequential_scans,
    seq_tup_read AS rows_read_sequentially,
    idx_scan AS index_scans,
    CASE 
        WHEN seq_scan > 0 
        THEN ROUND(seq_tup_read::numeric / seq_scan, 0)
        ELSE 0 
    END AS avg_rows_per_scan,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS table_size
FROM pg_stat_user_tables
WHERE seq_scan > 0
    AND idx_scan = 0  -- No index scans at all
    AND seq_tup_read > 10000  -- Reading significant data
ORDER BY seq_tup_read DESC
LIMIT 20;

-- ======================
-- PART 2: Tables with Disproportionate Sequential Scans
-- High seq_scan compared to idx_scan
-- ======================

SELECT 
    schemaname,
    tablename,
    seq_scan AS sequential_scans,
    idx_scan AS index_scans,
    ROUND((seq_scan::numeric / NULLIF(seq_scan + idx_scan, 0)) * 100, 2) AS seq_scan_percent,
    n_live_tup AS estimated_rows,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS table_size
FROM pg_stat_user_tables
WHERE (seq_scan + idx_scan) > 0
    AND seq_scan > idx_scan  -- More sequential than index scans
    AND n_live_tup > 1000  -- Only for tables with significant data
ORDER BY seq_scan DESC
LIMIT 20;

-- ======================
-- PART 3: Unused Indexes
-- Indexes that are never used (candidates for removal)
-- ======================

SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS times_used,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS table_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0  -- Never used
    AND indexrelname NOT LIKE '%_pkey'  -- Exclude primary keys
    AND indexrelname NOT LIKE '%_fkey'  -- Exclude foreign keys
ORDER BY pg_relation_size(indexrelid) DESC;

-- ======================
-- PART 4: Duplicate/Redundant Indexes
-- Indexes on the same columns
-- ======================

SELECT 
    a.schemaname,
    a.tablename,
    a.indexname AS index1,
    b.indexname AS index2,
    a.indexdef AS index1_definition,
    b.indexdef AS index2_definition,
    pg_size_pretty(pg_relation_size(a.indexrelid)) AS index1_size,
    pg_size_pretty(pg_relation_size(b.indexrelid)) AS index2_size
FROM pg_indexes a
JOIN pg_indexes b 
    ON a.schemaname = b.schemaname 
    AND a.tablename = b.tablename 
    AND a.indexname < b.indexname
WHERE a.indexdef = b.indexdef  -- Exact duplicates
    OR (
        -- Indexes on same columns but different order might be redundant
        regexp_replace(a.indexdef, '\(.*\)', '') = 
        regexp_replace(b.indexdef, '\(.*\)', '')
    );

-- ======================
-- PART 5: Index Usage Statistics
-- Overview of how indexes are being used
-- ======================

SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan AS times_used,
    idx_tup_read AS tuples_read,
    idx_tup_fetch AS tuples_fetched,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size,
    CASE 
        WHEN idx_scan > 0 
        THEN ROUND(idx_tup_read::numeric / idx_scan, 0)
        ELSE 0 
    END AS avg_tuples_per_scan
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC, pg_relation_size(indexrelid) DESC
LIMIT 30;

-- ======================
-- PART 6: Cache Hit Ratio for Indexes
-- How well indexes are cached
-- ======================

SELECT 
    schemaname,
    tablename,
    indexname,
    idx_blks_hit AS cache_hits,
    idx_blks_read AS disk_reads,
    CASE 
        WHEN (idx_blks_hit + idx_blks_read) > 0 
        THEN ROUND((idx_blks_hit::numeric / (idx_blks_hit + idx_blks_read)) * 100, 2)
        ELSE 100 
    END AS cache_hit_ratio,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_statio_user_indexes
WHERE (idx_blks_hit + idx_blks_read) > 0
ORDER BY cache_hit_ratio ASC, (idx_blks_hit + idx_blks_read) DESC
LIMIT 20;

-- ======================
-- PART 7: Missing Foreign Key Indexes
-- Foreign keys without indexes (causes slow JOINs)
-- ======================

SELECT 
    c.conrelid::regclass AS table_name,
    string_agg(a.attname, ', ') AS columns,
    'Missing index on ' || c.conrelid::regclass || 
    ' (' || string_agg(a.attname, ', ') || ')' AS recommendation
FROM pg_constraint c
JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = ANY(c.conkey)
WHERE c.contype = 'f'  -- Foreign key constraints
    AND NOT EXISTS (
        SELECT 1
        FROM pg_index i
        WHERE i.indrelid = c.conrelid
            AND c.conkey[1] = ANY(i.indkey)
    )
GROUP BY c.conrelid, c.conname
ORDER BY c.conrelid::regclass::text;

-- ======================
-- RECOMMENDATIONS SUMMARY
-- ======================

-- To create an index based on findings:
-- CREATE INDEX idx_tablename_columnname ON tablename(columnname);

-- To drop an unused index:
-- DROP INDEX IF EXISTS indexname;

-- To analyze a table and update statistics:
-- ANALYZE tablename;
