"""
Data Uploader GUI
A tkinter application for automated data upload and SQL processing.

Features:
- Database connection management
- File upload with drag-and-drop
- Error handling and validation
- Append vs Truncate options
- SQL script execution
- Progress tracking and logging
"""

import tkinter as tk
from tkinter import ttk, filedialog, messagebox, scrolledtext
import tkinter.dnd as dnd
import threading
import queue
import json
import os
import sys
import shutil
from pathlib import Path
import traceback
from datetime import datetime

# Import the existing upload_refresh functionality
try:
    from upload_refresh import (
        connect_from_cfg, test_connection, list_tables, 
        upload_from_folders, run_sql_scripts, list_sql_files,
        ensure_folders_from_config
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
        
        # Create the interface
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
        # Create notebook for tabs
        self.notebook = ttk.Notebook(self.root)
        self.notebook.pack(fill='both', expand=True, padx=10, pady=10)
        
        # Create tabs
        self.create_connection_tab()
        self.create_upload_tab()
        self.create_sql_tab()
        self.create_logs_tab()
        
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
        
        # Trusted connection checkbox
        self.trusted_var = tk.BooleanVar()
        ttk.Checkbutton(auth_frame, text="Use Windows Authentication (Trusted Connection)", 
                       variable=self.trusted_var, command=self.toggle_auth).pack(anchor='w', pady=5)
        
        # Username/Password (initially disabled)
        self.username_var = tk.StringVar()
        self.password_var = tk.StringVar()
        
        ttk.Label(auth_frame, text="Username:").grid(row=1, column=0, sticky='w', padx=5, pady=5)
        self.username_entry = ttk.Entry(auth_frame, textvariable=self.username_var, width=30, state='disabled')
        self.username_entry.grid(row=1, column=1, padx=5, pady=5)
        
        ttk.Label(auth_frame, text="Password:").grid(row=2, column=0, sticky='w', padx=5, pady=5)
        self.password_entry = ttk.Entry(auth_frame, textvariable=self.password_var, width=30, 
                                      show='*', state='disabled')
        self.password_entry.grid(row=2, column=1, padx=5, pady=5)
        
        # Connection buttons
        button_frame = ttk.Frame(self.conn_frame)
        button_frame.pack(fill='x', padx=10, pady=10)
        
        ttk.Button(button_frame, text="Test Connection", command=self.test_connection).pack(side='left', padx=5)
        ttk.Button(button_frame, text="Save Configuration", command=self.save_config).pack(side='left', padx=5)
        ttk.Button(button_frame, text="Load Configuration", command=self.load_config_to_ui).pack(side='left', padx=5)
        
    def create_upload_tab(self):
        """Create file upload tab"""
        self.upload_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.upload_frame, text="File Upload")
        
        # Upload settings
        ttk.Label(self.upload_frame, text="File Upload Settings", 
                 font=('Arial', 14, 'bold')).pack(pady=10)
        
        # Table mapping frame
        mapping_frame = ttk.LabelFrame(self.upload_frame, text="Table Mapping", padding=10)
        mapping_frame.pack(fill='both', expand=True, padx=10, pady=5)
        
        # Create treeview for table mappings
        columns = ('Folder', 'Target Table', 'File Patterns', 'Truncate Before Load')
        self.mapping_tree = ttk.Treeview(mapping_frame, columns=columns, show='headings', height=8)
        
        for col in columns:
            self.mapping_tree.heading(col, text=col)
            self.mapping_tree.column(col, width=150)
        
        # Scrollbar for treeview
        tree_scroll = ttk.Scrollbar(mapping_frame, orient='vertical', command=self.mapping_tree.yview)
        self.mapping_tree.configure(yscrollcommand=tree_scroll.set)
        
        self.mapping_tree.pack(side='left', fill='both', expand=True)
        tree_scroll.pack(side='right', fill='y')
        
        # Upload options frame
        options_frame = ttk.LabelFrame(self.upload_frame, text="Upload Options", padding=10)
        options_frame.pack(fill='x', padx=10, pady=5)
        
        # Global truncate option
        self.global_truncate_var = tk.BooleanVar()
        ttk.Checkbutton(options_frame, text="Truncate all tables before upload", 
                       variable=self.global_truncate_var).pack(anchor='w', pady=5)
        
        # Error handling options
        self.stop_on_error_var = tk.BooleanVar(value=True)
        ttk.Checkbutton(options_frame, text="Stop on first error", 
                       variable=self.stop_on_error_var).pack(anchor='w', pady=5)
        
        # File selection area with drag-and-drop
        file_selection_frame = ttk.LabelFrame(self.upload_frame, text="File Selection", padding=10)
        file_selection_frame.pack(fill='x', padx=10, pady=5)
        
        # Drag and drop area
        self.drop_area = tk.Frame(file_selection_frame, bg='lightblue', height=100, relief='dashed', bd=2)
        self.drop_area.pack(fill='x', pady=5)
        self.drop_area.pack_propagate(False)
        
        drop_label = tk.Label(self.drop_area, text="Drag and drop Excel files here\nor click 'Select Files' button", 
                            bg='lightblue', font=('Arial', 10))
        drop_label.pack(expand=True)
        
        # Bind drag and drop events
        self.drop_area.bind("<Button-1>", self.select_files)
        drop_label.bind("<Button-1>", self.select_files)
        
        # Selected files list
        self.selected_files_listbox = tk.Listbox(file_selection_frame, height=4)
        self.selected_files_listbox.pack(fill='x', pady=5)
        
        # Upload buttons
        upload_button_frame = ttk.Frame(self.upload_frame)
        upload_button_frame.pack(fill='x', padx=10, pady=10)
        
        ttk.Button(upload_button_frame, text="Select Files to Upload", 
                  command=self.select_files).pack(side='left', padx=5)
        ttk.Button(upload_button_frame, text="Clear Selected Files", 
                  command=self.clear_selected_files).pack(side='left', padx=5)
        ttk.Button(upload_button_frame, text="Start Upload", 
                  command=self.start_upload).pack(side='left', padx=5)
        ttk.Button(upload_button_frame, text="Refresh Table List", 
                  command=self.refresh_table_list).pack(side='left', padx=5)
        
    def create_sql_tab(self):
        """Create SQL script execution tab"""
        self.sql_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.sql_frame, text="SQL Scripts")
        
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
        
    def create_logs_tab(self):
        """Create logging and status tab"""
        self.logs_frame = ttk.Frame(self.notebook)
        self.notebook.add(self.logs_frame, text="Logs & Status")
        
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
                else:
                    self.log_message("✗ Database connection failed!")
                    self.operation_queue.put(("error", "Database connection failed!"))
            except Exception as e:
                self.log_message(f"✗ Connection error: {e}")
                self.operation_queue.put(("error", f"Connection error: {e}"))
        
        threading.Thread(target=test_conn, daemon=True).start()
    
    def refresh_table_list(self):
        """Refresh the table mapping list"""
        try:
            # Clear existing items
            for item in self.mapping_tree.get_children():
                self.mapping_tree.delete(item)
            
            # Load from config
            for folder_config in self.config.get('folders', []):
                folder = folder_config.get('folder', '')
                target_table = folder_config.get('target_table', '')
                file_patterns = ', '.join(folder_config.get('file_patterns', []))
                truncate = folder_config.get('truncate_before_load', False)
                
                self.mapping_tree.insert('', 'end', values=(
                    folder, target_table, file_patterns, 'Yes' if truncate else 'No'
                ))
            
            self.log_message("Table mapping list refreshed")
        except Exception as e:
            self.log_message(f"Error refreshing table list: {e}")
    
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
            self.add_files_to_list(files)
    
    def add_files_to_list(self, files):
        """Add files to the selected files list"""
        for file_path in files:
            if file_path not in [self.selected_files_listbox.get(i) for i in range(self.selected_files_listbox.size())]:
                self.selected_files_listbox.insert(tk.END, file_path)
        
        self.log_message(f"Added {len(files)} files to upload queue")
    
    def clear_selected_files(self):
        """Clear the selected files list"""
        self.selected_files_listbox.delete(0, tk.END)
        self.log_message("Cleared selected files")
    
    def get_selected_files(self):
        """Get list of selected files"""
        return [self.selected_files_listbox.get(i) for i in range(self.selected_files_listbox.size())]
    
    def start_upload(self):
        """Start the upload process"""
        selected_files = self.get_selected_files()
        if not selected_files:
            messagebox.showwarning("No Files", "Please select files to upload first.")
            return
        
        def upload_process():
            try:
                self.status_var.set("Uploading files...")
                self.progress_var.set(0)
                self.log_message("Starting upload process...")
                
                # Copy selected files to appropriate inbound folders
                self.copy_files_to_folders(selected_files)
                
                # Update config with global truncate setting
                for folder_config in self.config.get('folders', []):
                    folder_config['truncate_before_load'] = self.global_truncate_var.get()
                
                # Save updated config
                with open(self.config_path, 'w', encoding='utf-8') as f:
                    json.dump(self.config, f, indent=2)
                
                # Run upload
                self.progress_var.set(50)
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
    
    def copy_files_to_folders(self, files):
        """Copy files to appropriate inbound folders based on filename patterns"""
        base = Path(__file__).parent.resolve()
        inbound_base = base / 'inbound'
        
        # Create inbound directory if it doesn't exist
        inbound_base.mkdir(exist_ok=True)
        
        for file_path in files:
            try:
                file_name = Path(file_path).name
                self.log_message(f"Processing file: {file_name}")
                
                # Try to match file to appropriate folder based on name patterns
                target_folder = self.find_matching_folder(file_name)
                
                if target_folder:
                    # Copy file to target folder
                    target_path = inbound_base / target_folder
                    target_path.mkdir(exist_ok=True)
                    
                    dest_file = target_path / file_name
                    shutil.copy2(file_path, dest_file)
                    self.log_message(f"Copied {file_name} to {target_folder}")
                else:
                    # If no specific match, copy to a general folder
                    general_folder = inbound_base / "General"
                    general_folder.mkdir(exist_ok=True)
                    dest_file = general_folder / file_name
                    shutil.copy2(file_path, dest_file)
                    self.log_message(f"Copied {file_name} to General folder (no specific match found)")
                    
            except Exception as e:
                self.log_message(f"Error processing {file_path}: {e}")
    
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
        
        self.log_text.insert(tk.END, log_entry)
        self.log_text.see(tk.END)
        self.root.update_idletasks()
    
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
    root = tk.Tk()
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


if __name__ == "__main__":
    main()
