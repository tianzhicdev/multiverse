import os
from psycopg2 import pool
from typing import Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class DatabaseConnection:
    """
    Singleton class for PostgreSQL database connection.
    Manages a connection pool for efficient database access.
    """
    _instance = None
    _connection_pool = None
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super(DatabaseConnection, cls).__new__(cls)
            cls._instance._initialize_connection_pool()
        return cls._instance
    
    def _initialize_connection_pool(self):
        """Initialize the connection pool with environment credentials."""
        try:
            # Get database credentials from environment variables
            host = os.environ.get("DB_HOST")
            port = os.environ.get("DB_PORT")
            user = os.environ.get("DB_USER")
            password = os.environ.get("DB_PASSWORD")
            database = os.environ.get("DB_DATABASE")
            logger.info(f"host: {host}, port: {port}, user: {user}, password: {len(password)*'*'}, database: {database}")
            
            # Connection parameters
            self._connection_pool = pool.ThreadedConnectionPool(
                minconn=1,
                maxconn=50,
                host=host,
                port=port,
                user=user,
                password=password,
                database=database
            )
            # Verify connection works
            with self.get_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute("SELECT 1")
                    
            print("Database connection pool initialized successfully")
            
        except Exception as e:
            print(f"Error initializing database connection pool: {e}")
            self._connection_pool = None
    
    def get_connection(self):
        """Get a connection from the pool."""
        if self._connection_pool is None:
            self._initialize_connection_pool()
            
        if self._connection_pool is None:
            raise ConnectionError("Failed to establish database connection")
            
        return self._connection_pool.getconn()
    
    def release_connection(self, conn):
        """Return a connection to the pool."""
        if self._connection_pool is not None:
            self._connection_pool.putconn(conn)
    
    def close_all_connections(self):
        """Close all connections in the pool."""
        if self._connection_pool is not None:
            self._connection_pool.closeall()
            self._connection_pool = None


# Convenience functions for accessing the singleton

def get_db_connection():
    """Get a database connection from the singleton pool."""
    return DatabaseConnection().get_connection()

def release_db_connection(conn):
    """Release a connection back to the pool."""
    DatabaseConnection().release_connection(conn)

def execute_query(query, params=None):
    """Execute a query and return results."""
    conn = None
    try:
        conn = get_db_connection()
        with conn.cursor() as cursor:
            cursor.execute(query, params)
            if query.strip().upper().startswith("SELECT"):
                return cursor.fetchall()
            conn.commit()
            return cursor.rowcount
    except Exception as e:
        if conn:
            conn.rollback()
        raise e
    finally:
        if conn:
            release_db_connection(conn)
