"""
================================================================================
Data Validation and Cleaning Script
================================================================================

PURPOSE:
  This script validates and cleans Excel files before uploading to the database.
  It ensures column names match SQL table expectations and data is properly formatted.

FEATURES:
  - Validates column names against expected schema
  - Performs fuzzy matching for similar column names
  - Identifies missing and extra columns
  - Reports data type issues
  - Generates a detailed validation report

USAGE:
  python validate_and_clean_data.py <file_path> [--table_name TABLE_NAME] [--fix]

EXAMPLES:
  # Validate a file without making changes
  python validate_and_clean_data.py "Active Insurance.xlsx"

  # Validate and fix issues automatically
  python validate_and_clean_data.py "fractions.xlsx" --fix

  # Validate for a specific table
  python validate_and_clean_data.py "data.xlsx" --table_name Fractions

================================================================================
"""

import pandas as pd
import sys
from pathlib import Path
from difflib import SequenceMatcher
from openpyxl import load_workbook

# Expected column mappings for each table
TABLE_SCHEMAS = {
    'ActiveInsurance': [
        'PatientId', 'CompanyName', 'PrimaryFlag'
    ],
    'AriaData': [
        'PatientId', 'Patient_Status', 'Active_Insurance'
    ],
    'AtRisk': [
        'PatientId', 'StatusIcon'
    ],
    'Fractions': [
        'Patient ID1', 'Activity Name', 'Due Date', 'Start Date', 'Duration',
        'Note', 'Status', 'Prim# Oncologist', 'Diagnosis', 'Staff/Resource(s)',
        'Patient Name', 'Check-In', 'Questionnaire', 'Priority', 'Checklist',
        'F1', 'descr', 'Cancer Flag', 'ICD_High_level_Category',
        'ICD_Second_Level', 'ICD_Detailed', 'Start Date Only'
    ],
    'ICD_Crosswalk': [
        'Prefix', 'Latest dx', 'Descr', 'Roll Up - High Level', 'ICD_Second Level'
    ],
    'PatientDOB': [
        'PatientId', 'DateOfBirth'
    ],
    'PayerCrosswalk': [
        'Insurance Product Detail', 'Category - Type', 'InsuranceCatAbv', 'Payer Roll-Up'
    ],
    'ReferralRaw': [
        'Patient ID', 'Patient Name', 'State', 'Referral Date', 'Ref Month',
        'Self-referral Inquiry Date', 'DOB', 'SBRT', 'Prior RT', 'IV Contrast',
        'Primary Insurance', 'Secondary Insurance', 'Insurance Category', 'Disease Site',
        'Anesthesia', 'Referring Hospital', 'Other Hosp Detail', 'Referring Physician',
        'Attending Physician', 'NYPC Clinical Approval', 'Insurance Approval',
        'Final Approval', 'Reason', 'At Risk', 'Treatment Status', 'Trial',
        'Fin Counselor', 'ROI Date', 'Intake Acceptance Date', 'Decision Date',
        'Insurance decision date (For at risk patients)', 'Auth Initiation Date',
        'IRO Submission Date', '1st Appeal Denial Date', '2nd Appeal Denial Date',
        'Peer to Peer Date', 'LMN Date', 'Comparison Sim Date',
        'Comparison Plan Requested Date', 'Comparison Plan Completed Date',
        'Inquiry Source', 'Visit Number', 'TransMRN', 'FirstName', 'RemainingBalance',
        'UpdatedPrimary', 'UpdatedSecondary', 'InsuranceAbv', 'InsuranceCat',
        'Funding Type', 'Treatment', 'Sim', 'Consult', 'Referred Back',
        'Sim Date', '1st Treatment', 'Final Treatment', 'Comment', 'On-Hold',
        'FBR', 'Consult Date', 'MultiPlan', 'ICD 10 verified', 'ICD 10'
    ],
    'ResearchPatient': [
        'PatientId', 'StatusIcon'
    ],
    'TransactionsRaw': [
        'PaymentDateUpdated', 'PaymentDateVoided', 'VoucherDateUpdated', 'VoucherDateVoided',
        'DateRan', 'PracticeCompanyNumber', 'PracticeName', 'DepartmentAbv', 'AccountType',
        'InsuranceAbv', 'InsuranceName', 'PatientNumber', 'PatientNumberUpdated',
        'PatientFullName', 'LastName', 'FirstName', 'MiddleName', 'FromDOS', 'Voucher',
        'BillDate', 'ReBillDate', 'BillingProvider', 'NPI', 'ProcedureCode',
        'ProcedureDescription', 'Modifier', 'DiagnosisCode', 'WorkRVU', 'PERVU', 'MPRVU',
        'Units', 'Charges', 'PersonalPayments', 'InsurancePayments', 'IntlPayments',
        'ContractualAdjustment', 'Refunds', 'Allowed', 'TotalPayments', 'TotalAdjustments',
        'RemainingBalance', 'Charity', 'BalTransFromTiger', 'IntlAdjustment', 'Bankruptcy',
        'PatientBalanceDeemedUncollectible', 'CharityWriteOff', 'IndigentCharity',
        'BundledNCCIEdit', 'ChargeError', 'GlobalPeriodNotBillable',
        'AppealsExhaustedNotMedNecessary', 'ChargesNotReceivedfromSiteTimely',
        'DeceasedPatient', 'FinancialHardship', 'G6017NotCovered', 'MUEMaxUnitsExceeded',
        'NoAuthorizationObtained', 'NoncoveredService', 'NoTransferAgreementInpat',
        'OutofNetwork', 'PromptPayAdjustment', 'SmallBalanceAdjustment',
        'CollectionAgencyPayments', 'CollectionAgencyRefunds', 'CollectionAgencyTransfers',
        'CollectionAgencyAdjustment', 'CollectionAgencyFeeAdjustment', 'CharityAdjs',
        'OtherAdjs', 'InternationalAdjs', 'PatientDirective', 'PayerDirective',
        'PrimaryInsurance', 'SecondaryInsurance', 'VisitNumber', 'TransMRN',
        'PayerRollUp', 'InsuranceCat', 'PatientSubscriberID', 'Date Uploaded'
    ]
}


