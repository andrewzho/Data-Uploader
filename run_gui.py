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
    from src.gui.main_window import main
    main()
except ImportError as e:
    print(f"Error: {e}")
    print("\nPlease install required dependencies:")
    print("pip install -r requirements.txt")
    input("\nPress Enter to exit...")
except Exception as e:
    print(f"Unexpected error: {e}")
    import traceback
    traceback.print_exc()
    input("\nPress Enter to exit...")
