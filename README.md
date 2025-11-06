# SQL Optimization Toolkit

Comprehensive toolkit for database performance analysis and optimization. Includes query analyzers, index recommendations, monitoring scripts, and real-world optimization examples.

## 🎯 What's Included

### 📊 Analysis Tools
- **Slow Query Detection** - Identify performance bottlenecks
- **Index Recommendations** - Suggest missing or unused indexes
- **Table Statistics** - Analyze table sizes and row counts
- **Query Performance Analysis** - Detailed execution metrics

### ⚡ Optimization Scripts
- **Common Optimizations** - Before/after examples
- **Index Strategies** - Best practices for indexing
- **Query Rewriting** - Performance improvement patterns

### 📈 Monitoring
- **Performance Monitor** - Real-time database monitoring
- **Alert System** - Automated performance alerts
- **Query Statistics** - Track query execution over time

### 📚 Documentation
- **Case Studies** - Real-world optimization examples
- **Best Practices** - Database optimization guidelines
- **Troubleshooting** - Common issues and solutions

## 💡 Supported Databases

- ✅ **PostgreSQL** (Primary focus)
- ✅ **MySQL** / MariaDB
- ✅ **SQL Server** (Limited support)

## 📋 Requirements

### For Analysis Scripts (SQL)
```bash
# PostgreSQL
sudo apt-get install postgresql-client

# MySQL
sudo apt-get install mysql-client
```

### For Monitoring Scripts (Python)
```bash
pip install psycopg2-binary pymysql
```

## 🚀 Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/sql-optimization-toolkit.git
cd sql-optimization-toolkit
```

### 2. Run Analysis

#### PostgreSQL
```bash
# Connect to your database
psql -h localhost -U postgres -d mydb

# Run slow query analysis
\i analysis/slow_queries.sql

# Get index recommendations
\i analysis/index_recommendations.sql

# View table statistics
\i analysis/table_statistics.sql
```

#### MySQL
```bash
# Connect to your database
mysql -h localhost -u root -p mydb

# Run analysis scripts
source analysis/slow_queries_mysql.sql;
```

### 3. Apply Optimizations
```bash
# Review optimization examples
\i optimization/common_optimizations.sql

# Create recommended indexes
\i optimization/index_creation.sql
```

### 4. Start Monitoring
```python
# Install dependencies
pip install psycopg2-binary

# Run monitor
python3 monitoring/performance_monitor.py
```

## 📁 Project Structure
```
sql-optimization-toolkit/
├── analysis/                      # Database analysis scripts
│   ├── slow_queries.sql          # Identify slow queries
│   ├── index_recommendations.sql # Missing/unused indexes
│   └── table_statistics.sql      # Table size analysis
├── optimization/                  # Optimization examples
│   ├── common_optimizations.sql  # Query optimization patterns
│   └── index_creation.sql        # Index creation strategies
├── monitoring/                    # Monitoring tools
│   └── performance_monitor.py    # Real-time monitoring
├── examples/                      # Case studies
│   └── case_studies.md          # Real-world examples
└── README.md                     # This file
```

## 🔍 Analysis Scripts

### Slow Queries Analysis

Identifies queries that are currently running slow or have slow execution history.
```sql
-- PostgreSQL
\i analysis/slow_queries.sql

-- Shows:
-- - Currently running slow queries
-- - Query execution time
-- - Query statistics from pg_stat_statements
```

**Key Metrics:**
- Execution time
- Number of calls
- Average time per call
- Total time spent

### Index Recommendations

Analyzes table access patterns to recommend indexes.
```sql
\i analysis/index_recommendations.sql

-- Shows:
-- - Tables with high sequential scans
-- - Unused indexes (candidates for removal)
-- - Index usage statistics
```

**Benefits:**
- Reduce sequential scans
- Improve query performance
- Optimize disk space usage

### Table Statistics

Comprehensive table analysis including size, row counts, and bloat.
```sql
\i analysis/table_statistics.sql

-- Shows:
-- - Table sizes (data + indexes)
-- - Row counts
-- - Dead rows (candidates for VACUUM)
-- - Index sizes
```

## ⚡ Optimization Examples

### Common Query Optimizations

Before and after examples of common optimization patterns:

- Using EXISTS instead of NOT IN
- Using IN instead of OR
- Avoiding functions on indexed columns
- Selecting specific columns vs SELECT *
```sql
\i optimization/common_optimizations.sql
```

### Index Strategies

Examples of different index types and when to use them:

- B-tree indexes (default)
- Partial indexes
- Composite indexes
- Covering indexes
- GIN indexes (full-text search)
```sql
\i optimization/index_creation.sql
```

## 📈 Monitoring

### Real-time Performance Monitor

Python script for continuous database monitoring.
```python
python3 monitoring/performance_monitor.py
```

**Features:**
- Detects slow-running queries
- Monitors system resources
- Sends alerts for threshold violations
- Logs all monitoring activity

**Configuration:**
```python
config = {
    'host': 'localhost',
    'port': 5432,
    'database': 'mydb',
    'user': 'postgres',
    'password': 'your_password'
}
```

**Usage:**
```bash
# One-time check
python3 monitoring/performance_monitor.py

