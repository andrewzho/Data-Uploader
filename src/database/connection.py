"""Database connection management for the Data Uploader application."""
import json
from pathlib import Path
from typing import Dict, Any, Optional
from src.utils.exceptions import ConnectionError as ConnError

try:
    import pyodbc
except ImportError:
    pyodbc = None


def connect_from_cfg(dbcfg: dict):
    """
    Create a database connection from configuration dictionary.
    
    Args:
        dbcfg (dict): Database configuration with keys:
            - driver: ODBC driver name (default: 'ODBC Driver 17 for SQL Server')
            - server: Server hostname or IP
            - database: Database name
            - trusted_connection: Use Windows authentication (default: True)
            - username: Username for SQL authentication (if trusted_connection=False)
            - password: Password for SQL authentication (if trusted_connection=False)
    
    Returns:
        pyodbc.Connection: Database connection object
    
    Raises:
        SystemExit: If pyodbc is not installed
        ValueError: If required configuration is missing
        ConnError: If connection fails
    """
    if pyodbc is None:
        raise SystemExit("pyodbc is not installed. Install with: pip install pyodbc")
    
    driver = dbcfg.get('driver', 'ODBC Driver 17 for SQL Server')
    server = dbcfg.get('server')
    database = dbcfg.get('database')
    trusted = dbcfg.get('trusted_connection', True)
    
    if not server or not database:
        raise ValueError('server and database must be set in config db section')
    
    try:
        if trusted:
            conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};Trusted_Connection=yes;"
            return pyodbc.connect(conn_str, autocommit=False)
        else:
            user = dbcfg.get('username')
            pwd = dbcfg.get('password')
            if not user or not pwd:
                raise ValueError('username and password required when trusted_connection is False')
            conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};UID={user};PWD={pwd}"
            return pyodbc.connect(conn_str, autocommit=False)
    except Exception as e:
        raise ConnError(f"Failed to connect to database: {e}")


def test_connection(cfg_path: Path) -> tuple[bool, str]:
    """
    Test database connection and return server information.
    
    Args:
        cfg_path (Path): Path to config.json file
    
    Returns:
        tuple: (success: bool, message: str)
    """
    try:
        cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
        conn = connect_from_cfg(cfg['db'])
    except Exception as e:
        return False, f'Connection failed: {e}'
    
    try:
        cur = conn.cursor()
        cur.execute("SELECT SUSER_SNAME() AS current_login, @@SERVERNAME AS server_name, @@VERSION AS version")
        row = cur.fetchone()
        
        if row:
            try:
                user = row.current_login
                server = row.server_name
                version = row.version.split('\n')[0]
            except Exception:
                user = row[0]
                server = row[1]
                version = str(row[2]).split('\n')[0]
            
            message = f"Connected successfully\nUser: {user}\nServer: {server}\nVersion: {version}"
            
            # Test permissions
            try:
                cur.execute("SELECT COUNT(*) AS table_count FROM INFORMATION_SCHEMA.TABLES")
                rc = cur.fetchone()
                if rc:
                    message += f"\nTables visible: {rc.table_count}"
            except Exception as me:
                message += f"\nWarning: could not query INFORMATION_SCHEMA.TABLES: {me}"
            
            return True, message
        else:
            return False, 'Connected but no info returned'
    finally:
        conn.close()


def get_tables_list(cfg_path: Path) -> list[tuple[str, str, str]]:
    """
    Get list of accessible base tables.
    
    Args:
        cfg_path (Path): Path to config.json file
    
    Returns:
        list: List of tuples (schema, table_name, full_name)
    """
    try:
        cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
        conn = connect_from_cfg(cfg['db'])
    except Exception:
        return []
    
    try:
        cur = conn.cursor()
        cur.execute("SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_SCHEMA, TABLE_NAME")
        rows = cur.fetchall()
        tables = []
        
        for r in rows:
            try:
                schema = r.TABLE_SCHEMA
                table = r.TABLE_NAME
            except Exception:
                schema = r[0]
                table = r[1]
            
            db = cfg.get('db', {}).get('database', '')
            if db:
                full_name = f"[{db}].[{schema}].[{table}]"
            else:
                full_name = f"[{schema}].[{table}]"
            tables.append((schema, table, full_name))
        
        return tables
    finally:
        conn.close()


def get_table_columns(conn, full_table_name: str) -> list[tuple[str, str, Optional[int]]]:
    """
    Get column metadata for a table.
    
    Args:
        conn: Database connection
        full_table_name (str): Fully qualified table name
    
    Returns:
        list: List of tuples (column_name, data_type, max_length)
    """
    from src.database.queries import parse_table_name
    
    db_name, schema, table = parse_table_name(full_table_name)
    cur = conn.cursor()
    
    if db_name:
        query = """
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
            FROM [{db}].INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
            ORDER BY ORDINAL_POSITION
        """.format(db=db_name)
    else:
        query = """
            SELECT COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
            FROM INFORMATION_SCHEMA.COLUMNS
            WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
            ORDER BY ORDINAL_POSITION
        """
    
    cur.execute(query, (schema, table))
    rows = cur.fetchall()
    columns = []
    
    for r in rows:
        try:
            col_name = r.COLUMN_NAME
            data_type = r.DATA_TYPE
            max_len = r.CHARACTER_MAXIMUM_LENGTH
        except Exception:
            col_name = r[0]
            data_type = r[1]
            max_len = r[2]
        columns.append((col_name, data_type, max_len))
    
    return columns
