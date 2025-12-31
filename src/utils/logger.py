"""Logging utilities for the Data Uploader application."""
import logging
from pathlib import Path
from datetime import datetime


def setup_logger(name, log_file='data_uploader.log', level=logging.INFO):
    """
    Setup logger with file and console handlers.
    
    Args:
        name (str): Logger name
        log_file (str): Path to log file
        level: Logging level (default: logging.INFO)
    
    Returns:
        logging.Logger: Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # Prevent duplicate handlers
    if logger.handlers:
        return logger
    
    # File handler
    fh = logging.FileHandler(log_file)
    fh.setLevel(level)
    
    # Console handler
    ch = logging.StreamHandler()
    ch.setLevel(logging.WARNING)
    
    # Formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    
    logger.addHandler(fh)
    logger.addHandler(ch)
    
    return logger


def format_log_message(message, level='INFO'):
    """
    Format a log message with timestamp.
    
    Args:
        message (str): Message to format
        level (str): Log level (INFO, WARNING, ERROR)
    
    Returns:
        str: Formatted log message
    """
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    return f"[{timestamp}] {level}: {message}"