# Continuous monitoring (every 60 seconds)
# Uncomment in the script:
# monitor.monitor(interval=60)
```

## 📚 Case Studies

### Case Study 1: Order Query Optimization

**Problem:** Query taking 2.5 seconds on 5M row table

**Solution:** Added index on customer_id

**Result:** 50x faster (0.05 seconds)

[Read full case study](examples/case_studies.md#case-study-1)

### Case Study 2: JOIN Optimization

**Problem:** Complex JOIN taking 8 seconds

**Solution:** Created covering index

**Result:** 26x faster (0.3 seconds)

[Read full case study](examples/case_studies.md#case-study-2)

### Case Study 3: Aggregation Query

**Problem:** Aggregation query taking 15 seconds

**Solution:** Used materialized view

**Result:** 1500x faster (0.01 seconds)

[Read full case study](examples/case_studies.md#case-study-3)

## 🎓 Best Practices

### Query Optimization

1. **Always use EXPLAIN ANALYZE** to understand query execution
2. **Index strategically** - not every column needs an index
3. **Monitor index usage** - remove unused indexes
4. **Use appropriate JOIN types** - INNER vs LEFT vs RIGHT
5. **Avoid SELECT *** - specify needed columns only

### Index Strategy

1. **Index foreign keys** - essential for JOIN performance
2. **Create composite indexes** for multi-column queries
3. **Use partial indexes** for filtered queries
4. **Covering indexes** for frequently accessed columns
5. **Monitor bloat** - rebuild fragmented indexes

### Maintenance

1. **Regular VACUUM** - remove dead tuples
2. **ANALYZE tables** - update statistics
3. **REINDEX** - rebuild fragmented indexes
4. **Monitor disk space** - prevent storage issues
5. **Review slow query log** - identify bottlenecks

## 🔧 Configuration Tips

### PostgreSQL Configuration
```ini
# postgresql.conf optimizations

# Memory
shared_buffers = 256MB              # 25% of RAM
effective_cache_size = 1GB          # 50-75% of RAM
work_mem = 16MB                     # Per query memory

# Query Planning
random_page_cost = 1.1              # For SSDs
effective_io_concurrency = 200      # For SSDs

# Logging
log_min_duration_statement = 1000   # Log slow queries (ms)
log_line_prefix = '%t [%p]: '       # Timestamp and PID
```

### MySQL Configuration
```ini
# my.cnf optimizations

[mysqld]
# Memory
innodb_buffer_pool_size = 1G        # 70-80% of RAM
query_cache_size = 64M
tmp_table_size = 64M

# Logging
slow_query_log = 1
long_query_time = 1                 # Log queries > 1 second
```

## 🐛 Troubleshooting

### Slow Queries Not Showing?

**PostgreSQL:**
```sql
-- Enable pg_stat_statements extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Check if enabled
SELECT * FROM pg_available_extensions WHERE name = 'pg_stat_statements';
```

**MySQL:**
```sql
-- Enable slow query log
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;
```

### Indexes Not Being Used?
```sql
-- Check if table statistics are up to date
ANALYZE table_name;

-- Force planner to prefer index scans
SET enable_seqscan = OFF;  -- PostgreSQL only, for testing
```

### High Disk Usage?
```sql
-- PostgreSQL: Check for bloat
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 10;

-- Run VACUUM
VACUUM FULL ANALYZE table_name;
```

## 📊 Performance Metrics

### Key Performance Indicators (KPIs)

1. **Query Response Time** - Target: < 100ms for simple queries
2. **Index Hit Ratio** - Target: > 99%
3. **Cache Hit Ratio** - Target: > 95%
4. **Slow Query Count** - Target: < 1% of total queries
5. **Table Bloat** - Target: < 20%

### Monitoring Commands
```sql
-- PostgreSQL: Cache hit ratio
SELECT 
    sum(heap_blks_hit) / (sum(heap_blks_hit) + sum(heap_blks_read)) * 100 
    AS cache_hit_ratio
FROM pg_statio_user_tables;

-- Index hit ratio
SELECT 
    sum(idx_blks_hit) / (sum(idx_blks_hit) + sum(idx_blks_read)) * 100 
    AS index_hit_ratio
FROM pg_statio_user_indexes;
```

## 🎯 Use Cases

### For DBAs
- Daily performance monitoring
- Index maintenance planning
- Capacity planning
- Query optimization reviews

### For Developers
- Query performance analysis
- Index strategy planning
- Code review optimization
- Production troubleshooting

### For DevOps
- Automated monitoring
- Alert configuration
- Performance trending
- Capacity forecasting

## 🤝 Contributing

Feel free to contribute your own optimization examples and scripts!

Areas for contribution:
- Additional database support
- More optimization patterns
- Monitoring enhancements
- Case studies

## 📝 License

MIT License - Free for personal and commercial use

## 👤 Author

Available for freelance database optimization and consulting.

**Specialties:**
- Database performance tuning
- Query optimization
- Index strategy
- PostgreSQL/MySQL administration

## 📞 Support

For questions or issues:
- Check the case studies in `examples/`
- Review troubleshooting section above
- Open an issue on GitHub

## 🔗 Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [MySQL Performance Blog](https://www.percona.com/blog/)
- [Use The Index, Luke!](https://use-the-index-luke.com/)
- [Explain.depesz.com](https://explain.depesz.com/) - EXPLAIN visualizer

## 🚀 Next Steps

1. Run analysis scripts on your database
2. Review slow queries
3. Implement recommended indexes
4. Monitor performance improvements
5. Share your results!

---

**Star this repo if you find it useful!** ⭐
