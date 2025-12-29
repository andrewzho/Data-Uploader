"""
upload_refresh.py

Simple uploader + SQL runner for the workspace SQL scripts.
- Creates inbound/<script-folder> for each .sql in cwd (ordered by name)
- Writes a template config.json mapping folder -> target_table (edit before uploading)
- Uploads Excel files (*.xlsx, *.xls) from those folders into the configured table (fast_executemany via pyodbc)

Usage:
  python upload_refresh.py --init         # create folders + config.json
  python upload_refresh.py --upload       # upload files from configured folders
  python upload_refresh.py --run-sql      # execute SQL scripts in order
  python upload_refresh.py --upload --run-sql
  python upload_refresh.py --list-tables   # list accessible base tables via INFORMATION_SCHEMA
  python upload_refresh.py --test-connection  # test DB connection and report server/user info

Dependencies: pandas, pyodbc, openpyxl
Install: pip install pandas pyodbc openpyxl
"""

from pathlib import Path
import os
import json
import argparse
import re
import sys

try:
    import pandas as pd
except Exception:
    pd = None

try:
    import pyodbc
except Exception:
    pyodbc = None

try:
    from difflib import SequenceMatcher
except Exception:
    SequenceMatcher = None


def list_sql_files(base: Path):
    return sorted([p.name for p in base.glob('*.sql')])


def safe_dirname(name: str) -> str:
    return re.sub(r'[\\/*?:"<>|]', '_', name)


def create_inbound_dirs(sql_files, base: Path):
    # Ensure the base inbound directory exists (base is typically project/inbound)
    base.mkdir(parents=True, exist_ok=True)
    folders = []
    for f in sql_files:
        stem = Path(f).stem
        d = base / safe_dirname(stem)
        d.mkdir(parents=True, exist_ok=True)
        # Return relative folder path (relative to project root) so the generated
        # `config.json` is portable across machines. e.g. 'inbound/1 - ScriptName'
        try:
            rel = str(d.relative_to(Path(__file__).parent.resolve()))
        except Exception:
            # Fallback: use a path under 'inbound'
            rel = os.path.join('inbound', safe_dirname(stem))
        folders.append(rel)
    return folders


def write_template_config(sql_files, folders, path: Path):
    cfg = {
        "db": {
            "driver": "ODBC Driver 17 for SQL Server",
            "server": "SERVER_NAME_OR_HOST",
            "database": "NYPCSQL01",
            "trusted_connection": True,
            "username": "",
            "password": ""
        },
        "folders": []
    }
    for sf, fd in zip(sql_files, folders):
        # Ensure folder entries in the template are relative paths where possible
        folder_value = fd
        p = Path(fd)
        if p.is_absolute():
            try:
                folder_value = str(p.relative_to(Path(__file__).parent.resolve()))
            except Exception:
                # leave absolute path if we can't relativize it
                folder_value = fd

        cfg["folders"].append({
            "script": sf,
            "folder": folder_value,
            "target_table": None,
            "file_patterns": ["*.xlsx", "*.xls"],
            "upload_mode": "append"  # options: 'append', 'delete'
        })
    with open(path, 'w', encoding='utf-8') as fh:
        json.dump(cfg, fh, indent=2)
    print(f"Template config written to {path}. Edit target_table entries before uploading.")


def connect_from_cfg(dbcfg: dict):
    if pyodbc is None:
        raise SystemExit("pyodbc is not installed. Install with: pip install pyodbc")
    driver = dbcfg.get('driver', 'ODBC Driver 17 for SQL Server')
    server = dbcfg.get('server')
    database = dbcfg.get('database')
    trusted = dbcfg.get('trusted_connection', True)
    if not server or not database:
        raise ValueError('server and database must be set in config db section')
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


