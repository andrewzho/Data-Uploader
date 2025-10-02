#!/usr/bin/env python3
"""
Simple launcher for the Data Uploader GUI
"""

import sys
import os
from pathlib import Path

# Add current directory to Python path
current_dir = Path(__file__).parent.resolve()
sys.path.insert(0, str(current_dir))

try:
    from data_uploader_gui import main
    main()
except ImportError as e:
    print(f"Error: {e}")
    print("\nPlease install required dependencies:")
    print("pip install -r requirements.txt")
    input("\nPress Enter to exit...")
except Exception as e:
    print(f"Unexpected error: {e}")
    input("\nPress Enter to exit...")
