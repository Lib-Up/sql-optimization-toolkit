#!/usr/bin/env python3
"""
Database Performance Monitoring Script
Real-time monitoring of PostgreSQL/MySQL databases
Monitors slow queries and sends alerts when thresholds are exceeded
"""

import psycopg2
import pymysql
import logging
import time
import sys
from datetime import datetime
from typing import List, Dict, Optional

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DatabaseMonitor:
    """Monitor database performance and alert on issues"""
    
    def __init__(self, connection_params: Dict, db_type: str = 'postgresql'):
        """
        Initialize database monitor
        
        Args:
            connection_params: Database connection parameters
            db_type: 'postgresql' or 'mysql'
        """
        self.conn_params = connection_params
        self.db_type = db_type.lower()
        self.slow_query_threshold = 1000  # milliseconds
        self.connection = None
        
    def connect(self) -> bool:
        """Establish database connection"""
        try:
            if self.db_type == 'postgresql':
                self.connection = psycopg2.connect(**self.conn_params)
            elif self.db_type == 'mysql':
                self.connection = pymysql.connect(**self.conn_params)
            else:
                raise ValueError(f"Unsupported database type: {self.db_type}")
            
            logger.info(f"✓ Connected to {self.db_type} database")
            return True
            
        except Exception as e:
            logger.error(f"Failed to connect: {e}")
            return False
    
    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("Database connection closed")
    
    def get_slow_queries_postgresql(self) -> List[Dict]:
        """Fetch currently running slow queries (PostgreSQL)"""
        query = """
        SELECT 
            pid,
            usename,
            datname,
            EXTRACT(EPOCH FROM (now() - query_start)) * 1000 AS duration_ms,
            state,
            wait_event_type,
            wait_event,
            LEFT(query, 200) AS query_preview
        FROM pg_stat_activity
        WHERE state != 'idle'
            AND pid != pg_backend_pid()
            AND now() - query_start > interval '1 second'
        ORDER BY duration_ms DESC;
        """
        
        try:
            with self.connection.cursor() as cur:
                cur.execute(query)
                columns = [desc[0] for desc in cur.description]
                results = cur.fetchall()
                
                slow_queries = []
                for row in results:
                    slow_queries.append(dict(zip(columns, row)))
                
                return slow_queries
                
        except Exception as e:
            logger.error(f"Error fetching slow queries: {e}")
            return []
    
    def get_slow_queries_mysql(self) -> List[Dict]:
        """Fetch currently running slow queries (MySQL)"""
        query = """
        SELECT 
            Id AS pid,
            User AS usename,
            db AS datname,
            Time AS duration_seconds,
            State AS state,
            LEFT(Info, 200) AS query_preview
        FROM information_schema.PROCESSLIST
        WHERE Command != 'Sleep'
            AND Time > 1
            AND Id != CONNECTION_ID()
        ORDER BY Time DESC;
        """
        
        try:
            with self.connection.cursor() as cur:
                cur.execute(query)
                results = cur.fetchall()
                
                slow_queries = []
                for row in results:
                    slow_queries.append({
                        'pid': row[0],
                        'usename': row[1],
                        'datname': row[2],
                        'duration_ms': row[3] * 1000,  # Convert to ms
                        'state': row[4],
                        'query_preview': row[5]
                    })
                
                return slow_queries
                
        except Exception as e:
            logger.error(f"Error fetching slow queries: {e}")
            return []
    
    def get_slow_queries(self) -> List[Dict]:
        """Get slow queries based on database type"""
        if self.db_type == 'postgresql':
            return self.get_slow_queries_postgresql()
        elif self.db_type == 'mysql':
            return self.get_slow_queries_mysql()
        return []
    
    def get_database_stats_postgresql(self) -> Dict:
        """Get overall database statistics (PostgreSQL)"""
        queries = {
            'active_connections': """
                SELECT COUNT(*) FROM pg_stat_activity 
                WHERE state = 'active';
            """,
            'total_connections': """
                SELECT COUNT(*) FROM pg_stat_activity;
            """,
            'database_size': """
                SELECT pg_size_pretty(pg_database_size(current_database()));
            """,
            'cache_hit_ratio': """
                SELECT ROUND(
                    100 * sum(blks_hit) / NULLIF(sum(blks_hit) + sum(blks_read), 0), 2
                ) FROM pg_stat_database WHERE datname = current_database();
            """
        }
        
        stats = {}
        try:
            with self.connection.cursor() as cur:
                for stat_name, query in queries.items():
                    cur.execute(query)
                    result = cur.fetchone()
                    stats[stat_name] = result[0] if result else None
            
            return stats
            
        except Exception as e:
            logger.error(f"Error fetching database stats: {e}")
            return {}
    
    def get_database_stats_mysql(self) -> Dict:
        """Get overall database statistics (MySQL)"""
        queries = {
            'active_connections': """
                SELECT COUNT(*) FROM information_schema.PROCESSLIST 
                WHERE Command != 'Sleep';
            """,
            'total_connections': """
                SELECT COUNT(*) FROM information_schema.PROCESSLIST;
            """,
            'database_size': """
                SELECT CONCAT(ROUND(SUM(data_length + index_length) / 1024 / 1024, 2), ' MB')
                FROM information_schema.TABLES 
                WHERE table_schema = DATABASE();
            """
        }
        
        stats = {}
        try:
            with self.connection.cursor() as cur:
                for stat_name, query in queries.items():
                    cur.execute(query)
                    result = cur.fetchone()
                    stats[stat_name] = result[0] if result else None
            
            return stats
            
        except Exception as e:
            logger.error(f"Error fetching database stats: {e}")
            return {}
    
    def get_database_stats(self) -> Dict:
        """Get database statistics based on type"""
        if self.db_type == 'postgresql':
            return self.get_database_stats_postgresql()
        elif self.db_type == 'mysql':
            return self.get_database_stats_mysql()
        return {}
    
    def send_alert(self, subject: str, message: str):
        """Send alert (placeholder - implement email/slack/etc)"""
        logger.warning(f"ALERT: {subject}")
        logger.warning(f"Message: {message}")
        # TODO: Implement actual alerting (email, Slack, PagerDuty, etc.)
    
    def check_and_alert(self) -> Dict:
        """Check for slow queries and other issues, send alerts if needed"""
        logger.info("=" * 70)
        logger.info("Database Performance Check")
        logger.info("=" * 70)
        logger.info(f"Time: {datetime.now()}")
        logger.info(f"Database: {self.db_type}")
        
        # Get slow queries
        slow_queries = self.get_slow_queries()
        
        if slow_queries:
            logger.warning(f"⚠ Found {len(slow_queries)} slow queries:")
            for i, query in enumerate(slow_queries, 1):
                duration = query.get('duration_ms', 0)
                preview = query.get('query_preview', 'N/A')
                pid = query.get('pid', 'N/A')
                
                logger.warning(f"  {i}. PID {pid}: {duration:.2f}ms")
                logger.warning(f"     Query: {preview[:80]}...")
                
                # Send alert for very slow queries (> 5 seconds)
                if duration > 5000:
                    self.send_alert(
                        f"Very Slow Query Detected (PID {pid})",
                        f"Query running for {duration/1000:.2f}s:\n{preview}"
                    )
        else:
            logger.info("✓ No slow queries detected")
        
        # Get database statistics
        stats = self.get_database_stats()
        
        logger.info("")
        logger.info("Database Statistics:")
        for stat_name, value in stats.items():
            logger.info(f"  {stat_name}: {value}")
        
        # Check for connection issues
        if stats.get('active_connections'):
            active = stats['active_connections']
            if active > 100:  # Threshold for alert
                self.send_alert(
                    "High Active Connection Count",
                    f"Active connections: {active}"
                )
        
        # Check cache hit ratio (PostgreSQL)
        if 'cache_hit_ratio' in stats:
            cache_ratio = stats['cache_hit_ratio']
            if cache_ratio and cache_ratio < 95:
                self.send_alert(
                    "Low Cache Hit Ratio",
                    f"Cache hit ratio: {cache_ratio}% (should be > 95%)"
                )
        
        logger.info("=" * 70)
        logger.info("")
        
        return {
            'slow_queries_count': len(slow_queries),
            'slow_queries': slow_queries,
            'stats': stats
        }
    
    def monitor(self, interval: int = 60, duration: Optional[int] = None):
        """
        Continuously monitor database
        
        Args:
            interval: Check interval in seconds (default: 60)
            duration: Total monitoring duration in seconds (None = infinite)
        """
        logger.info(f"Starting continuous monitoring (interval: {interval}s)")
        
        if not self.connect():
            logger.error("Failed to connect to database")
            return
        
        start_time = time.time()
        check_count = 0
        
        try:
            while True:
                check_count += 1
                logger.info(f"Check #{check_count}")
                
                self.check_and_alert()
                
                # Check if duration limit reached
                if duration and (time.time() - start_time) >= duration:
                    logger.info(f"Monitoring duration limit reached ({duration}s)")
                    break
                
                # Wait for next check
                time.sleep(interval)
                
        except KeyboardInterrupt:
            logger.info("Monitoring stopped by user")
        except Exception as e:
            logger.error(f"Monitoring error: {e}", exc_info=True)
        finally:
            self.disconnect()