def test_connection(cfg_path: Path):
    """Attempt a DB connection using config and print basic server/user info."""
    cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
    try:
        conn = connect_from_cfg(cfg['db'])
    except Exception as e:
        print('Connection failed:', e)
        return 1
    try:
        cur = conn.cursor()
        # Fetch current login, server name and version
        # use safe alias names (avoid reserved keywords like current_user)
        cur.execute("SELECT SUSER_SNAME() AS current_login, @@SERVERNAME AS server_name, @@VERSION AS version")
        row = cur.fetchone()
        if row:
            print('Connected successfully')
            # access by alias names returned by the query
            try:
                print('Current user:', row.current_login)
                print('Server name :', row.server_name)
                print('Version     :', row.version.split('\n')[0])
            except Exception:
                # fallback to tuple-style indexing if attribute names differ
                print('Current user:', row[0])
                print('Server name :', row[1])
                print('Version     :', str(row[2]).split('\n')[0])
        else:
            print('Connected but no info returned')
        # Optionally try a simple metadata query to ensure permissions
        try:
            cur.execute("SELECT COUNT(*) AS table_count FROM INFORMATION_SCHEMA.TABLES")
            rc = cur.fetchone()
            if rc:
                print('Information schema tables visible:', rc.table_count)
        except Exception as me:
            print('Warning: could not query INFORMATION_SCHEMA.TABLES:', me)
        return 0
    finally:
        conn.close()


def list_tables(cfg_path: Path):
    """List accessible base tables via INFORMATION_SCHEMA.TABLES"""
    cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
    try:
        conn = connect_from_cfg(cfg['db'])
    except Exception as e:
        print('Connection failed:', e)
        return 1
    try:
        cur = conn.cursor()
        cur.execute("SELECT TABLE_SCHEMA, TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_TYPE='BASE TABLE' ORDER BY TABLE_SCHEMA, TABLE_NAME")
        rows = cur.fetchall()
        if not rows:
            print('No base tables found or insufficient permissions.')
            return 0
        print('Accessible tables:')
        for r in rows:
            try:
                print(f"{r.TABLE_SCHEMA}.{r.TABLE_NAME}")
            except Exception:
                # fallback tuple
                print(f"{r[0]}.{r[1]}")
        return 0
    finally:
        conn.close()


def split_sql_batches(sql_text: str):
    # Split on lines that contain only GO (case-insensitive)
    batches = re.split(r'(?im)^\s*GO\s*;?\s*$', sql_text)
    return [b.strip() for b in batches if b.strip()]


def upload_df_to_table(conn, df, table, upload_mode='append', table_cols=None):
    """
    Upload DataFrame to SQL Server table.
    
    upload_mode options:
    - 'append': Add data without clearing existing data
    - 'delete': Delete all existing data, then insert new data (uses DELETE instead of TRUNCATE)
    """
    cursor = conn.cursor()
    cols = list(df.columns)
    if not cols:
        print('No columns found in file, skipping upload to', table)
        return
    
    # Handle table clearing based on upload_mode
    if upload_mode == 'delete':
        try:
            # DELETE is slower but works with foreign keys (can be rolled back)
            cursor.execute(f"DELETE FROM {table}")
        except Exception as e:
            print(f"Warning: Could not delete table data: {e}")
    elif upload_mode == 'truncate':
        # Legacy support for 'truncate' mode
        try:
            cursor.execute(f"TRUNCATE TABLE {table}")
        except Exception as e:
            # Fallback to DELETE if TRUNCATE fails (e.g., due to foreign keys)
            print(f"TRUNCATE failed, attempting DELETE: {e}")
            cursor.execute(f"DELETE FROM {table}")
    # 'append' mode does not clear the table
    
    placeholders = ", ".join("?" for _ in cols)
    col_list = ", ".join(f"[{c}]" for c in cols)
    sql = f"INSERT INTO {table} ({col_list}) VALUES ({placeholders})"
    
    # Convert DataFrame to list of tuples, converting pandas NA/NaN to None for SQL Server
    data = []
    for _, row in df.iterrows():
        row_data = []
        for val in row:
            # Handle pandas NA (from nullable dtypes like Int64, boolean, string)
            if pd.isna(val):
                row_data.append(None)
            else:
                row_data.append(val)
        data.append(tuple(row_data))
    
    cursor.fast_executemany = True
    try:
        cursor.executemany(sql, data)
        conn.commit()
    except Exception as e:
        # If there's a truncation or type error, provide detailed info
        error_msg = str(e)
        print(f"\n===== UPLOAD ERROR =====")
        print(f"Table: {table}")
        print(f"\nExpected columns from SQL Server table:")
        if table_cols:
            for col_name, sql_type, _ in table_cols:
                print(f"  [{col_name}] {sql_type}")
        print(f"\nColumns in DataFrame:")
        for col in cols:
            print(f"  {col}")
        print(f"\nFirst few rows of data:")
        for i, row in enumerate(data[:3]):
            print(f"  Row {i}: {row}")
        print(f"\nSQL Error: {error_msg}")
        print(f"========================\n")
        raise


