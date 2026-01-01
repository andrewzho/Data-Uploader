# Data Uploader - Auto-DB-Refresh

A tkinter GUI application for uploading Excel data to SQL Server with smart file categorization, validation, and automated data refresh workflows.

## Quick Start

**Windows**: Double-click `run_gui.bat`

**Manual**:
```bash
pip install -r requirements.txt
python run_gui.py
```

## Complete Workflow

### 1. Test Connection (Database Connection Tab)
- Enter your SQL Server connection details (server, database, authentication)
- Click **"Test Connection"** to verify connectivity
- Click **"Browse Tables"** to see all available tables in your database
- Double-click any table to select it, or use it in the Upload tab

### 2. Select Table & Drop Files (File Upload Tab)
- Select your target table from the dropdown (click "Refresh Tables" if needed)
- **Drag and drop** Excel files into the drop zone, or **click** to browse and select files
- Selected files will appear in the "Selected Files" list

### 3. Validate Before Upload
- Click **"Validate Files"** to check if your file columns match the table schema
- The system uses fuzzy matching to handle minor column name variations (similar to SSMS)
- Review validation results in the Logs tab
- If validation fails, the system can auto-fix common issues

### 4. Upload Data
- Choose upload mode:
  - **Delete**: Clears existing data, then inserts new data (recommended for full refreshes)
  - **Append**: Adds new data without clearing existing records
- Click **"Upload to Database"** to start the upload
- Monitor progress in the Logs & Status tab

### 5. Run SQL Scripts (SQL Scripts Tab)
- View available SQL scripts in the list
- Select scripts to run (or run all)
- Click **"Run Selected Scripts"** or **"Run All Scripts"**
- Scripts execute in alphabetical/numerical order (e.g., 1 - Script.sql, 2 - Script.sql)

### 6. Run Error Checks (Error Checking Tab)
- After upload and SQL scripts complete, run error checking scripts
- View available error checking scripts in the list
- Select specific checks or run all checks
- Click **"Run Selected Check"** or **"Run All Checks"**
- Review results in the Logs & Status tab

## Features

### Smart Column Matching
- **Fuzzy matching**: Automatically matches similar column names (e.g., "Prim. Oncologist" → "Prim# Oncologist")
- **Type coercion**: Automatically converts data types to match SQL Server table definitions
- **Column alignment**: Adds missing columns with NULL values, removes extra columns

### Validation
- Validates column names against table schema
- Checks data types and formats
- Reports missing and extra columns
- Provides detailed validation reports

### Upload Modes
- **Delete**: Clears the table then inserts new data (uses DELETE for compatibility with foreign keys)
- **Append**: Adds data without clearing existing records

## Free Testing Options

Since you don't have SSMS locally, here are free options for testing:

### Option 1: SQL Server Express (Free)
- Download SQL Server Express from Microsoft (free, unlimited database size)
- Install locally for testing
- Download SQL Server Management Studio (SSMS) separately (also free)

### Option 2: Azure SQL Database (Free Tier)
- Create a free Azure account
- Set up Azure SQL Database (free tier available for 12 months)
- Use Azure Data Studio (free, cross-platform) instead of SSMS

### Option 3: Docker SQL Server (Free)
- Run SQL Server in Docker container (free)
- Perfect for local development/testing
- No installation required, just Docker

### Option 4: Test on Client's System
- All testing can be done on the client's side where SSMS is already set up
- The application doesn't require SSMS to be installed - it uses Python's `pyodbc` library

## Requirements

- Python 3.7+
- SQL Server access (local or remote)
- pandas, pyodbc, openpyxl, tkinterdnd2 (auto-installed via requirements.txt)

## Troubleshooting

- **Connection Issues**: Run `python verify_setup.py` to check if everything is installed correctly
- **Column Mismatches**: Use the validation feature to see detailed column matching information
- **Upload Errors**: Check the Logs tab for detailed error messages
- **File Reading Errors**: Ensure files are not open in Excel when uploading

## Notes

- Column names don't need to match exactly - the system uses fuzzy matching similar to SSMS
- Files are validated before upload to prevent errors
- SQL scripts run in order (numbered scripts: 1, 2, 3, etc.)
- All operations are logged for troubleshooting
