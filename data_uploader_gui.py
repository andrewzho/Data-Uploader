"""
Data Uploader GUI
A tkinter application for automated data upload and SQL processing.

Features:
- Database connection management
- Direct file upload with drag-and-drop (automatically categorized)
- Multiple upload modes: Append, Delete, Reset
- Error handling and validation
- SQL script execution
- Progress tracking and logging
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import threading
import queue
import json
import os
import sys
import shutil
from pathlib import Path
import traceback
from datetime import datetime

# Try to import tkinterdnd2 for drag-and-drop support
HAS_DND = False
DND_FILES = None
DND_TEXT = None
try:
    from tkinterdnd2 import DND_FILES, DND_TEXT
    # Also need to initialize tkinterdnd2
    HAS_DND = True
except (ImportError, Exception) as e:
    HAS_DND = False
    print(f"Note: Drag-and-drop not available ({e}). You can still click to select files.")

# Import the existing upload_refresh functionality
try:
    from upload_refresh import (
        connect_from_cfg, test_connection, list_tables, get_tables_list,
        upload_from_folders, run_sql_scripts, list_sql_files,
        ensure_folders_from_config, get_table_columns
    )
    import pandas as pd
    import pyodbc
except ImportError as e:
    print(f"Missing dependencies: {e}")
    print("Please install required packages: pip install pandas pyodbc openpyxl")
    sys.exit(1)


class DataUploaderGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("Data Uploader - Automated SQL Server Data Processing")
        self.root.geometry("1000x700")
        self.root.configure(bg='#f0f0f0')
        
        # Configuration
        self.config_path = Path(__file__).parent / 'config.json'
        self.config = self.load_config()
        
        # Threading for long operations
        self.operation_queue = queue.Queue()
        self.check_queue()
        
        # Create the interface (this creates the notebook and all tabs)
        self.create_widgets()
        self.load_config_to_ui()
        
    def load_config(self):
        """Load configuration from config.json"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r', encoding='utf-8') as f:
                    return json.load(f)
            except Exception as e:
                messagebox.showerror("Config Error", f"Failed to load config: {e}")
        return self.get_default_config()
    
    def get_default_config(self):
        """Return default configuration"""
        return {
            "db": {
                "driver": "ODBC Driver 17 for SQL Server",
                "server": "NYPCSQL01",
                "database": "DataCleanup",
                "trusted_connection": True,
                "username": "",
                "password": ""
            },
            "folders": []
        }
    
    def create_widgets(self):
        """Create the main GUI widgets"""
        # Create notebook for tabs FIRST
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill='both', expand=True, padx=10, pady=10)
        
        # Create all tabs (now that notebook exists)
        print("DEBUG: Creating tabs...")
        self.create_connection_tab()
        print("DEBUG: Connection tab created")
        self.create_upload_tab()
        print("DEBUG: Upload tab created")
        self.create_sql_tab()
        print("DEBUG: SQL tab creation attempted")
        self.create_logs_tab()
        print("DEBUG: Logs tab creation attempted")
        print(f"DEBUG: Total tabs in notebook: {self.notebook.index('end')}")
        
    def create_connection_tab(self):
        """Create database connection configuration tab"""
        self.conn_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.conn_frame, text="Database Connection")
        
        # Connection settings
        ttk.Label(self.conn_frame, text="Database Connection Settings", 
                 font=('Arial', 14, 'bold')).pack(pady=10)
        
        # Server settings frame
        server_frame = ttk.LabelFrame(self.conn_frame, text="Server Configuration", padding=10)
        server_frame.pack(fill='x', padx=10, pady=5)
        
        # Server
        ttk.Label(server_frame, text="Server:").grid(row=0, column=0, sticky='w', padx=5, pady=5)
        self.server_var = tk.StringVar()
        ttk.Entry(server_frame, textvariable=self.server_var, width=30).grid(row=0, column=1, padx=5, pady=5)
        
        # Database
        ttk.Label(server_frame, text="Database:").grid(row=1, column=0, sticky='w', padx=5, pady=5)
        self.database_var = tk.StringVar()
        ttk.Entry(server_frame, textvariable=self.database_var, width=30).grid(row=1, column=1, padx=5, pady=5)
        
        # Driver
        ttk.Label(server_frame, text="Driver:").grid(row=2, column=0, sticky='w', padx=5, pady=5)
        self.driver_var = tk.StringVar()
        driver_combo = ttk.Combobox(server_frame, textvariable=self.driver_var, width=27)
        driver_combo['values'] = [
            "ODBC Driver 17 for SQL Server",
            "ODBC Driver 13 for SQL Server",
            "SQL Server"
        ]
        driver_combo.grid(row=2, column=1, padx=5, pady=5)
        
        # Authentication frame
        auth_frame = ttk.LabelFrame(self.conn_frame, text="Authentication", padding=10)
        auth_frame.pack(fill='x', padx=10, pady=5)

        # Create inner frame for grid layout
        auth_grid = ttk.Frame(auth_frame)
        auth_grid.pack(fill='x', padx=5, pady=5)
        
        # Trusted connection checkbox
        self.trusted_var = tk.BooleanVar()
        ttk.Checkbutton(auth_grid, text="Use Windows Authentication (Trusted Connection)", 
                       variable=self.trusted_var, command=self.toggle_auth).grid(row=0, column=0, columnspan=2, sticky='w', pady=5)
        
        # Username/Password (initially disabled)
        self.username_var = tk.StringVar()
        self.password_var = tk.StringVar()
        
        ttk.Label(auth_grid, text="Username:").grid(row=1, column=0, sticky='w', padx=5, pady=5)
        self.username_entry = ttk.Entry(auth_grid, textvariable=self.username_var, width=30, state='disabled')
        self.username_entry.grid(row=1, column=1, padx=5, pady=5)
        
        ttk.Label(auth_grid, text="Password:").grid(row=2, column=0, sticky='w', padx=5, pady=5)
        self.password_entry = ttk.Entry(auth_grid, textvariable=self.password_var, width=30, 
                                      show='*', state='disabled')
        self.password_entry.grid(row=2, column=1, padx=5, pady=5)
        
        # Connection buttons
        button_frame = ttk.Frame(self.conn_frame)
        button_frame.pack(fill='x', padx=10, pady=10)
        
        ttk.Button(button_frame, text="Test Connection", command=self.test_connection).pack(side='left', padx=5)
        ttk.Button(button_frame, text="Browse Tables", command=self.browse_tables).pack(side='left', padx=5)
        ttk.Button(button_frame, text="Save Configuration", command=self.save_config).pack(side='left', padx=5)
        ttk.Button(button_frame, text="Load Configuration", command=self.load_config_to_ui).pack(side='left', padx=5)
        
        # Table browser frame
        browser_frame = ttk.LabelFrame(self.conn_frame, text="Available Tables", padding=10)
        browser_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Table list with scrollbar
        table_list_frame = ttk.Frame(browser_frame)
        table_list_frame.pack(fill='both', expand=True)
        
        self.table_listbox = tk.Listbox(table_list_frame, height=10)
        table_scroll = ttk.Scrollbar(table_list_frame, orient='vertical', command=self.table_listbox.yview)
        self.table_listbox.configure(yscrollcommand=table_scroll.set)
        
        self.table_listbox.pack(side='left', fill='both', expand=True)
        table_scroll.pack(side='right', fill='y')
        
        # Selected table display
        self.selected_table_var = tk.StringVar(value="No table selected")
        ttk.Label(browser_frame, text="Selected Table:", font=('Arial', 9, 'bold')).pack(anchor='w', pady=(5, 2))
        ttk.Label(browser_frame, textvariable=self.selected_table_var, font=('Arial', 9), 
                 foreground='blue').pack(anchor='w', pady=(0, 5))
        
        # Bind double-click to select table
        self.table_listbox.bind('<Double-Button-1>', self.on_table_select)
        
    def create_upload_tab(self):
        """Create file upload tab"""
        self.upload_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.upload_frame, text="File Upload")
        
        # Title
        title_frame = ttk.Frame(self.upload_frame)
        title_frame.pack(fill='x', padx=10, pady=10)
        ttk.Label(title_frame, text="Upload Data to Tables", 
                 font=('Arial', 14, 'bold')).pack(anchor='w')
        ttk.Label(title_frame, text="Select a table, drop your files, validate, then upload.", 
                 font=('Arial', 9), foreground='gray').pack(anchor='w')
        
        # Quick table selection frame
        quick_select_frame = ttk.LabelFrame(self.upload_frame, text="Quick Table Selection", padding=10)
        quick_select_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Label(quick_select_frame, text="Target Table:").pack(side='left', padx=5)
        self.quick_table_var = tk.StringVar()
        self.quick_table_combo = ttk.Combobox(quick_select_frame, textvariable=self.quick_table_var, 
                                             width=50, state='readonly')
        self.quick_table_combo.pack(side='left', padx=5, fill='x', expand=True)
        self.quick_table_combo.bind('<<ComboboxSelected>>', self.on_quick_table_select)
        
        ttk.Button(quick_select_frame, text="Refresh Tables", 
                  command=self.refresh_quick_tables).pack(side='left', padx=5)
        
        # File drop zone
        drop_zone_frame = ttk.LabelFrame(self.upload_frame, text="Drop Files Here", padding=10)
        drop_zone_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        self.drop_zone = tk.Label(drop_zone_frame, text="Drag and drop Excel files here\nor click to select files", 
                                  font=('Arial', 12), bg='#f0f0f0', relief='sunken', 
                                  borderwidth=2, padx=20, pady=40)
        self.drop_zone.pack(fill='both', expand=True)
        
        # Enable drag and drop if available (with error handling)
        if HAS_DND:
            try:
                self.drop_zone.drop_target_register(DND_FILES)
                self.drop_zone.dnd_bind('<<Drop>>', self.on_file_drop)
            except Exception as e:
                print(f"Warning: Could not enable drag-and-drop: {e}")
                print("You can still click to select files")
        
        self.drop_zone.bind('<Button-1>', self.select_files_for_table)
        
        # Selected files display
        files_frame = ttk.LabelFrame(self.upload_frame, text="Selected Files", padding=10)
        files_frame.pack(fill='x', padx=10, pady=5)
        
        self.selected_files_listbox = tk.Listbox(files_frame, height=4)
        files_scroll = ttk.Scrollbar(files_frame, orient='vertical', command=self.selected_files_listbox.yview)
        self.selected_files_listbox.configure(yscrollcommand=files_scroll.set)
        
        self.selected_files_listbox.pack(side='left', fill='both', expand=True)
        files_scroll.pack(side='right', fill='y')
        
        # Store current table and files
        self.current_upload_table = None
        self.current_upload_files = []
        
        # Upload mode selection
        mode_frame = ttk.LabelFrame(self.upload_frame, text="Upload Mode", padding=10)
        mode_frame.pack(fill='x', padx=10, pady=5)
        
        self.upload_mode_var = tk.StringVar(value='delete')
        ttk.Radiobutton(mode_frame, text="Delete existing data, then insert new data", 
                       variable=self.upload_mode_var, value='delete').pack(anchor='w', padx=5)
        ttk.Radiobutton(mode_frame, text="Append new data to existing data", 
                       variable=self.upload_mode_var, value='append').pack(anchor='w', padx=5)
        
        # Action buttons
        action_frame = ttk.Frame(self.upload_frame)
        action_frame.pack(fill='x', padx=10, pady=10)
        
        ttk.Button(action_frame, text="Validate Files", 
                  command=self.validate_current_files).pack(side='left', padx=5)
        ttk.Button(action_frame, text="Clear Selection", 
                  command=self.clear_file_selection).pack(side='left', padx=5)
        ttk.Button(action_frame, text="Upload to Database", 
                  command=self.upload_current_files).pack(side='left', padx=5)
        
        # Keep old table configs for backward compatibility (used by refresh_table_list)
        self.table_configs = {}
        self.mapping_canvas = None
        self.mapping_scrollable_frame = None
        
    def create_sql_tab(self):
        """Create SQL script execution tab"""
        try:
            self.sql_frame = ttk.Frame(self.notebook)
            self.notebook.add(self.sql_frame, text="SQL Scripts")
            print("DEBUG: SQL Scripts tab created and added to notebook")
            
            ttk.Label(self.sql_frame, text="SQL Script Execution", 
                     font=('Arial', 14, 'bold')).pack(pady=10)
            
            # SQL files list
            sql_list_frame = ttk.LabelFrame(self.sql_frame, text="Available SQL Scripts", padding=10)
            sql_list_frame.pack(fill='both', expand=True, padx=10, pady=5)
            
            self.sql_listbox = tk.Listbox(sql_list_frame, height=8)
            sql_scroll = ttk.Scrollbar(sql_list_frame, orient='vertical', command=self.sql_listbox.yview)
            self.sql_listbox.configure(yscrollcommand=sql_scroll.set)
            
            self.sql_listbox.pack(side='left', fill='both', expand=True)
            sql_scroll.pack(side='right', fill='y')
            
            # SQL options
            sql_options_frame = ttk.LabelFrame(self.sql_frame, text="Execution Options", padding=10)
            sql_options_frame.pack(fill='x', padx=10, pady=5)
            
            self.upload_before_sql_var = tk.BooleanVar(value=True)
            ttk.Checkbutton(sql_options_frame, text="Upload files before running SQL scripts", 
                           variable=self.upload_before_sql_var).pack(anchor='w', pady=5)
            
            # SQL buttons
            sql_button_frame = ttk.Frame(self.sql_frame)
            sql_button_frame.pack(fill='x', padx=10, pady=10)
            
            ttk.Button(sql_button_frame, text="Refresh SQL List", 
                      command=self.refresh_sql_list).pack(side='left', padx=5)
            ttk.Button(sql_button_frame, text="Run Selected Scripts", 
                      command=self.run_selected_sql).pack(side='left', padx=5)
            ttk.Button(sql_button_frame, text="Run All Scripts", 
                      command=self.run_all_sql).pack(side='left', padx=5)
        except Exception as e:
            # If SQL tab creation fails, log it but don't crash
            print(f"Error creating SQL tab: {e}")
            import traceback
            traceback.print_exc()
            # Create a minimal SQL tab so the app doesn't break
            self.sql_frame = ttk.Frame(self.notebook)
            self.notebook.add(self.sql_frame, text="SQL Scripts (Error)")
            ttk.Label(self.sql_frame, text=f"Error loading SQL Scripts tab: {e}", 
                     foreground='red').pack(pady=20)
        
    def create_logs_tab(self):
        """Create logging and status tab"""
        try:
            self.logs_frame = ttk.Frame(self.notebook)
            self.notebook.add(self.logs_frame, text="Logs & Status")
            print("DEBUG: Logs & Status tab created and added to notebook")
        except Exception as e:
            print(f"ERROR creating Logs tab: {e}")
            import traceback
            traceback.print_exc()
            # Create minimal logs tab
            self.logs_frame = ttk.Frame(self.notebook)
            self.notebook.add(self.logs_frame, text="Logs & Status (Error)")
            ttk.Label(self.logs_frame, text=f"Error loading Logs tab: {e}", 
                     foreground='red').pack(pady=20)
        
        ttk.Label(self.logs_frame, text="Operation Logs", 
                 font=('Arial', 14, 'bold')).pack(pady=10)
        
        # Progress bar
        self.progress_var = tk.DoubleVar()
        self.progress_bar = ttk.Progressbar(self.logs_frame, variable=self.progress_var, maximum=100)
        self.progress_bar.pack(fill='x', padx=10, pady=5)
        
        # Status label
        self.status_var = tk.StringVar(value="Ready")
        self.status_label = ttk.Label(self.logs_frame, textvariable=self.status_var, font=('Arial', 10, 'bold'))
        self.status_label.pack(pady=5)
        
        # Log text area
        self.log_text = scrolledtext.ScrolledText(self.logs_frame, height=18, width=80)
        self.log_text.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Log buttons
        log_button_frame = ttk.Frame(self.logs_frame)
        log_button_frame.pack(fill='x', padx=10, pady=5)
        
        ttk.Button(log_button_frame, text="Clear Logs", 
                  command=self.clear_logs).pack(side='left', padx=5)
        ttk.Button(log_button_frame, text="Save Logs", 
                  command=self.save_logs).pack(side='left', padx=5)
        
    def toggle_auth(self):
        """Toggle authentication method"""
        if self.trusted_var.get():
            self.username_entry.config(state='disabled')
            self.password_entry.config(state='disabled')
        else:
            self.username_entry.config(state='normal')
            self.password_entry.config(state='normal')
    
    def load_config_to_ui(self):
        """Load configuration into UI elements"""
        try:
            self.server_var.set(self.config.get('db', {}).get('server', ''))
            self.database_var.set(self.config.get('db', {}).get('database', ''))
            self.driver_var.set(self.config.get('db', {}).get('driver', 'ODBC Driver 17 for SQL Server'))
            self.trusted_var.set(self.config.get('db', {}).get('trusted_connection', True))
            self.username_var.set(self.config.get('db', {}).get('username', ''))
            self.password_var.set(self.config.get('db', {}).get('password', ''))
            
            self.toggle_auth()
            self.refresh_table_list()
            self.refresh_sql_list()
            # Refresh quick tables in upload tab if it exists
            if hasattr(self, 'quick_table_combo'):
                self.refresh_quick_tables()
            self.log_message("Configuration loaded successfully")
        except Exception as e:
            self.log_message(f"Error loading configuration: {e}")
    
    def save_config(self):
        """Save current configuration"""
        try:
            self.config['db'] = {
                'driver': self.driver_var.get(),
                'server': self.server_var.get(),
                'database': self.database_var.get(),
                'trusted_connection': self.trusted_var.get(),
                'username': self.username_var.get() if not self.trusted_var.get() else '',
                'password': self.password_var.get() if not self.trusted_var.get() else ''
            }
            
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.config, f, indent=2)
            
            self.log_message("Configuration saved successfully")
            messagebox.showinfo("Success", "Configuration saved successfully!")
        except Exception as e:
            self.log_message(f"Error saving configuration: {e}")
            messagebox.showerror("Error", f"Failed to save configuration: {e}")
    
    def test_connection(self):
        """Test database connection"""
        def test_conn():
            try:
                self.log_message("Testing database connection...")
                result = test_connection(self.config_path)
                if result == 0:
                    self.log_message("✓ Database connection successful!")
                    self.operation_queue.put(("success", "Database connection successful!"))
                    # Auto-refresh table list on successful connection
                    self.root.after(500, self.browse_tables)
                else:
                    self.log_message("✗ Database connection failed!")
                    self.operation_queue.put(("error", "Database connection failed!"))
            except Exception as e:
                self.log_message(f"✗ Connection error: {e}")
                self.operation_queue.put(("error", f"Connection error: {e}"))
        
        threading.Thread(target=test_conn, daemon=True).start()
    
    def browse_tables(self):
        """Browse and display available tables from the database"""
        def browse():
            try:
                self.log_message("Loading tables from database...")
                tables = get_tables_list(self.config_path)
                if not tables:
                    self.log_message("No tables found or connection failed")
                    self.operation_queue.put(("error", "No tables found. Check connection and permissions."))
                    return
                
                # Update listbox
                self.table_listbox.delete(0, tk.END)
                for schema, table, full_name in tables:
                    display_name = f"{schema}.{table}"
                    self.table_listbox.insert(tk.END, display_name)
                    # Store full_name as item data (we'll use index to retrieve)
                
                # Store tables list for later retrieval
                self.available_tables = tables
                self.log_message(f"Found {len(tables)} table(s)")
                self.operation_queue.put(("success", f"Found {len(tables)} table(s)"))
            except Exception as e:
                self.log_message(f"Error browsing tables: {e}")
                self.operation_queue.put(("error", f"Error browsing tables: {e}"))
        
        threading.Thread(target=browse, daemon=True).start()
    
    def on_table_select(self, event=None):
        """Handle table selection from listbox"""
        selection = self.table_listbox.curselection()
        if not selection:
            return
        
        idx = selection[0]
        if hasattr(self, 'available_tables') and idx < len(self.available_tables):
            schema, table, full_name = self.available_tables[idx]
            self.selected_table_var.set(full_name)
            self.log_message(f"Selected table: {full_name}")
            # Also update quick table selector in upload tab
            if hasattr(self, 'quick_table_combo'):
                self.refresh_quick_tables()
                # Try to set the selection
                try:
                    idx = [t[2] for t in self.available_tables].index(full_name)
                    if idx < len(self.quick_table_combo['values']):
                        self.quick_table_var.set(self.quick_table_combo['values'][idx])
                        self.current_upload_table = full_name
                except:
                    pass
    
    def refresh_quick_tables(self):
        """Refresh the quick table selector in upload tab"""
        def refresh():
            try:
                tables = get_tables_list(self.config_path)
                if tables:
                    table_names = [full_name for _, _, full_name in tables]
                    self.quick_table_combo['values'] = table_names
                    self.available_tables = tables
                    self.log_message(f"Refreshed {len(tables)} table(s) in upload tab")
            except Exception as e:
                self.log_message(f"Error refreshing tables: {e}")
        
        threading.Thread(target=refresh, daemon=True).start()
    
    def on_quick_table_select(self, event=None):
        """Handle quick table selection in upload tab"""
        selected = self.quick_table_var.get()
        if selected:
            self.current_upload_table = selected
            self.log_message(f"Selected table for upload: {selected}")
            self.drop_zone.config(text=f"Table: {selected}\n\nDrag and drop Excel files here\nor click to select files")
    
    def on_file_drop(self, event):
        """Handle file drop event"""
        try:
            files = self.root.tk.splitlist(event.data)
            cleaned_files = []
            for f in files:
                clean_path = f.strip('{}')
                if os.path.isfile(clean_path) and clean_path.lower().endswith(('.xlsx', '.xls')):
                    cleaned_files.append(clean_path)
            
            if cleaned_files:
                self.add_files_to_selection(cleaned_files)
        except Exception as e:
            self.log_message(f"Error processing dropped files: {e}")
            messagebox.showerror("Error", f"Error processing dropped files: {e}")
    
    def select_files_for_table(self, event=None):
        """Select files for the current table"""
        if not self.current_upload_table:
            messagebox.showwarning("No Table Selected", "Please select a table first from the dropdown above.")
            return
        
        files = filedialog.askopenfilenames(
            title=f"Select files for {self.current_upload_table}",
            filetypes=[("Excel files", "*.xlsx *.xls"), ("All files", "*.*")]
        )
        
        if files:
            self.add_files_to_selection(list(files))
    
    def add_files_to_selection(self, files):
        """Add files to the current selection"""
        if not self.current_upload_table:
            messagebox.showwarning("No Table Selected", "Please select a table first.")
            return
        
        for file_path in files:
            if file_path not in self.current_upload_files:
                self.current_upload_files.append(file_path)
                file_name = Path(file_path).name
                self.selected_files_listbox.insert(tk.END, file_name)
                self.log_message(f"Added file: {file_name}")
    
    def clear_file_selection(self):
        """Clear the current file selection"""
        self.current_upload_files.clear()
        self.selected_files_listbox.delete(0, tk.END)
        self.log_message("Cleared file selection")
    
    def validate_current_files(self):
        """Validate the currently selected files against the selected table"""
        if not self.current_upload_table:
            messagebox.showwarning("No Table Selected", "Please select a table first.")
            return
        
        if not self.current_upload_files:
            messagebox.showwarning("No Files Selected", "Please select files to validate.")
            return
        
        def validate():
            try:
                self.log_message(f"\n{'='*80}")
                self.log_message(f"VALIDATING {len(self.current_upload_files)} FILE(S) FOR TABLE: {self.current_upload_table}")
                self.log_message(f"{'='*80}\n")
                
                from validate_and_clean_data import validate_file
                
                all_valid = True
                for file_path in self.current_upload_files:
                    file_name = Path(file_path).name
                    self.log_message(f"Validating: {file_name}...")
                    
                    # Extract table name from full name (e.g., "DataCleanup.dbo.TransactionsRaw" -> "TransactionsRaw")
                    table_parts = self.current_upload_table.split('.')
                    table_name = table_parts[-1].strip('[]')
                    
                    results = validate_file(file_path, table_name)
                    
                    if results['valid']:
                        self.log_message(f"  ✓ {file_name}: PASSED")
                    else:
                        self.log_message(f"  ❌ {file_name}: FAILED")
                        if results['missing_columns']:
                            self.log_message(f"     Missing columns: {', '.join(results['missing_columns'][:5])}")
                        if results['extra_columns']:
                            self.log_message(f"     Extra columns: {', '.join(results['extra_columns'][:5])}")
                        all_valid = False
                
                self.log_message(f"\n{'='*80}")
                if all_valid:
                    self.log_message("✓ ALL FILES VALIDATED SUCCESSFULLY!")
                    self.operation_queue.put(("success", "All files validated successfully!"))
                else:
                    self.log_message("❌ SOME FILES FAILED VALIDATION")
                    self.operation_queue.put(("error", "Some files failed validation. Check logs for details."))
                
            except Exception as e:
                self.log_message(f"Validation error: {e}")
                self.operation_queue.put(("error", f"Validation failed: {e}"))
        
        threading.Thread(target=validate, daemon=True).start()
    
    def upload_current_files(self):
        """Upload the currently selected files to the selected table"""
        if not self.current_upload_table:
            messagebox.showwarning("No Table Selected", "Please select a table first.")
            return
        
        if not self.current_upload_files:
            messagebox.showwarning("No Files Selected", "Please select files to upload.")
            return
        
        def upload():
            try:
                self.status_var.set("Uploading files...")
                self.progress_var.set(0)
                self.log_message(f"\n{'='*80}")
                self.log_message(f"UPLOADING {len(self.current_upload_files)} FILE(S) TO: {self.current_upload_table}")
                self.log_message(f"{'='*80}\n")
                
                # Connect to database
                conn = connect_from_cfg(self.config['db'])
                try:
                    # Get table columns for validation
                    table_cols = get_table_columns(conn, self.current_upload_table)
                    
                    upload_mode = self.upload_mode_var.get()
                    
                    # Process each file
                    for idx, file_path in enumerate(self.current_upload_files):
                        file_name = Path(file_path).name
                        file_size_mb = Path(file_path).stat().st_size / (1024 * 1024)
                        self.log_message(f"Processing {file_name} ({file_size_mb:.1f} MB)...")
                        self.root.update_idletasks()  # Update GUI to show message
                        
                        # Read Excel file with progress feedback
                        # For large files, use engine='openpyxl' with read-only mode for better performance
                        self.log_message(f"  Reading Excel file...")
                        self.root.update_idletasks()
                        try:
                            # Try to use openpyxl engine with read_only mode for large files
                            # This is more memory efficient for large Excel files
                            if file_size_mb > 50:  # For files larger than 50 MB
                                self.log_message(f"  (Using optimized reading mode for large file...)")
                                self.root.update_idletasks()
                            df = pd.read_excel(file_path, engine='openpyxl')
                        except Exception as e:
                            # Fallback to default engine if openpyxl fails
                            self.log_message(f"  (Falling back to default reader...)")
                            self.root.update_idletasks()
                            df = pd.read_excel(file_path)
                        self.log_message(f"  ✓ Loaded {len(df):,} rows, {len(df.columns)} columns")
                        self.root.update_idletasks()
                        
                        # Prepare DataFrame (align columns, coerce types)
                        self.log_message(f"  Preparing data (type conversion, column alignment)...")
                        self.root.update_idletasks()
                        from upload_refresh import prepare_dataframe_for_table
                        df_prepared = prepare_dataframe_for_table(df, table_cols, filename=file_name)
                        self.log_message(f"  ✓ Data preparation complete")
                        self.root.update_idletasks()
                        
                        # Upload to table
                        self.log_message(f"  Starting upload to {self.current_upload_table}...")
                        self.root.update_idletasks()
                        from upload_refresh import upload_df_to_table
                        upload_df_to_table(conn, df_prepared, self.current_upload_table, 
                                         upload_mode=upload_mode, table_cols=table_cols)
                        
                        self.log_message(f"  ✓ Uploaded {len(df_prepared):,} rows from {file_name}")
                        self.progress_var.set((idx + 1) * 100 / len(self.current_upload_files))
                        self.root.update_idletasks()
                    
                    self.log_message(f"\n✓ UPLOAD COMPLETED SUCCESSFULLY!")
                    self.status_var.set("Upload completed!")
                    self.operation_queue.put(("success", f"Successfully uploaded {len(self.current_upload_files)} file(s)!"))
                    
                finally:
                    conn.close()
                    
            except Exception as e:
                # Extract more detailed error information
                error_msg = str(e)
                if hasattr(e, 'args') and len(e.args) > 0:
                    if isinstance(e.args[0], tuple) and len(e.args[0]) >= 2:
                        error_msg = f"{e.args[0][0]}: {e.args[0][1]}"
                    elif isinstance(e.args[0], str):
                        error_msg = e.args[0]
                
                # Log detailed error
                self.log_message(f"✗ Upload failed!")
                self.log_message(f"  Error: {error_msg}")
                self.log_message(f"  Check the console/terminal for detailed error information.")
                self.status_var.set("Upload failed!")
                self.operation_queue.put(("error", f"Upload failed: {error_msg}"))
        
        threading.Thread(target=upload, daemon=True).start()
    
    def refresh_table_list(self):
        """Refresh the table mapping list with pretty interactive controls"""
        try:
            # Skip if the old mapping frame doesn't exist (new UI doesn't use it)
            if not hasattr(self, 'mapping_scrollable_frame') or self.mapping_scrollable_frame is None:
                return
            
            # Clear existing items
            for widget in self.mapping_scrollable_frame.winfo_children():
                widget.destroy()
            
            self.table_configs = {}
            
            # Load from config and create interactive rows
            for idx, folder_config in enumerate(self.config.get('folders', [])):
                folder = folder_config.get('folder', '')
                target_table = folder_config.get('target_table', '')
                
                # Support both old 'truncate_before_load' and new 'upload_mode' formats
                upload_mode = folder_config.get('upload_mode')
                if upload_mode is None:
                    truncate = folder_config.get('truncate_before_load', False)
                    upload_mode = 'delete' if truncate else 'append'
                
                self.table_configs[folder] = {
                    'upload_mode': upload_mode,
                    'file': None,
                    'target_table': target_table,
                    'enabled': tk.BooleanVar(value=True)  # New: Track if this table should be uploaded
                }
                
                # Create row frame with alternating background colors
                bg_color = '#f8f8f8' if idx % 2 == 0 else '#ffffff'
                row_frame = tk.Frame(self.mapping_scrollable_frame, bg=bg_color, relief='flat', borderwidth=0)
                row_frame.pack(fill='x', padx=5, pady=3)
                
                # Left side: Checkbox and folder info
                left_frame = tk.Frame(row_frame, bg=bg_color)
                left_frame.pack(side='left', fill='both', expand=True, padx=8, pady=8)
                
                # Checkbox to enable/disable this table
                checkbox = tk.Checkbutton(left_frame, text="", variable=self.table_configs[folder]['enabled'],
                                         bg=bg_color, activebackground=bg_color, highlightthickness=0)
                checkbox.pack(side='left', padx=(0, 8))
                
                # Info frame with folder and table names
                info_frame = tk.Frame(left_frame, bg=bg_color)
                info_frame.pack(side='left', fill='both', expand=True)
                
                # Folder name in bold
                folder_label = tk.Label(info_frame, text=f"📁 {folder}", 
                                       font=('Arial', 10, 'bold'), bg=bg_color, fg='#333333')
                folder_label.pack(anchor='w', pady=(0, 2))
                
                # Table name in smaller text
                table_label = tk.Label(info_frame, text=f"Table: {target_table}", 
                                      font=('Arial', 8), bg=bg_color, fg='#666666')
                table_label.pack(anchor='w')
                
                # Middle: Upload mode dropdown
                mode_frame = tk.Frame(row_frame, bg=bg_color)
                mode_frame.pack(side='left', padx=10, pady=8)
                
                mode_label = tk.Label(mode_frame, text="Mode:", font=('Arial', 9, 'bold'), 
                                     bg=bg_color, fg='#333333')
                mode_label.pack()
                
                mode_var = tk.StringVar(value=upload_mode)
                mode_dropdown = ttk.Combobox(mode_frame, textvariable=mode_var, 
                                            values=['append', 'delete'], state='readonly', width=10)
                mode_dropdown.pack(pady=(2, 0))
                
                # Store the variable so we can retrieve it later
                mode_dropdown.folder = folder
                mode_dropdown.bind('<<ComboboxSelected>>', 
                                  lambda e, f=folder, v=mode_var: self._update_upload_mode(f, v.get()))
                
                # Right side: File selection button
                button_frame = tk.Frame(row_frame, bg=bg_color)
                button_frame.pack(side='right', padx=12, pady=8)
                
                file_label_var = tk.StringVar(value="No file")
                file_status_label = tk.Label(button_frame, textvariable=file_label_var, 
                                            font=('Arial', 8), bg=bg_color, fg='#999999')
                file_status_label.pack(pady=(0, 3))
                
                def select_file_for_folder(f=folder, label_var=file_label_var):
                    file = filedialog.askopenfilename(
                        title=f"Select file for {f}",
                        filetypes=[("Excel files", "*.xlsx *.xls"), ("All files", "*.*")]
                    )
                    if file:
                        self.table_configs[f]['file'] = file
                        file_name = Path(file).name
                        # Show just the filename, truncate if too long
                        display_name = file_name if len(file_name) <= 20 else file_name[:17] + "..."
                        label_var.set(display_name)
                        self.log_message(f"Selected file for {f}: {file_name}")
                
                select_btn = tk.Button(button_frame, text="📂 Select File", 
                                      command=select_file_for_folder,
                                      bg='#007bff', fg='white', font=('Arial', 8, 'bold'),
                                      padx=10, pady=4, relief='flat', cursor='hand2',
                                      activebackground='#0056b3', activeforeground='white')
                select_btn.pack()
            
            self.log_message("Table mapping list refreshed")
        except Exception as e:
            self.log_message(f"Error refreshing table list: {e}")
    
    def _update_upload_mode(self, folder, mode):
        """Update upload mode for a specific folder"""
        if folder in self.table_configs:
            self.table_configs[folder]['upload_mode'] = mode
            self.log_message(f"Updated upload mode for {folder} to: {mode}")
    
    def _on_mousewheel(self, event):
        """Handle mousewheel scrolling on canvas"""
        if event.num == 5 or event.delta < 0:
            self.mapping_canvas.yview_scroll(1, "units")
        elif event.num == 4 or event.delta > 0:
            self.mapping_canvas.yview_scroll(-1, "units")
    
    # ==================== UPLOAD METHODS ====================

    def refresh_sql_list(self):
        """Refresh the SQL scripts list"""
        try:
            self.sql_listbox.delete(0, tk.END)
            base = Path(__file__).parent.resolve()
            sql_files = list_sql_files(base)
            
            for sql_file in sql_files:
                self.sql_listbox.insert(tk.END, sql_file)
            
            self.log_message(f"Found {len(sql_files)} SQL scripts")
        except Exception as e:
            self.log_message(f"Error refreshing SQL list: {e}")
    
    def select_files(self, event=None):
        """Select files to upload"""
        files = filedialog.askopenfilenames(
            title="Select Excel files to upload",
            filetypes=[("Excel files", "*.xlsx *.xls"), ("All files", "*.*")]
        )
        
        if files:
            self.log_message(f"Selected {len(files)} files")
    
    def drop_files(self, event):
        """Handle drag-and-drop files"""
        try:
            # Parse the dropped files from the event data
            files = self.root.tk.splitlist(event.data)
            
            # Clean up file paths (remove curly braces)
            cleaned_files = []
            for f in files:
                # Remove curly braces and normalize path
                clean_path = f.strip('{}')
                if os.path.isfile(clean_path):
                    cleaned_files.append(clean_path)
            
            if cleaned_files:
                self.log_message(f"Dropped {len(cleaned_files)} files")
        except Exception as e:
            self.log_message(f"Error processing dropped files: {e}")
            messagebox.showerror("Error", f"Error processing dropped files: {e}")
    
    def get_selected_files(self):
        """Get list of selected files from table configs"""
        selected_files = []
        for folder, config in self.table_configs.items():
            if config.get('file'):
                selected_files.append(config['file'])
        return selected_files
    
    def validate_and_fix_selected_files(self):
        """Validate and optionally fix files selected for upload"""
        # Get enabled tables with selected files
        files_to_validate = {}
        for folder, config in self.table_configs.items():
            if config['enabled'].get() and config['file']:
                file_path = config['file']
                if Path(file_path).exists():
                    files_to_validate[folder] = file_path
        
        if not files_to_validate:
            messagebox.showwarning("Warning", "No files selected for validation.\nPlease select files for enabled tables first.")
            return
        
        def validate_process():
            try:
                self.log_message(f"Validating {len(files_to_validate)} file(s)...\n")
                
                from validate_and_clean_data import validate_file
                
                all_valid = True
                validation_results = {}
                
                for folder, file_path in files_to_validate.items():
                    self.log_message(f"Validating {Path(file_path).name} for {folder}...")
                    # Use the target_table from config
                    table_name = self.table_configs[folder]['target_table']
                    results = validate_file(file_path, table_name)
                    validation_results[folder] = results
                    
                    if results['valid']:
                        self.log_message(f"  ✓ {Path(file_path).name}: PASSED")
                    else:
                        self.log_message(f"  ❌ {Path(file_path).name}: FAILED")
                        if results['missing_columns']:
                            self.log_message(f"     Missing: {', '.join(results['missing_columns'][:3])}...")
                        if results['extra_columns']:
                            self.log_message(f"     Extra: {', '.join(results['extra_columns'][:3])}...")
                        all_valid = False
                
                self.log_message("\n" + "="*80)
                
                if all_valid:
                    self.log_message("✓ ALL FILES VALIDATED SUCCESSFULLY!")
                    self.log_message("Files are ready for upload.\n")
                    messagebox.showinfo("Validation Success", 
                        f"All {len(files_to_validate)} file(s) validated successfully!\n\nReady for upload.")
                else:
                    self.log_message("❌ SOME FILES FAILED VALIDATION")
                    self.log_message("Click 'Validate & Fix' again to auto-correct issues.\n")
                    
                    if messagebox.askyesno("Validation Failed", 
                        "Some files have issues.\n\nAuto-fix and create cleaned copies?"):
                        self.fix_selected_files(files_to_validate)
                
            except ImportError:
                self.log_message("Error: validate_and_clean_data module not found")
                messagebox.showerror("Import Error", 
                    "validate_and_clean_data.py not found in the same directory")
            except Exception as e:
                self.log_message(f"Validation error: {e}")
                messagebox.showerror("Error", f"Validation failed: {e}")
        
        threading.Thread(target=validate_process, daemon=True).start()
    
    def fix_selected_files(self, files_to_validate):
        """Auto-fix validation issues in selected files"""
        def fix_process():
            try:
                from validate_and_clean_data import clean_and_save
                
                fixed_files = []
                failed_files = []
                
                for folder, file_path in files_to_validate.items():
                    output_path = str(Path(file_path).parent / f"{Path(file_path).stem}_cleaned.xlsx")
                    
                    self.log_message(f"Fixing {Path(file_path).name}...")
                    
                    try:
                        # Use the target_table from config
                        table_name = self.table_configs[folder]['target_table']
                        if clean_and_save(file_path, table_name, output_path):
                            fixed_files.append(output_path)
                            self.log_message(f"  ✓ Fixed: {output_path}")
                            # Update the file reference to the cleaned file
                            self.table_configs[folder]['file'] = output_path
                        else:
                            failed_files.append(file_path)
                            self.log_message(f"  ❌ Could not fix: {file_path}")
                    except Exception as e:
                        failed_files.append(file_path)
                        self.log_message(f"  ❌ Error fixing {Path(file_path).name}: {e}")
                
                self.log_message("\n" + "="*80)
                
                if fixed_files:
                    self.log_message(f"✓ Fixed {len(fixed_files)} file(s)")
                    self.log_message("Updated file references to cleaned versions.")
                    self.log_message("Ready for upload!\n")
                    messagebox.showinfo("Files Fixed", 
                        f"Successfully fixed {len(fixed_files)} file(s)!\n\nUpdated references point to cleaned files.\nReady for upload.")
                
                if failed_files:
                    self.log_message(f"❌ Could not fix {len(failed_files)} file(s)\n")
                
            except Exception as e:
                self.log_message(f"Fix error: {e}")
                messagebox.showerror("Error", f"Fix process failed: {e}")
        
        threading.Thread(target=fix_process, daemon=True).start()

    def start_upload(self):
        """Start the upload process with per-table configurations"""
        def upload_process():
            try:
                self.status_var.set("Uploading files...")
                self.progress_var.set(0)
                self.log_message("Starting upload process...")
                
                base = Path(__file__).parent.resolve()
                inbound_base = base / 'inbound'
                inbound_base.mkdir(exist_ok=True)
                
                # Process files based on per-table selections and upload modes
                files_uploaded = 0
                
                for folder, config in self.table_configs.items():
                    # Skip if this table is not enabled
                    if not config['enabled'].get():
                        self.log_message(f"Skipping {folder} (unchecked)")
                        continue
                    
                    upload_mode = config['upload_mode']
                    selected_file = config['file']
                    
                    # If a specific file was selected for this table, use it
                    if selected_file and Path(selected_file).exists():
                        # Extract just the folder name from the path (e.g., "ActiveInsurance" from "inbound/ActiveInsurance")
                        folder_name = Path(folder).name
                        target_folder_path = inbound_base / folder_name
                        target_folder_path.mkdir(exist_ok=True)
                        
                        file_name = Path(selected_file).name
                        dest_file = target_folder_path / file_name
                        
                        try:
                            shutil.copy2(selected_file, dest_file)
                            self.log_message(f"Copied {file_name} to {folder} with mode: {upload_mode}")
                            files_uploaded += 1
                        except Exception as e:
                            self.log_message(f"Error copying {file_name}: {e}")
                            if self.stop_on_error_var.get():
                                raise
                
                if files_uploaded == 0:
                    self.log_message("No files selected for upload. Please select a file for at least one enabled table.")
                    self.status_var.set("No files selected")
                    return
                
                # Update config with per-folder upload modes
                for folder_config in self.config.get('folders', []):
                    folder = folder_config.get('folder', '')
                    if folder in self.table_configs:
                        # Clean up old format
                        if 'truncate_before_load' in folder_config:
                            del folder_config['truncate_before_load']
                        # Update with current mode
                        folder_config['upload_mode'] = self.table_configs[folder]['upload_mode']
                
                # Save updated config
                with open(self.config_path, 'w', encoding='utf-8') as f:
                    json.dump(self.config, f, indent=2)
                
                # Run upload
                self.progress_var.set(50)
                self.log_message(f"Running database upload for {files_uploaded} file(s)...")
                upload_from_folders(self.config_path)
                
                self.progress_var.set(100)
                self.status_var.set("Upload completed successfully!")
                self.log_message("✓ Upload process completed successfully!")
                self.operation_queue.put(("success", "Upload completed successfully!"))
                
            except Exception as e:
                self.status_var.set("Upload failed!")
                self.log_message(f"✗ Upload failed: {e}")
                self.operation_queue.put(("error", f"Upload failed: {e}"))
        
        threading.Thread(target=upload_process, daemon=True).start()
    
    def find_matching_folder(self, filename):
        """Find the appropriate folder for a file based on filename patterns"""
        filename_lower = filename.lower()
        
        # Define mapping patterns
        patterns = {
            'ActiveInsurance': ['active', 'insurance'],
            'AriaData': ['aria'],
            'AtRisk': ['atrisk', 'at-risk', 'risk'],
            'Fractions': ['fraction'],
            'ICD_Crosswalk': ['icd', 'crosswalk'],
            'PatientDOB': ['patient', 'dob', 'birth'],
            'PayerCrosswalk': ['payer', 'crosswalk'],
            'ReferralRaw': ['referral'],
            'ResearchPateint': ['research', 'patient'],
            'TransactionsRaw': ['transaction']
        }
        
        for folder_name, keywords in patterns.items():
            if any(keyword in filename_lower for keyword in keywords):
                return folder_name
        return None
    
    def run_selected_sql(self):
        """Run selected SQL scripts"""
        selected = self.sql_listbox.curselection()
        if not selected:
            messagebox.showwarning("No Selection", "Please select SQL scripts to run.")
            return
        
        def run_sql_process():
            try:
                self.log_message("Starting SQL script execution...")
                
                # Get selected files
                base = Path(__file__).parent.resolve()
                sql_files = list_sql_files(base)
                selected_files = [sql_files[i] for i in selected]
                
                # Run upload first if requested
                if self.upload_before_sql_var.get():
                    self.log_message("Uploading files before SQL execution...")
                    upload_from_folders(self.config_path)
                
                # Run SQL scripts
                run_sql_scripts([str(base / f) for f in selected_files], self.config_path)
                self.log_message("✓ SQL scripts executed successfully!")
                self.operation_queue.put(("success", "SQL scripts executed successfully!"))
                
            except Exception as e:
                self.log_message(f"✗ SQL execution failed: {e}")
                self.operation_queue.put(("error", f"SQL execution failed: {e}"))
        
        threading.Thread(target=run_sql_process, daemon=True).start()
    
    def run_all_sql(self):
        """Run all SQL scripts"""
        self.sql_listbox.selection_set(0, tk.END)
        self.run_selected_sql()
    
    def log_message(self, message):
        """Add message to log"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {message}\n"
        
        # Check if log_text widget exists and insert message
        if hasattr(self, 'log_text'):
            self.log_text.insert(tk.END, log_entry)
            self.log_text.see(tk.END)
            self.root.update_idletasks()
        else:
            # Fallback to print if widget not ready
            print(log_entry, end='')
    
    def clear_logs(self):
        """Clear the log text area"""
        self.log_text.delete(1.0, tk.END)
    
    def save_logs(self):
        """Save logs to file"""
        try:
            filename = filedialog.asksaveasfilename(
                defaultextension=".txt",
                filetypes=[("Text files", "*.txt"), ("All files", "*.*")]
            )
            if filename:
                with open(filename, 'w', encoding='utf-8') as f:
                    f.write(self.log_text.get(1.0, tk.END))
                self.log_message("Logs saved successfully")
        except Exception as e:
            self.log_message(f"Error saving logs: {e}")
    
    def check_queue(self):
        """Check for messages from background threads"""
        try:
            while True:
                msg_type, message = self.operation_queue.get_nowait()
                if msg_type == "success":
                    messagebox.showinfo("Success", message)
                elif msg_type == "error":
                    messagebox.showerror("Error", message)
        except queue.Empty:
            pass
        
        # Schedule next check
        self.root.after(100, self.check_queue)


def main():
    """Main function to run the application"""
    # Initialize tkinterdnd2 if available (must be done before creating Tk root)
    if HAS_DND:
        try:
            from tkinterdnd2 import TkinterDnD
            root = TkinterDnD.Tk()  # Use TkinterDnD's Tk instead of regular Tk
        except Exception as e:
            print(f"Warning: Could not initialize drag-and-drop: {e}")
            root = tk.Tk()
    else:
        root = tk.Tk()
    
    try:
        app = DataUploaderGUI(root)
        
        # Set window icon and properties
        try:
            root.iconbitmap('icon.ico')  # Optional icon file
        except:
            pass
        
        # Center the window
        root.update_idletasks()
        x = (root.winfo_screenwidth() // 2) - (root.winfo_width() // 2)
        y = (root.winfo_screenheight() // 2) - (root.winfo_height() // 2)
        root.geometry(f"+{x}+{y}")
        
        root.mainloop()
    except Exception as e:
        print(f"Error starting application: {e}")
        import traceback
        traceback.print_exc()
        input("Press Enter to exit...")


if __name__ == "__main__":
    main()