def resolve_folder_path(folder: str, base: Path) -> Path:
    """
    Intelligently resolve a folder path:
    1. If absolute and exists, use it directly
    2. If relative, try relative to project root first
    3. Try case-insensitive search within project
    4. Extract just the folder name and search within inbound/
    5. Create the folder if it doesn't exist
    
    Returns the resolved Path (created if necessary).
    """
    p = Path(folder)
    
    # If absolute path exists, use it
    if p.is_absolute() and p.exists():
        return p
    
    # If relative, resolve from project root
    if not p.is_absolute():
        resolved = base / folder
        if resolved.exists():
            return resolved
        
        # Get the folder name (last component: "ActiveInsurance" from "inbound/ActiveInsurance")
        folder_name = Path(folder).name
        
        # Try case-insensitive search within inbound/ specifically first
        inbound_dir = base / 'inbound'
        if inbound_dir.exists():
            try:
                for existing_path in inbound_dir.iterdir():
                    if existing_path.is_dir() and existing_path.name.lower() == folder_name.lower():
                        return existing_path
            except Exception:
                pass
        
        # Try case-insensitive search within the entire project
        for existing_path in base.rglob(folder_name):
            if existing_path.is_dir() and existing_path.name.lower() == folder_name.lower():
                return existing_path
        
        # If none found, create the folder at the intended path
        resolved.mkdir(parents=True, exist_ok=True)
        return resolved
    
    # For absolute paths that don't exist, create them
    p.mkdir(parents=True, exist_ok=True)
    return p


def find_files(folder: str, patterns, base: Path = None):
    """Find files matching patterns in folder. Auto-resolves and creates folder if needed."""
    if base is None:
        base = Path(__file__).parent.resolve()
    p = resolve_folder_path(folder, base)
    files = []
    for pat in patterns:
        files.extend(sorted(p.glob(pat)))
    return files


def ensure_folders_from_config(cfg_path: Path, base: Path):
    """Create inbound folders referenced in config.json. If folder is relative, create under base/inbound."""
    cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
    for entry in cfg.get('folders', []):
        folder = entry.get('folder')
        if not folder:
            continue
        p = Path(folder)
        if not p.is_absolute():
            p = base / folder
        p.mkdir(parents=True, exist_ok=True)


def parse_table_name(full_name: str):
    # Accept formats: [db].[schema].[table] or schema.table or table
    parts = [p.strip().strip('[]') for p in re.split(r'\.', full_name) if p.strip()]
    if len(parts) == 3:
        return parts[0], parts[1], parts[2]
    if len(parts) == 2:
        return None, parts[0], parts[1]
    if len(parts) == 1:
        return None, 'dbo', parts[0]
    raise ValueError(f'Unable to parse table name: {full_name}')


