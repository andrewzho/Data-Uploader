# Data Uploader - Auto-DB-Refresh

A tkinter GUI application for uploading Excel data to SQL Server with smart file categorization.

## Quick Start

**Windows**: Double-click `run_gui.bat`

**Manual**:
```bash
pip install -r requirements.txt
python run_gui.py
```

## How to Use

1. **Database Connection Tab**: Set up your SQL Server credentials and test the connection
2. **File Upload Tab**: 
   - Select upload mode (Append or Delete)
   - Drag Excel files into the upload area or click "Select Files"
   - Click "Start Upload"
3. **SQL Scripts Tab**: Run SQL scripts if needed
4. **Logs & Status Tab**: Check the status and logs of your uploads

## Upload Modes

- **Append**: Adds data without clearing existing records
- **Delete**: Clears the table then inserts new data (recommended for full refreshes)

## File Organization

Files are automatically sorted by their names:
- **ActiveInsurance** - files with "active" or "insurance"
- **AriaData** - files with "aria"
- **AtRisk** - files with "atrisk", "at-risk", or "risk"
- **Fractions** - files with "fraction"
- **ICD_Crosswalk** - files with "icd" or "crosswalk"
- **PatientDOB** - files with "patient", "dob", or "birth"
- **PayerCrosswalk** - files with "payer" or "crosswalk"
- **ReferralRaw** - files with "referral"
- **ResearchPatient** - files with "research"
- **TransactionsRaw** - files with "transaction"

## Requirements

- Python 3.7+
- SQL Server access
- pandas, pyodbc, openpyxl, tkinterdnd2 (auto-installed)

## Troubleshooting

Run `python verify_setup.py` to check if everything is installed correctly.