def fuzzy_match_column(col_name, expected_cols, threshold=0.85):
    """
    Find the best fuzzy match for a column name in the expected columns list.
    Returns (matched_name, ratio) or (None, 0) if no good match found.
    """
    best_match = None
    best_ratio = threshold
    
    for expected in expected_cols:
        ratio = SequenceMatcher(None, col_name.lower(), expected.lower()).ratio()
        if ratio > best_ratio:
            best_ratio = ratio
            best_match = expected
    
    return best_match, best_ratio


def detect_table_from_columns(df_columns, threshold=0.65):
    """
    Detect which table this data is for by matching column names.
    Uses flexible matching (0.65 threshold) similar to SSMS data uploader.
    Returns (table_name, match_score) or (None, 0) if no good match.
    """
    best_table = None
    best_score = 0
    
    for table_name, expected_cols in TABLE_SCHEMAS.items():
        # Count how many columns match with fuzzy matching
        matches = 0
        for col in df_columns:
            fuzzy, ratio = fuzzy_match_column(col, expected_cols, threshold=0.65)
            if ratio >= 0.65:
                matches += 1
        
        match_score = matches / len(expected_cols) if expected_cols else 0
        if match_score > best_score:
            best_score = match_score
            best_table = table_name
    
    return best_table, best_score