def get_table_columns(conn, full_table_name: str):
    db, schema, table = parse_table_name(full_table_name)
    if db:
        prefix = f"[{db}]."
    else:
        prefix = ''
    
    # Query actual column sizes from sys.columns which stores the max_length attribute
    sql = f"""
        SELECT 
            c.name as COLUMN_NAME,
            t.name as DATA_TYPE,
            c.max_length as CHAR_MAX
        FROM {prefix}sys.columns c
        INNER JOIN {prefix}sys.types t ON c.user_type_id = t.user_type_id
        INNER JOIN {prefix}sys.tables tbl ON c.object_id = tbl.object_id
        INNER JOIN {prefix}sys.schemas s ON tbl.schema_id = s.schema_id
        WHERE s.name = ? AND tbl.name = ?
        ORDER BY c.column_id
    """
    cur = conn.cursor()
    cur.execute(sql, (schema, table))
    cols = []
    
    for row in cur.fetchall():
        col_name = row.COLUMN_NAME
        data_type = row.DATA_TYPE
        char_max = row.CHAR_MAX
        
        # sys.columns stores max_length in bytes
        # For nvarchar, max_length is 2 * actual char count, for varchar it's 1:1
        if char_max and char_max > 0:
            if 'nvarchar' in data_type.lower():
                char_max = char_max // 2  # Convert bytes to characters
            elif 'varchar' in data_type.lower() or 'char' in data_type.lower():
                char_max = char_max  # Already in characters
        
        cols.append((col_name, data_type, char_max if char_max and char_max > 0 else None))
    
    return cols


def sql_type_to_coercion(data_type: str):
    t = data_type.lower()
    if t in ('int', 'smallint', 'bigint', 'tinyint'):
        return 'int'
    if t in ('decimal', 'numeric', 'money', 'smallmoney', 'float', 'real'):
        return 'float'
    if t in ('bit',):
        return 'bool'
    if 'char' in t or 'text' in t or 'xml' in t or 'uniqueidentifier' in t:
        return 'str'
    if 'date' in t or 'time' in t or 'datetime' in t or 'smalldatetime' in t:
        return 'datetime'
    # default to string
    return 'str'


def prepare_dataframe_for_table(df: 'pd.DataFrame', table_cols, filename=None):
    """Align and coerce a DataFrame to the target table columns.
    table_cols: list of (colname, data_type, char_max_length)
    Returns the coerced DataFrame ordered to match table_cols.
    Uses fuzzy matching to handle minor spelling variations in column names.
    Truncates string values that exceed column width limits.
    """
    # normalize column names for matching (case-insensitive)
    orig_cols = list(df.columns)
    col_map = {c.lower().strip(): c for c in orig_cols}
    prepared = df.copy()
    prepared.columns = [c.strip() for c in prepared.columns]

    # Fuzzy match function
    def fuzzy_match(expected, available, threshold=0.85):
        """Find best fuzzy match for expected column name in available columns."""
        if SequenceMatcher is None:
            return None
        best_match = None
        best_ratio = threshold
        for avail in available:
            ratio = SequenceMatcher(None, expected.lower(), avail.lower()).ratio()
            if ratio > best_ratio:
                best_ratio = ratio
                best_match = avail
        return best_match

    # Ensure all expected columns exist
    expected_cols = [c for c, _, _ in table_cols]
    missing_cols = []
    extra_cols = []
    
    for exp in expected_cols:
        # try exact case-insensitive match first
        key = exp.lower()
        if key in col_map:
            actual = col_map[key]
            if actual != exp:
                prepared.rename(columns={actual: exp}, inplace=True)
        else:
            # try fuzzy match (e.g., "Prim. Oncologist" -> "Prim# Oncologist")
            fuzzy = fuzzy_match(exp, prepared.columns)
            if fuzzy:
                print(f"Note: Auto-mapping Excel column '{fuzzy}' to expected '{exp}'")
                prepared.rename(columns={fuzzy: exp}, inplace=True)
            else:
                # missing column -> create with NULLs
                missing_cols.append(exp)
                prepared[exp] = None

    # Track unexpected extra columns (those that didn't match anything)
    for c in list(prepared.columns):
        if c.lower() not in [ec.lower() for ec in expected_cols]:
            extra_cols.append(c)

    # Drop unexpected extra columns
    if extra_cols:
        print(f"Warning: dropping extra columns from file {filename or ''}: {extra_cols}")
        prepared.drop(columns=extra_cols, inplace=True)
    
    if missing_cols:
        print(f"Warning: Excel missing columns {missing_cols}, will insert NULLs for file {filename or ''}")

    # Reorder to expected
    prepared = prepared[expected_cols]

    # Coerce types and truncate strings to fit column width
    for col_name, sql_type, char_max_length in table_cols:
        coercion = sql_type_to_coercion(sql_type)
        if coercion == 'int':
            prepared[col_name] = pd.to_numeric(prepared[col_name], errors='coerce').astype('Int64')
        elif coercion == 'float':
            prepared[col_name] = pd.to_numeric(prepared[col_name], errors='coerce').astype('float64')
        elif coercion == 'bool':
            prepared[col_name] = prepared[col_name].map(lambda v: True if v in (1, '1', 'True', 'true', True) else (False if v in (0, '0', 'False', 'false', False) else pd.NA)).astype('boolean')
        elif coercion == 'datetime':
            prepared[col_name] = pd.to_datetime(prepared[col_name], errors='coerce')
        else:
            # String type - convert to string and truncate if needed
            prepared[col_name] = prepared[col_name].astype('string')
            # Truncate strings to fit column width if a limit is defined
            if char_max_length and char_max_length > 0:
                prepared[col_name] = prepared[col_name].apply(
                    lambda x: str(x)[:char_max_length] if pd.notna(x) else None
                )

    return prepared


