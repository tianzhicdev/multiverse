from flask import jsonify, request
import json
from src.common.db import execute_query
from src.common.logging_config import setup_logger

# Configure logger
logger = setup_logger(__name__, 'device_logger.log')

def register_routes(app):
    @app.route('/api/device/logs', methods=['POST'])
    def log_device_data():
        """
        Receive and store logs from user devices.
        
        Logs whatever data is received without making assumptions about the structure.
        """
        try:
            logger.info(request.json)
           
        except Exception as e:
            logger.error(f"Error processing device log: {str(e)}")
            return jsonify({
                'success': False,
                'error': f'Error processing device log: {str(e)}'
            }), 500
