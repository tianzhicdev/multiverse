import logging
import os
from logging.handlers import RotatingFileHandler

# Base log directory
LOG_DIR = '/logs'

# Create log directory if it doesn't exist
os.makedirs(LOG_DIR, exist_ok=True)

def setup_logger(name, log_file, level=logging.INFO):
    """
    Set up a logger with a specific name and file path.
    
    Args:
        name (str): Logger name (usually __name__)
        log_file (str): Name of the log file
        level: Logging level (default: INFO)
        
    Returns:
        The configured logger object
    """
    # Create handler with file path
    handler = RotatingFileHandler(
        os.path.join(LOG_DIR, log_file),
        maxBytes=10*1024*1024,  # 10MB
        backupCount=10
    )
    
    # Set formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    handler.setFormatter(formatter)
    
    # Configure logger
    logger = logging.getLogger(name)
    logger.setLevel(level)
    
    # Remove existing handlers to prevent duplicates
    logger.handlers = []
    
    # Add new handler
    logger.addHandler(handler)
    
    return logger 