def validate_and_prepare_files_for_entry(conn, entry, base: Path):
    """Given a config entry, find files in the folder, convert non-Excel to Excel, align columns and coerce types.
    Returns list of tuples (original_path, prepared_df)
    """
    folder = entry.get('folder')
    if not folder:
        return []
    
    # Use the smart path resolver
    fpath = resolve_folder_path(folder, base)
    patterns = entry.get('file_patterns', ['*.xlsx', '*.xls'])
    files = find_files(folder, patterns, base)

    prepared_list = []
    if not files:
        return prepared_list

    # acquire table schema
    ttable = entry.get('target_table')
    if not ttable:
        return prepared_list
    table_cols = get_table_columns(conn, ttable)

    for f in files:
        try:
            # read file (Excel expected)
            if f.suffix.lower() in ('.xls', '.xlsx'):
                try:
                    df = pd.read_excel(f)
                except Exception as e:
                    # Provide a clearer message for common tempfile/permission issues
                    msg = str(e)
                    if isinstance(e, (PermissionError, OSError)) or 'temp' in msg.lower() or 'temporary' in msg.lower():
                        print(f"Error reading Excel file {f}: {e}\n"
                              "This often indicates a problem creating temporary files (permissions, disk space, or OneDrive sync)."
                              " Try freeing disk space, checking permissions on your TEMP directory, or disabling OneDrive sync for this folder.")
                    else:
                        print(f"Error reading Excel file {f}: {e}")
                    continue
            else:
                # attempt to read as CSV and convert to DataFrame
                try:
                    df = pd.read_csv(f)
                except Exception:
                    print(f"Skipping unreadable file {f}")
                    continue

            # prepare DataFrame
            df_prepared = prepare_dataframe_for_table(df, table_cols, filename=str(f.name))
            prepared_list.append((f, df_prepared, table_cols))
        except Exception as e:
            print(f"Error preparing file {f}: {e}")
    return prepared_list


