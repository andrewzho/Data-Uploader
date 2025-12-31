"""Custom exceptions for the Data Uploader application."""


class DataUploaderException(Exception):
    """Base exception for Data Uploader."""
    pass


class ConnectionError(DataUploaderException):
    """Database connection failed."""
    pass


class ValidationError(DataUploaderException):
    """Data validation failed."""
    pass


class UploadError(DataUploaderException):
    """Upload operation failed."""
    pass


class ConfigError(DataUploaderException):
    """Configuration error."""
    pass


class FileError(DataUploaderException):
    """File operation error."""
    pass


class SQLExecutionError(DataUploaderException):
    """SQL script execution error."""
    pass
