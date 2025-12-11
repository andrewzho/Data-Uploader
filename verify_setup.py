#!/usr/bin/env python3
"""
Verification script to check if all dependencies are properly installed
and the project is ready to run.
"""

import sys
import subprocess
from pathlib import Path

def check_package(package_name, import_name=None):
    """Check if a package is installed"""
    if import_name is None:
        import_name = package_name
    
    try:
        __import__(import_name)
        print(f"✓ {package_name:<20} - Installed")
        return True
    except ImportError:
        print(f"✗ {package_name:<20} - NOT installed")
        return False

def check_file(file_path, description):
    """Check if a file exists"""
    path = Path(file_path)
    if path.exists():
        print(f"✓ {description:<30} - Found ({file_path})")
        return True
    else:
        print(f"✗ {description:<30} - NOT found ({file_path})")
        return False

def check_directories():
    """Check if required directories exist"""
    base = Path(__file__).parent
    required_dirs = [
        ('inbound/ActiveInsurance', 'ActiveInsurance folder'),
        ('inbound/AriaData', 'AriaData folder'),
        ('inbound/AtRisk', 'AtRisk folder'),
        ('inbound/Fractions', 'Fractions folder'),
        ('inbound/ICD_Crosswalk', 'ICD_Crosswalk folder'),
        ('inbound/PatientDOB', 'PatientDOB folder'),
        ('inbound/PayerCrosswalk', 'PayerCrosswalk folder'),
        ('inbound/ReferralRaw', 'ReferralRaw folder'),
        ('inbound/ResearchPateint', 'ResearchPateint folder'),
        ('inbound/TransactionsRaw', 'TransactionsRaw folder'),
    ]
    
    print("\n" + "="*60)
    print("Checking directories:")
    print("="*60)
    
    all_exist = True
    for dir_path, description in required_dirs:
        full_path = base / dir_path
        if full_path.exists():
            print(f"✓ {description:<30} - Exists")
        else:
            print(f"⚠ {description:<30} - Missing (will be created on first use)")
    
    return True

def main():
    print("\n" + "="*60)
    print("Data Uploader - Dependency Verification")
    print("="*60)
    
    print("\nChecking Python version:")
    print(f"Python {sys.version.split()[0]}")
    
    if sys.version_info < (3, 7):
        print("✗ Python 3.7 or higher is required!")
        return False
    else:
        print("✓ Python version is compatible")
    
    print("\n" + "="*60)
    print("Checking required packages:")
    print("="*60)
    
    packages = [
        ('pandas', 'pandas'),
        ('pyodbc', 'pyodbc'),
        ('openpyxl', 'openpyxl'),
        ('tkinterdnd2', 'tkinterdnd2'),
    ]
    
    all_installed = True
    for package_name, import_name in packages:
        if not check_package(package_name, import_name):
            all_installed = False
    
    print("\n" + "="*60)
    print("Checking required files:")
    print("="*60)
    
    base = Path(__file__).parent
    files_to_check = [
        ('config.json', 'Configuration file'),
        ('data_uploader_gui.py', 'GUI application'),
        ('upload_refresh.py', 'Upload module'),
        ('requirements.txt', 'Requirements file'),
        ('run_gui.py', 'GUI launcher'),
        ('run_gui.bat', 'Windows batch launcher'),
        ('README_GUI.md', 'README'),
        ('SETUP_INSTRUCTIONS.md', 'Setup instructions'),
    ]
    
    all_files_exist = True
    for file_path, description in files_to_check:
        if not check_file(base / file_path, description):
            all_files_exist = False
    
    # Check directories
    check_directories()
    
    print("\n" + "="*60)
    print("Summary:")
    print("="*60)
    
    if all_installed and all_files_exist:
        print("\n✓ All dependencies are installed!")
        print("✓ All required files are present!")
        print("\nYou can now run the application:")
        print("  Option 1: Double-click 'run_gui.bat'")
        print("  Option 2: Run 'python run_gui.py' in terminal")
        return True
    else:
        print("\n✗ Some dependencies or files are missing!")
        if not all_installed:
            print("\nTo install missing packages, run:")
            print("  pip install -r requirements.txt")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