def upload_from_folders(cfg_path: Path):
    if pd is None:
        raise SystemExit('pandas is not installed. Install with: pip install pandas openpyxl')
    cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
    base_dir = Path(__file__).parent.resolve()

    # First scan all configured folders to see if any matching files exist.
    any_files_found = False
    for entry in cfg.get('folders', []):
        folder = entry.get('folder')
        if not folder:
            continue
        patterns = entry.get('file_patterns', ['*.xlsx', '*.xls'])
        files = find_files(folder, patterns, base_dir)
        if files:
            any_files_found = True
            break

    if not any_files_found:
        print('No files found in any configured inbound folders. Skipping upload step.')
        return

    # Proceed to connect and upload only if files were found
    conn = connect_from_cfg(cfg['db'])
    try:
        for entry in cfg.get('folders', []):
            ttable = entry.get('target_table')
            folder = entry.get('folder')
            if not ttable:
                print(f"Skipping folder {folder} (no target_table set).")
                continue
            if not folder:
                print('No folder set for entry, skipping')
                continue

            prepared_files = validate_and_prepare_files_for_entry(conn, entry, base_dir)
            if not prepared_files:
                print(f"No valid files found in {folder}")
                continue
            
            # Determine upload mode from config
            upload_mode = entry.get('upload_mode', 'append')  # default to append for backward compatibility
            
            for orig_path, df, table_cols in prepared_files:
                print(f"Uploading {orig_path} -> {ttable} (mode: {upload_mode})")
                upload_df_to_table(conn, df, ttable, upload_mode=upload_mode, table_cols=table_cols)
                print(f"Uploaded {len(df)} rows from {orig_path.name}")
    finally:
        conn.close()


def run_sql_scripts(seq_files, cfg_path: Path):
    cfg = json.load(open(cfg_path, 'r', encoding='utf-8'))
    conn = connect_from_cfg(cfg['db'])
    try:
        cursor = conn.cursor()
        for sqlfile in seq_files:
            print('Running', sqlfile)
            text = open(sqlfile, 'r', encoding='utf-8-sig').read()
            for batch in split_sql_batches(text):
                cursor.execute(batch)
        conn.commit()
    finally:
        conn.close()


def main():
    base = Path(__file__).parent.resolve()
    inbound = base / 'inbound'
    cfg_path = base / 'config.json'

    p = argparse.ArgumentParser(description='Upload files and run SQL scripts in order')
    p.add_argument('--init', action='store_true', help='Create inbound folders and template config.json')
    p.add_argument('--config', default=str(cfg_path), help='Path to config.json')
    p.add_argument('--upload', action='store_true', help='Upload files from configured folders')
    p.add_argument('--run-sql', action='store_true', help='Execute SQL scripts (in alphabetical/numeric order)')
    p.add_argument('--test-connection', action='store_true', help='Test DB connection and report server/user info')
    p.add_argument('--list-tables', action='store_true', help='List accessible base tables via INFORMATION_SCHEMA')
    args = p.parse_args()

    sql_files = list_sql_files(base)
    if not sql_files:
        print('No .sql files found in current directory.')
        return

    if args.test_connection:
        if not Path(args.config).exists():
            print('config.json not found. Run --init first.')
            return
        rc = test_connection(Path(args.config))
        sys.exit(rc)

    if args.list_tables:
        if not Path(args.config).exists():
            print('config.json not found. Run --init first.')
            return
        rc = list_tables(Path(args.config))
        sys.exit(rc)

    if args.init:
        # Create inbound folders from existing config if present, otherwise create default numbered folders
        if Path(args.config).exists():
            ensure_folders_from_config(Path(args.config), base)
            print('Created inbound folders from config.json')
        else:
            folders = create_inbound_dirs(sql_files, inbound)
            write_template_config(sql_files, folders, Path(args.config))
        return

    if args.upload:
        if not Path(args.config).exists():
            print('config.json not found. Run --init first.')
            return
        upload_from_folders(Path(args.config))

    if args.run_sql:
        # Always attempt to upload files first using the configured folders
        if Path(args.config).exists():
            try:
                print('Uploading files from configured inbound folders before running SQL scripts...')
                ensure_folders_from_config(Path(args.config), base)
                upload_from_folders(Path(args.config))
            except Exception as e:
                print('Warning: upload step failed or skipped:', e)
        run_sql_scripts([str((base / f)) for f in sql_files], Path(args.config))


if __name__ == '__main__':
    main()
