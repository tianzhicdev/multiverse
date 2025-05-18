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
            logger.info("Received request to /api/device/logs")
            
            # Attempt to get request data in different formats
            data = None
            content_type = request.headers.get('Content-Type', '')
            
            try:
                # Try to get raw data
                raw_data = request.get_data()
                logger.info(f"Received raw data length: {len(raw_data)}")
                
                # Try JSON if content type suggests it
                if 'application/json' in content_type:
                    try:
                        data = request.json
                        logger.info("Successfully parsed JSON data")
                    except:
                        logger.info("Failed to parse as JSON despite content type")
                        data = {'raw_data': raw_data.decode('utf-8', errors='replace')}
                # Form data
                elif 'application/x-www-form-urlencoded' in content_type:
                    data = dict(request.form)
                    logger.info("Using form data")
                # Multipart form data
                elif 'multipart/form-data' in content_type:
                    form_data = dict(request.form)
                    file_data = {k: f"<file: {v.filename}>" for k, v in request.files.items()}
                    data = {**form_data, **file_data}
                    logger.info("Using multipart form data")
                # Default: treat as raw data
                else:
                    try:
                        # Try to decode as text
                        data = {'raw_data': raw_data.decode('utf-8', errors='replace')}
                        logger.info("Using raw data decoded as text")
                    except:
                        # If it fails, store as base64 or some other indicator
                        data = {'raw_data': f"<binary data, {len(raw_data)} bytes>"}
                        logger.info("Using raw binary data")
            except Exception as e:
                logger.warning(f"Error parsing request data: {str(e)}")
                data = {'error': f"Failed to parse request data: {str(e)}"}
            
            # Extract user_id if it exists, otherwise use anonymous
            user_id = None
            if isinstance(data, dict) and 'user_id' in data:
                user_id = data.get('user_id')
            elif request.args.get('user_id'):
                user_id = request.args.get('user_id')
            
            # Use a default for anonymous logs
            if not user_id:
                user_id = '00000000-0000-0000-0000-000000000000'
                logger.info("No user_id found, using default anonymous user_id")
            
            # Store the data in the actions table
            query = """
                INSERT INTO actions (user_id, action, metadata) 
                VALUES (%s, %s, %s)
                RETURNING id
            """
            
            # Convert data to json string, handling non-dict data
            if not isinstance(data, (dict, list)):
                metadata_json = json.dumps({'data': str(data)})
            else:
                metadata_json = json.dumps(data)
            
            result = execute_query(query, (user_id, 'device_log', metadata_json))
            
            logger.info(f"Logged device data for user_id: {user_id}")
            return jsonify({
                'success': True,
                'message': 'Log data received and stored'
            })
                
        except Exception as e:
            logger.error(f"Error processing device log: {str(e)}")
            return jsonify({
                'success': False,
                'error': f'Error processing device log: {str(e)}'
            }), 500
