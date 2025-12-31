"""SQL queries and utilities for the Data Uploader application."""
import re
from typing import Optional, Tuple


def parse_table_name(full_name: str) -> Tuple[Optional[str], str, str]:
    """
    Parse a full table name into database, schema, and table components.
    
    Args:
        full_name (str): Full table name in format [database].[schema].[table] or [schema].[table]
    
    Returns:
        tuple: (database_name or None, schema_name, table_name)
    
    Examples:
        >>> parse_table_name('[MyDB].[dbo].[MyTable]')
        ('MyDB', 'dbo', 'MyTable')
        >>> parse_table_name('[dbo].[MyTable]')
        (None, 'dbo', 'MyTable')
    """
    # Remove brackets and split by period
    parts = re.findall(r'\[([^\]]+)\]', full_name)
    
    if len(parts) == 3:
        return parts[0], parts[1], parts[2]  # database, schema, table
    elif len(parts) == 2:
        return None, parts[0], parts[1]  # schema, table
    elif len(parts) == 1:
        return None, 'dbo', parts[0]  # assume dbo schema
    else:
        raise ValueError(f"Invalid table name format: {full_name}")


def split_sql_batches(sql_text: str) -> list[str]:
    """
    Split SQL script into batches separated by GO statements.
    
    Args:
        sql_text (str): SQL script text
    
    Returns:
        list: List of SQL batch strings
    """
    # Split on lines that contain only GO (case-insensitive)
    batches = re.split(r'(?im)^\s*GO\s*;?\s*$', sql_text)
    return [b.strip() for b in batches if b.strip()]


def sql_type_to_coercion(data_type: str) -> str:
    """
    Map SQL data type to pandas conversion type.
    
    Args:
        data_type (str): SQL data type name
    
    Returns:
        str: Pandas dtype or 'object'
    """
    dt_lower = data_type.lower()
    
    if dt_lower in ('int', 'tinyint', 'smallint', 'bigint'):
        return 'Int64'  # Nullable integer
    elif dt_lower in ('float', 'real', 'decimal', 'numeric', 'money', 'smallmoney'):
        return 'float64'
    elif dt_lower in ('bit',):
        return 'boolean'
    elif dt_lower in ('date', 'datetime', 'datetime2', 'smalldatetime'):
        return 'datetime'
    else:
        return 'object'  # Text types, etc.
