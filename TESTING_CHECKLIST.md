# Test Checklist for Data Uploader

## ✅ Path Fixes Completed

### Files Updated:
1. **src/gui/main_window.py**
   - ✅ Config path: Goes up 3 levels to project root
   - ✅ SQL scripts loading: Uses `sql_scripts/` folder
   - ✅ SQL script execution: Uses correct paths
   - ✅ Inbound folder creation: Uses project root

2. **src/database/upload_operations.py**
   - ✅ Added `get_project_root()` helper function
   - ✅ All path operations use `get_project_root()`
   - ✅ SQL scripts looked up in `sql_scripts/` folder first
   - ✅ Works when called from GUI or standalone

3. **run_gui.py**
   - ✅ Imports from new structure

## Testing Checklist

### 1. Application Startup ✅
- [x] Application launches without errors
- [x] All 4 tabs are visible
- [x] No import errors

### 2. Database Connection Tab
- [ ] Test connection button works
- [ ] Connection successful message appears
- [ ] Table browser populates with tables
- [ ] Double-click table selection works
- [ ] Configuration saves correctly

### 3. File Upload Tab
- [ ] Quick table selector shows tables
- [ ] Selecting table from dropdown works
- [ ] Drag-and-drop files works (if tkinterdnd2 installed)
- [ ] Click to select files works
- [ ] File list displays selected files
- [ ] Clear selection button works
- [ ] Upload mode radio buttons work (Delete/Append)
- [ ] Validate Files button works
  - [ ] Shows validation results in logs
  - [ ] Identifies missing columns
  - [ ] Identifies extra columns
  - [ ] Shows success message when valid
- [ ] Upload to Database button works
  - [ ] Progress bar updates
  - [ ] Status message updates
  - [ ] Chunked processing works for large files
  - [ ] Upload completes successfully
  - [ ] Delete mode clears table first
  - [ ] Append mode adds to existing data
  - [ ] Error handling works properly

### 4. SQL Scripts Tab
- [ ] SQL scripts list populates from `sql_scripts/` folder
- [ ] Shows all 5 SQL files
- [ ] Can select individual scripts
- [ ] Run Selected SQL button works
  - [ ] Executes selected scripts
  - [ ] Shows progress in logs
  - [ ] Shows success/error messages
- [ ] Run All SQL button works
  - [ ] Selects all scripts
  - [ ] Executes all in order
- [ ] Upload before SQL option works (if enabled)

### 5. Logs & Status Tab
- [ ] Log messages appear in text area
- [ ] Timestamps are correct
- [ ] Log auto-scrolls to bottom
- [ ] Progress bar updates during operations
- [ ] Status label shows current operation

### 6. Error Handling
- [ ] Database connection errors show user-friendly messages
- [ ] File not found errors are handled gracefully
- [ ] Invalid data shows validation errors
- [ ] SQL script errors are caught and logged
- [ ] Network errors are handled properly

### 7. File Paths
- [ ] config.json loads from project root
- [ ] SQL scripts load from sql_scripts/
- [ ] Inbound folders created in project root
- [ ] Log files saved to project root (if applicable)

### 8. Data Validation
- [ ] Column name matching works (including fuzzy matching)
- [ ] Data type validation works
- [ ] CSV files with commas in values handled correctly
- [ ] Excel files (.xlsx, .xls) both work
- [ ] CSV files work
- [ ] Large files (>10MB) process without memory issues

### 9. Upload Modes
- [ ] Delete mode: Table cleared before insert
- [ ] Append mode: Data added to existing records
- [ ] Mode selection persists during session
- [ ] Mode correctly applied per table

### 10. Standalone Script Usage
- [ ] Can run `python -m src.database.upload_operations --help`
- [ ] `--test-connection` works
- [ ] `--list-tables` works
- [ ] `--upload` works (if inbound folders have files)
- [ ] `--run-sql` works

## Quick Test Script

```python
# Test imports
from src.gui.main_window import main
from src.database.upload_operations import connect_from_cfg, get_project_root
from src.utils.config import Config
from src.utils.logger import setup_logger
from src.utils.exceptions import DataUploaderException

# Test project root
print(f"Project root: {get_project_root()}")

# Test config loading
config = Config('config.json')
print(f"Database: {config.database.get('database')}")
print(f"Folders: {len(config.folders)}")

print("All imports successful!")
```

## Known Working Features

1. ✅ Import structure works
2. ✅ Path resolution works from new locations
3. ✅ SQL scripts folder detected
4. ✅ Config file loads correctly
5. ✅ No circular imports
6. ✅ Backward compatibility maintained

## If Issues Found

### Connection Issues
- Check config.json has correct server/database
- Verify ODBC Driver 17 for SQL Server is installed
- Check network connectivity
- Verify SQL Server allows connections

### Path Issues
- Verify sql_scripts/ folder exists
- Check config.json is in project root
- Ensure inbound/ folders can be created

### Import Issues
- Run `pip install -r requirements.txt`
- Check Python version (3.7+)
- Verify all dependencies installed

### File Upload Issues
- Check file permissions
- Verify file format (Excel/CSV)
- Check column names match table schema
- Verify table exists in database
