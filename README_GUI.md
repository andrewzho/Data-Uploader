# Data Uploader GUI

A user-friendly tkinter application for automated data upload and SQL processing to SQL Server.

## Features

- **Database Connection Management**: Easy configuration of SQL Server connections
- **File Upload Interface**: Drag-and-drop support for Excel files
- **Smart File Organization**: Automatically categorizes files based on filename patterns
- **Error Handling**: Comprehensive error handling and validation
- **Upload Options**: Choose between append or truncate table operations
- **SQL Script Execution**: Run SQL scripts in sequence with progress tracking
- **Real-time Logging**: Detailed logs and status reporting
- **Progress Tracking**: Visual progress bars and status updates

## Installation

1. Install required dependencies:
```bash
pip install -r requirements.txt
```

2. Run the application:
```bash
python run_gui.py
```

## Usage

### 1. Database Connection
- Go to the "Database Connection" tab
- Configure your SQL Server connection settings
- Test the connection to ensure it's working
- Save your configuration

### 2. File Upload
- Go to the "File Upload" tab
- Drag and drop Excel files into the upload area, or click "Select Files"
- Review the table mappings
- Choose upload options (truncate vs append)
- Click "Start Upload" to begin the process

### 3. SQL Scripts
- Go to the "SQL Scripts" tab
- Select which SQL scripts to run
- Choose whether to upload files before running scripts
- Execute the scripts

### 4. Monitoring
- Use the "Logs & Status" tab to monitor progress
- View detailed logs of all operations
- Save logs for troubleshooting

## File Organization

The application automatically categorizes files based on filename patterns:

- **ActiveInsurance**: Files containing "active" or "insurance"
- **AriaData**: Files containing "aria"
- **AtRisk**: Files containing "atrisk", "at-risk", or "risk"
- **Fractions**: Files containing "fraction"
- **ICD_Crosswalk**: Files containing "icd" or "crosswalk"
- **PatientDOB**: Files containing "patient", "dob", or "birth"
- **PayerCrosswalk**: Files containing "payer" or "crosswalk"
- **ReferralRaw**: Files containing "referral"
- **ResearchPateint**: Files containing "research" or "patient"
- **TransactionsRaw**: Files containing "transaction"

Files that don't match any pattern are placed in a "General" folder.

## Configuration

The application uses the existing `config.json` file for database configuration and table mappings. You can:

- Edit the configuration through the GUI
- Manually edit the `config.json` file
- Use the existing command-line tools alongside the GUI

## Error Handling

The application includes comprehensive error handling:

- Database connection validation
- File format validation
- Upload error recovery
- SQL script execution error handling
- Detailed error logging

## Troubleshooting

1. **Connection Issues**: Check your database settings and network connectivity
2. **File Upload Errors**: Ensure files are in Excel format (.xlsx or .xls)
3. **Permission Issues**: Verify database permissions for the configured user
4. **SQL Script Errors**: Check SQL script syntax and dependencies

## Support

For issues or questions:
1. Check the logs in the "Logs & Status" tab
2. Review the error messages for specific issues
3. Ensure all dependencies are installed correctly
