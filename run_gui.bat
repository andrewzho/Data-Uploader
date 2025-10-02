@echo off
echo Starting Data Uploader GUI...
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo Python is not installed or not in PATH.
    echo Please install Python from https://python.org
    pause
    exit /b 1
)

REM Check if requirements are installed
python -c "import pandas, pyodbc, openpyxl" >nul 2>&1
if errorlevel 1 (
    echo Installing required dependencies...
    pip install -r requirements.txt
    if errorlevel 1 (
        echo Failed to install dependencies.
        pause
        exit /b 1
    )
)

REM Run the GUI
python run_gui.py

pause