def validate_file(file_path, table_name=None, validate_rows=True):
    """
    Validate an Excel file against expected schema.
    
    Args:
        file_path (str): Path to the Excel file
        table_name (str, optional): Table name to validate against. If None, auto-detects.
        validate_rows (bool): If True, only validates first 10 rows for speed. 
                             If False, validates entire file.
    
    Returns:
        dict: Validation results with keys:
            - valid (bool): Whether file passed validation
            - table_name (str): Detected or specified table name
            - issues (list): List of issues found
            - column_mapping (dict): Suggested column name mappings
            - missing_columns (list): Expected columns not in file
            - extra_columns (list): Columns in file not in schema
    """
    print(f"\n{'='*80}")
    print(f"VALIDATING: {Path(file_path).name}")
    print(f"{'='*80}\n")
    
    # Read only first 10 rows for fast validation
    try:
        if validate_rows:
            df = pd.read_excel(file_path, nrows=10)
            print(f"(Validating first 10 rows for speed)")
        else:
            df = pd.read_excel(file_path)
    except Exception as e:
        return {
            'valid': False,
            'table_name': None,
            'issues': [f"ERROR: Could not read file: {str(e)}"],
            'column_mapping': {},
            'missing_columns': [],
            'extra_columns': []
        }
    
    actual_cols = list(df.columns)
    issues = []
    
    # Step 1: Auto-detect or validate table name
    if not table_name:
        detected_table, score = detect_table_from_columns(actual_cols)
        if detected_table and score >= 0.5:
            table_name = detected_table
            print(f"✓ Detected table: {table_name} (match score: {score:.1%})")
        else:
            issues.append(f"Could not auto-detect table. Columns don't match any known schema.")
            return {
                'valid': False,
                'table_name': None,
                'issues': issues,
                'column_mapping': {},
                'missing_columns': [],
                'extra_columns': actual_cols
            }
    else:
        print(f"✓ Using specified table: {table_name}")
    
    # Step 2: Get expected columns for this table
    expected_cols = TABLE_SCHEMAS.get(table_name, [])
    if not expected_cols:
        issues.append(f"Unknown table: {table_name}")
        return {
            'valid': False,
            'table_name': table_name,
            'issues': issues,
            'column_mapping': {},
            'missing_columns': expected_cols,
            'extra_columns': actual_cols
        }
    
    print(f"Expected columns: {len(expected_cols)}")
    print(f"Actual columns:   {len(actual_cols)}\n")
    
    # Step 3: Map actual columns to expected columns
    column_mapping = {}
    matched_cols = set()
    fuzzy_matches = []
    
    for actual_col in actual_cols:
        # Try exact match first (case-insensitive)
        exact_match = None
        for expected_col in expected_cols:
            if actual_col.lower() == expected_col.lower():
                exact_match = expected_col
                break
        
        if exact_match:
            column_mapping[actual_col] = exact_match
            matched_cols.add(exact_match)
        else:
            # Try fuzzy match with lower threshold (0.65) for SSMS-like flexibility
            fuzzy, ratio = fuzzy_match_column(actual_col, expected_cols, threshold=0.65)
            if fuzzy:
                column_mapping[actual_col] = fuzzy
                matched_cols.add(fuzzy)
                fuzzy_matches.append((actual_col, fuzzy, ratio))
            else:
                # No match found
                column_mapping[actual_col] = None
    
    # Step 4: Identify missing and extra columns
    missing_cols = [col for col in expected_cols if col not in matched_cols]
    extra_cols = [col for col in actual_cols if column_mapping.get(col) is None]
    
    # Step 5: Report fuzzy matches
    if fuzzy_matches:
        print("⚠ FUZZY MATCHES (similar column names):")
        for actual, expected, ratio in fuzzy_matches:
            print(f"  '{actual}' → '{expected}' ({ratio:.0%} match)")
        print()
    
    # Step 6: Report missing columns
    if missing_cols:
        print("❌ MISSING COLUMNS (expected but not in file):")
        for col in missing_cols:
            print(f"  - {col}")
        print()
        issues.append(f"Missing {len(missing_cols)} expected columns")
    
    # Step 7: Report extra columns
    if extra_cols:
        print("⚠ EXTRA COLUMNS (in file but not in schema):")
        for col in extra_cols:
            print(f"  - {col}")
        print()
        issues.append(f"Found {len(extra_cols)} unexpected columns")
    
    # Step 8: Check for data quality issues
    print("DATA QUALITY CHECKS:")
    
    # Check for empty rows
    empty_rows = df.isnull().sum(axis=1)
    if (empty_rows == len(actual_cols)).any():
        print(f"  ⚠ Found {(empty_rows == len(actual_cols)).sum()} completely empty rows")
    
    # Check for mostly empty columns
    for col in actual_cols:
        null_pct = df[col].isnull().sum() / len(df)
        if null_pct > 0.8:
            print(f"  ⚠ Column '{col}' is {null_pct:.0%} empty")
    
    # Check data type compatibility
    print(f"  ✓ File has {len(df)} rows")
    print()
    
    # Step 9: Overall validation result
    is_valid = len(missing_cols) == 0 and len(extra_cols) == 0
    
    if is_valid:
        print("✓ VALIDATION PASSED - File is ready for upload!")
    else:
        print("❌ VALIDATION FAILED - Please fix issues before uploading")
    
    print(f"\n{'='*80}\n")
    
    return {
        'valid': is_valid,
        'table_name': table_name,
        'issues': issues,
        'column_mapping': column_mapping,
        'missing_columns': missing_cols,
        'extra_columns': extra_cols,
        'row_count': len(df),
        'dataframe': df
    }


