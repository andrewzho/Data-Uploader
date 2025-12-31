"""Configuration management for the Data Uploader application."""
import json
from pathlib import Path
from typing import Dict, List, Any, Optional
from src.utils.exceptions import ConfigError


class Config:
    """Configuration manager for Data Uploader."""
    
    def __init__(self, config_path: str = 'config.json'):
        """
        Initialize configuration manager.
        
        Args:
            config_path (str): Path to configuration JSON file
        """
        self.config_path = Path(config_path)
        self.data = {}
        if self.config_path.exists():
            self.load()
    
    def load(self) -> Dict[str, Any]:
        """
        Load configuration from JSON file.
        
        Returns:
            dict: Configuration data
        
        Raises:
            ConfigError: If config file cannot be loaded
        """
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                self.data = json.load(f)
            return self.data
        except Exception as e:
            raise ConfigError(f"Failed to load config from {self.config_path}: {e}")
    
    def save(self) -> None:
        """
        Save configuration to JSON file.
        
        Raises:
            ConfigError: If config file cannot be saved
        """
        try:
            with open(self.config_path, 'w', encoding='utf-8') as f:
                json.dump(self.data, f, indent=4)
        except Exception as e:
            raise ConfigError(f"Failed to save config to {self.config_path}: {e}")
    
    @property
    def database(self) -> Dict[str, Any]:
        """
        Get database configuration.
        
        Returns:
            dict: Database configuration (server, database, username, etc.)
        """
        return self.data.get('db', {})
    
    @property
    def folders(self) -> List[Dict[str, str]]:
        """
        Get folder mappings.
        
        Returns:
            list: List of folder mappings with 'folder', 'table', 'schema'
        """
        return self.data.get('folders', [])
    
    @property
    def sql_scripts_folder(self) -> str:
        """
        Get SQL scripts folder path.
        
        Returns:
            str: Path to SQL scripts folder
        """
        return self.data.get('sql_scripts_folder', 'sql_scripts')
    
    def get_table_mapping(self, folder_name: str) -> Optional[Dict[str, str]]:
        """
        Get table mapping for a specific folder.
        
        Args:
            folder_name (str): Name of the folder
        
        Returns:
            dict or None: Mapping info or None if not found
        """
        for mapping in self.folders:
            if mapping.get('folder') == folder_name:
                return mapping
        return None
    
    def update_database(self, **kwargs) -> None:
        """
        Update database configuration.
        
        Args:
            **kwargs: Database configuration parameters
        """
        if 'db' not in self.data:
            self.data['db'] = {}
        self.data['db'].update(kwargs)
    
    def add_folder_mapping(self, folder: str, table: str, schema: str = 'dbo') -> None:
        """
        Add or update a folder mapping.
        
        Args:
            folder (str): Folder name
            table (str): Table name
            schema (str): Schema name (default: 'dbo')
        """
        if 'folders' not in self.data:
            self.data['folders'] = []
        
        # Update existing or add new
        for mapping in self.data['folders']:
            if mapping.get('folder') == folder:
                mapping['table'] = table
                mapping['schema'] = schema
                return
        
        self.data['folders'].append({
            'folder': folder,
            'table': table,
            'schema': schema
        })
    
    def remove_folder_mapping(self, folder: str) -> bool:
        """
        Remove a folder mapping.
        
        Args:
            folder (str): Folder name to remove
        
        Returns:
            bool: True if removed, False if not found
        """
        if 'folders' not in self.data:
            return False
        
        original_length = len(self.data['folders'])
        self.data['folders'] = [m for m in self.data['folders'] if m.get('folder') != folder]
        return len(self.data['folders']) < original_length
