# Data Uploader GUI - Setup Instructions

## Quick Start

### Option 1: Windows Batch File (Recommended)
1. Double-click `run_gui.bat`
2. The script will automatically install dependencies and launch the GUI

### Option 2: Manual Python Execution
1. Install dependencies: `pip install -r requirements.txt`
2. Run the GUI: `python run_gui.py`

## What's New

Your existing command-line data processing system has been enhanced with a **user-friendly GUI** that provides:

### 🎯 **Key Features**

1. **Database Connection Management**
   - Easy configuration of SQL Server settings
   - Connection testing and validation
   - Support for both Windows Authentication and SQL Authentication

2. **Smart File Upload**
   - Drag-and-drop interface for Excel files
   - Automatic file categorization based on filename patterns
   - Visual file selection and management

3. **Flexible Upload Options**
   - Choose between append or truncate table operations
   - Global settings for all tables
   - Individual table configuration

4. **SQL Script Execution**
   - Visual selection of SQL scripts to run
   - Option to upload files before running scripts
   - Progress tracking and error handling

5. **Comprehensive Logging**
   - Real-time operation logs
   - Progress bars and status updates
   - Error reporting and troubleshooting

### 🔧 **How It Works**

1. **File Organization**: The GUI automatically categorizes your Excel files based on filename patterns:
   - Files with "active" or "insurance" → ActiveInsurance folder
   - Files with "aria" → AriaData folder
   - Files with "fraction" → Fractions folder
   - And so on...

2. **Upload Process**: 
   - Select your Excel files
   - Choose upload options (truncate vs append)
   - Files are automatically copied to the correct inbound folders
   - Data is uploaded to the corresponding SQL Server tables

3. **SQL Processing**:
   - Run your existing SQL scripts in sequence
   - Option to upload files first, then run scripts
   - Full error handling and progress tracking

### 📁 **File Structure**

```
Data-Uploader/
├── data_uploader_gui.py      # Main GUI application
├── upload_refresh.py         # Your existing command-line tool
├── config.json               # Database configuration
├── requirements.txt          # Python dependencies
├── run_gui.py               # GUI launcher
├── run_gui.bat              # Windows batch launcher
├── README_GUI.md            # Detailed documentation
└── SETUP_INSTRUCTIONS.md   # This file
```

### 🚀 **Getting Started**

1. **First Time Setup**:
   - Run `run_gui.bat` (Windows) or `python run_gui.py`
   - Configure your database connection in the "Database Connection" tab
   - Test the connection to ensure it works

2. **Upload Files**:
   - Go to the "File Upload" tab
   - Drag and drop your Excel files
   - Review the table mappings
   - Click "Start Upload"

3. **Run SQL Scripts**:
   - Go to the "SQL Scripts" tab
   - Select which scripts to run
   - Click "Run Selected Scripts" or "Run All Scripts"

### 🔍 **Monitoring and Troubleshooting**

- Use the "Logs & Status" tab to monitor all operations
- Check the progress bar for upload/script execution status
- Review error messages in the logs for troubleshooting
- Save logs for later analysis

### 💡 **Benefits**

- **No More Command Line**: Users can upload and process data without technical knowledge
- **Error Prevention**: Built-in validation and error handling
- **Visual Feedback**: Progress bars and status updates
- **Flexibility**: Choose which operations to run
- **Logging**: Complete audit trail of all operations

### 🔄 **Backward Compatibility**

Your existing command-line tools (`upload_refresh.py`) continue to work exactly as before. The GUI is an additional interface that uses the same underlying functionality.

### 📞 **Support**

If you encounter any issues:
1. Check the logs in the "Logs & Status" tab
2. Verify your database connection settings
3. Ensure all Excel files are in the correct format (.xlsx or .xls)
4. Review the error messages for specific guidance

The GUI makes your data processing workflow accessible to non-technical users while maintaining all the power and flexibility of your existing system!