def clean_and_save(file_path, table_name=None, output_path=None):
    """
    Clean a file by renaming columns and removing extra columns.
    Saves the cleaned file to a new location.
    
    Returns:
        bool: True if successful, False otherwise
    """
    # Validate entire file when cleaning (not just first 10 rows)
    results = validate_file(file_path, table_name, validate_rows=False)
    
    if not results['dataframe'] is None:
        df = results['dataframe']
    else:
        print("Cannot clean file - validation failed")
        return False
    
    print("CLEANING FILE...\n")
    
    # Rename columns based on mapping
    rename_dict = {
        actual: expected 
        for actual, expected in results['column_mapping'].items() 
        if expected is not None and actual != expected
    }
    
    if rename_dict:
        print("Renaming columns:")
        for actual, expected in rename_dict.items():
            print(f"  '{actual}' → '{expected}'")
        df = df.rename(columns=rename_dict)
        print()
    
    # Remove extra columns
    if results['extra_columns']:
        print("Removing extra columns:")
        for col in results['extra_columns']:
            print(f"  - {col}")
        df = df.drop(columns=results['extra_columns'], errors='ignore')
        print()
    
    # Add missing columns with NaN values
    if results['missing_columns']:
        print("Adding missing columns with NULL values:")
        for col in results['missing_columns']:
            df[col] = None
            print(f"  + {col}")
        print()
    
    # Reorder columns to match schema
    expected_cols = TABLE_SCHEMAS.get(results['table_name'], [])
    df = df[[col for col in expected_cols if col in df.columns]]
    
    # Save to output file
    if output_path is None:
        file_stem = Path(file_path).stem
        output_path = str(Path(file_path).parent / f"{file_stem}_cleaned.xlsx")
    
    df.to_excel(output_path, index=False)
    print(f"✓ Cleaned file saved to: {output_path}\n")
    
    return True


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("USAGE: python validate_and_clean_data.py <file_path> [--table_name TABLE_NAME] [--fix]")
        print("\nEXAMPLES:")
        print("  python validate_and_clean_data.py 'Active Insurance.xlsx'")
        print("  python validate_and_clean_data.py 'fractions.xlsx' --fix")
        print("  python validate_and_clean_data.py 'data.xlsx' --table_name Fractions")
        sys.exit(1)
    
    file_path = sys.argv[1]
    table_name = None
    fix = False
    
    # Parse optional arguments
    if '--table_name' in sys.argv:
        idx = sys.argv.index('--table_name')
        if idx + 1 < len(sys.argv):
            table_name = sys.argv[idx + 1]
    
    if '--fix' in sys.argv:
        fix = True
    
    # Validate the file (use full file for command-line validation)
    results = validate_file(file_path, table_name, validate_rows=False)
    
    # If requested, clean and save the file
    if fix and results['valid']:
        clean_and_save(file_path, results['table_name'])
    elif fix:
        print("Cannot clean file - please fix validation issues first")
