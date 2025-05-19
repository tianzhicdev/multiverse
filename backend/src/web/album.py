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
            
    @app.route('/api/album', methods=['GET'])
    def get_user_album():
        """
        Get all themes in a user's album
        Required query parameter:
        - user_id: UUID of the user
        """
        try:
            user_id = request.args.get('user_id')
            
            if not user_id:
                return jsonify({'error': 'User ID is required'}), 400
                
            # Validate UUID
            try:
                uuid.UUID(user_id)
            except ValueError:
                return jsonify({'error': 'Invalid UUID format'}), 400
                
            # Join albums and themes tables to get theme information
            query = """
                SELECT t.id, t.name
                FROM albums a
                JOIN themes t ON a.theme_id = t.id
                WHERE a.user_id = %s
                ORDER BY a.updated_at DESC
            """
            
            results = execute_query(query, [user_id])
            
            themes = []
            for row in results:
                themes.append({
                    'theme_id': row[0],
                    'name': row[1]
                })
                
            return jsonify({
                'user_id': user_id,
                'themes': themes
            })
                
        except Exception as e:
            logger.error(f"Error retrieving user album: {str(e)}")
            return jsonify({'error': f'Error retrieving user album: {str(e)}'}), 500
            
    @app.route('/api/album', methods=['DELETE'])
    def remove_from_album():
        """
        Remove a theme from a user's album
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
                
            # Delete from albums table
            query = """
                DELETE FROM albums
                WHERE user_id = %s AND theme_id = %s
            """
            
            result = execute_query(query, [user_id, theme_id])
            
            if result >= 0:
                return jsonify({
                    'theme_id': theme_id,
                    'user_id': user_id,
                    'message': 'Successfully removed from album'
                })
            else:
                return jsonify({'error': 'Failed to remove from album'}), 500
                
        except Exception as e:
            logger.error(f"Error removing from album: {str(e)}")
            return jsonify({'error': f'Error removing from album: {str(e)}'}), 500
            
    @app.route('/api/create_theme', methods=['POST'])
    def create_theme():
        """
        Create a new theme and add it to user's album
        Required JSON body parameters:
        - user_id: UUID of the user
        - name: Name of the theme
        - description: Description/content of the theme
        """
        try:
            # Get request data
            data = request.get_json()
            
            # Validate required fields
            if not data:
                return jsonify({'error': 'No data provided'}), 400
                
            user_id = data.get('user_id')
            name = data.get('name')
            description = data.get('description')
            
            if not user_id:
                return jsonify({'error': 'User ID is required'}), 400
            if not name:
                return jsonify({'error': 'Theme name is required'}), 400
            if not description:
                return jsonify({'error': 'Theme description is required'}), 400
                
            # Validate UUID
            try:
                uuid.UUID(user_id)
            except ValueError:
                return jsonify({'error': 'Invalid UUID format'}), 400
            
            # Generate new UUID for theme
            theme_id = str(uuid.uuid4())
            
            # Insert into themes table (note: description goes into the 'theme' column, not 'description')
            theme_query = """
                INSERT INTO themes (id, name, theme, public)
                VALUES (%s, %s, %s, %s)
            """
            
            theme_result = execute_query(theme_query, [theme_id, name, description, False])
            
            if theme_result != 1:
                return jsonify({'error': 'Failed to create theme'}), 500
                
            # Insert into albums table
            album_query = """
                INSERT INTO albums (theme_id, user_id)
                VALUES (%s, %s)
            """
            
            album_result = execute_query(album_query, [theme_id, user_id])
            
            if album_result != 1:
                # If album insertion fails, try to remove the theme
                execute_query("DELETE FROM themes WHERE id = %s", [theme_id])
                return jsonify({'error': 'Failed to add theme to album'}), 500
                
            return jsonify({
                'theme_id': theme_id,
                'name': name,
                'description': description,
                'message': 'Successfully created theme and added to album'
            })
                
        except Exception as e:
            logger.error(f"Error creating theme: {str(e)}")
            return jsonify({'error': f'Error creating theme: {str(e)}'}), 500