import pyodbc
from config import DB_CONFIG

class DatabaseConnection:
    """Handles all database connections and operations"""
    
    @staticmethod
    def get_connection():
        """Create and return a database connection"""
        conn_str = (
            f"DRIVER={DB_CONFIG['driver']};"
            f"SERVER={DB_CONFIG['server']};"
            f"DATABASE={DB_CONFIG['database']};"
            f"UID={DB_CONFIG['username']};"
            f"PWD={DB_CONFIG['password']};"
            "TrustServerCertificate=yes;"
        )
        return pyodbc.connect(conn_str)

    @staticmethod
    def execute_query(query, params=None, fetch=True):
        conn = DatabaseConnection.get_connection()
        try:
            cursor = conn.cursor()

            if params:
                cursor.execute(query, params)
            else:
                cursor.execute(query)

            if fetch:
                if cursor.description:
                    columns = [col[0] for col in cursor.description]
                    rows = cursor.fetchall()
                    return columns, rows
                else:
                    return [], []
            else:
                conn.commit()
                return None, None

        except pyodbc.Error as e:
            try:
                conn.rollback()
            except Exception:
                pass
            raise ValueError(f"Database error: {e}") from e

        finally:
            conn.close()
    
    @staticmethod
    def execute_insert_with_id(insert_query, params):
        """Execute INSERT and return the generated ID in same connection"""
        conn = DatabaseConnection.get_connection()
        try:
            cursor = conn.cursor()
            cursor.execute(insert_query, params)
            cursor.execute("SELECT @@IDENTITY")
            row = cursor.fetchone()
            conn.commit()
            
            if row and row[0] is not None:
                return int(row[0])
            else:
                raise ValueError("Failed to retrieve inserted ID")
                
        except pyodbc.Error as e:
            try:
                conn.rollback()
            except Exception:
                pass
            raise ValueError(f"Database error: {e}") from e
        finally:
            conn.close()

    @staticmethod
    def execute_scalar(query, params=()):
        columns, rows = DatabaseConnection.execute_query(query, params)
        return rows[0][0] if rows else None