def main():
    """Main entry point for command-line usage"""
    
    # Example configuration for PostgreSQL
    pg_config = {
        'host': 'localhost',
        'port': 5432,
        'database': 'postgres',
        'user': 'postgres',
        'password': 'password'  # Change this!
    }
    
    # Example configuration for MySQL
    mysql_config = {
        'host': 'localhost',
        'port': 3306,
        'database': 'mysql',
        'user': 'root',
        'password': 'password'  # Change this!
    }
    
    # Choose database type
    db_type = 'postgresql'  # or 'mysql'
    
    if db_type == 'postgresql':
        config = pg_config
    else:
        config = mysql_config
    
    # Create monitor
    monitor = DatabaseMonitor(config, db_type=db_type)
    
    # Connect and check
    if not monitor.connect():
        sys.exit(1)
    
    try:
        # One-time check
        result = monitor.check_and_alert()
        
        print("\n" + "=" * 70)
        print("Summary:")
        print(f"Slow queries found: {result['slow_queries_count']}")
        print("=" * 70)
        
        # Uncomment to enable continuous monitoring
        # monitor.monitor(interval=60)  # Check every 60 seconds
        
    except Exception as e:
        logger.error(f"Error: {e}", exc_info=True)
        sys.exit(1)
    finally:
        monitor.disconnect()


if __name__ == "__main__":
    # Check if required packages are installed
    try:
        import psycopg2
        import pymysql
    except ImportError as e:
        print(f"Missing required package: {e}")
        print("Install with: pip install psycopg2-binary pymysql")
        sys.exit(1)
    
    main()
