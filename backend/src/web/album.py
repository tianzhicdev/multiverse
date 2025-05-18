from flask import jsonify, request
import uuid
from src.common.db import execute_query
from src.common.logging_config import setup_logger

# Configure logger
logger = setup_logger(__name__, 'album.log')

def register_routes(app):
    @app.route('/api/add_to_album', methods=['POST'])
    def add_to_album():
        """
        Add a theme to a user's album
        Required JSON body parameters:
        - user_id: UUID of the user
        - theme_id: UUID of the theme
        """
        try:
            # Get request data
            data = request.get_json()
            
            # Validate required fields
            if not data:
                return jsonify({'error': 'No data provided'}), 400
                
            user_id = data.get('user_id')
            theme_id = data.get('theme_id')
            
            if not user_id:
                return jsonify({'error': 'User ID is required'}), 400
            if not theme_id:
                return jsonify({'error': 'Theme ID is required'}), 400
                
            # Validate UUIDs
            try:
                uuid.UUID(user_id)
                uuid.UUID(theme_id)
            except ValueError:
                return jsonify({'error': 'Invalid UUID format'}), 400
            
            # Insert into albums table
            query = """
                INSERT INTO albums (theme_id, user_id) 
                VALUES (%s, %s)
                ON CONFLICT (theme_id, user_id) DO UPDATE 
                SET updated_at = CURRENT_TIMESTAMP
            """
            
            result = execute_query(query, [theme_id, user_id])
            
            if result == 1:
                # Successful insertion, get the current timestamp
                return jsonify({
                    'theme_id': theme_id,
                    'user_id': user_id,
                    'message': 'Successfully added to album'
                })
            else:
                return jsonify({'error': 'Failed to add to album'}), 500
                
        except Exception as e:
            logger.error(f"Error adding to album: {str(e)}")
            return jsonify({'error': f'Error adding to album: {str(e)}'}), 500