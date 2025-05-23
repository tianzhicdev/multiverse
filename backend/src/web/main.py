from flask import Flask
from flask import request, send_file, jsonify    
import logging
from src.common.logging_config import setup_logger
import os
from src.common.helper import use_credits
from src.common.fashion_utils import models_fashion
from src.common.helper import init_user
from io import BytesIO  
import uuid
from src.common.db import execute_query
import json
from src.common.helper import get_themes
from src.common.helper import image_gen
from src.web.purchase import register_routes
from src.web.download import register_routes as register_download_routes
from src.web.metrics import register_routes as register_metrics_routes
from src.web.device_logger import register_routes as register_device_logger_routes
from src.web.album import register_routes as register_album_routes


FLASK_PORT = os.getenv('FLASK_PORT')
print(f"FLASK_PORT: {FLASK_PORT}")

# Enable CORS for all routes
from flask_cors import CORS

app = Flask(__name__)

# Configure logger using centralized logging config
logger = setup_logger(__name__, 'web.log')

# Initialize CORS with default settings to allow all origins
CORS(app)

# Register routes from purchase module
register_routes(app)
# Register routes from download module
register_download_routes(app)
# Register routes from metrics module
register_metrics_routes(app)
# Register routes from device logger module
register_device_logger_routes(app)
# Register routes from album module
register_album_routes(app)

@app.route('/')
def hello_world():
    return 'Hello, World!'

@app.route('/api/image_gen_test', methods=['GET'])
def image_gen_test():
    image_gen("A beautiful sunset over a calm ocean")

@app.route('/api/test-db', methods=['GET'])
def test_db_connection():
    try:
        # Simple query to test database connection
        query = "SELECT 1"
        result = execute_query(query)
        
        if result:
            return jsonify({
                'status': 'success',
                'message': 'Database connection successful',
                'result': result
            })
        else:
            return jsonify({
                'status': 'error',
                'message': 'Database query returned no results'
            }), 500
    except Exception as e:
        logger.error(f"Database connection error: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Database connection failed: {str(e)}'
        }), 500

@app.route('/api/image/<result_image_id>', methods=['GET'])
def get_image(result_image_id):
    """
    Get a generated image by its result_image_id.
    If the image is not ready, returns status information.
    """
    try:
        logger.info(f"Received request for image with ID: {result_image_id}")
        
        # Check if the user is authorized (in a real app, would verify user_id from session/token)
        user_id = request.args.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        # Look up the image request status, theme name, and engine
        query = """
            SELECT ir.status, ir.result_image_id, t.name as theme_name, ir.engine
            FROM image_requests ir
            JOIN themes t ON ir.theme_id = t.id
            WHERE ir.result_image_id = %s AND ir.user_id = %s
        """
        result = execute_query(query, (result_image_id, user_id))
        
        if not result:
            return jsonify({
                'ready': False,
                'status': 'not_found',
                'result_image_id': result_image_id
            })
            
        status, result_image_id, theme_name, engine = result[0]
        
        # If the image is still processing, return the status
        if status != 'ready':
            return jsonify({
                'ready': False,
                'status': status,
                'result_image_id': result_image_id,
                'theme_name': theme_name,
                'engine': engine
            })
            
        # Get the image data from the database
        query = "SELECT data, mime_type FROM images WHERE id = %s"
        image_result = execute_query(query, (result_image_id,))
        
        if not image_result:
            return jsonify({'error': 'Image data not found'}), 404
            
        image_data, mime_type = image_result[0]
        
        # Create a BytesIO object from the image data
        image_io = BytesIO(image_data)
        
        # Return the image with engine information in headers
        response = send_file(
            image_io,
            mimetype=mime_type,
            as_attachment=False
        )
        
        # Add engine information to the response headers
        response.headers['X-Engine'] = engine
        
        return response
            
    except Exception as e:
        logger.error(f"Error retrieving image: {str(e)}")
        return jsonify({'error': f'Error retrieving image: {str(e)}'}), 500



@app.route('/api/credits/<user_id>', methods=['GET'])
def get_user_credits(user_id):
    """
    Get the credit balance for a user.
    """
    try:
        logger.info(f"Received request for credits for user: {user_id}")
        
        # Check if user exists
        query = "SELECT credits FROM users WHERE user_id = %s"
        result = execute_query(query, (user_id,))
        
        if not result:
            return jsonify({'error': 'User not found'}), 404
            
        credits = result[0][0]
        
        return jsonify({
            'user_id': user_id,
            'credits': credits
        })
            
    except Exception as e:
        logger.error(f"Error retrieving user credits: {str(e)}")
        return jsonify({'error': f'Error retrieving user credits: {str(e)}'}), 500

@app.route('/api/use_credits', methods=['POST'])
def use_user_credits():
    """
    Use (deduct) credits from a user's account.
    """
    try:
        user_id = request.json.get('user_id')
        credits = request.json.get('credits', 0)
        reason = request.json.get('reason', 'API credit usage')
        
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        if not isinstance(credits, int) or credits <= 0:
            return jsonify({'error': 'Credits must be a positive integer'}), 400
            
        # Use the helper function to deduct credits
        if use_credits(user_id, credits, reason):
            # If successful, get remaining credits
            query = "SELECT credits FROM users WHERE user_id = %s"
            result = execute_query(query, (user_id,))
            remaining_credits = result[0][0]
            
            return jsonify({
                'success': True,
                'user_id': user_id,
                'credits_used': credits,
                'remaining_credits': remaining_credits
            })
        else:
            return jsonify({
                'success': False,
                'error': 'Insufficient credits or user not found'
            }), 400
            
    except Exception as e:
        logger.error(f"Error using credits: {str(e)}")
        return jsonify({'error': f'Error using credits: {str(e)}'}), 500

@app.route('/api/upload', methods=['POST'])
def upload_image():
    """
    Upload an image and save it to the database.
    Returns the source_image_id for future use.
    """
    try:
        logger.info("Received request to /api/upload")
        
        # Extract parameters from request
        user_id = request.form.get('user_id')
        
        # Validate required parameters
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        # Check if an image file was uploaded
        if 'image' not in request.files:
            return jsonify({'error': 'Missing image file'}), 400
            
        image_file = request.files['image']
        logger.info(f"Received image file: {image_file.filename}")
        
        # Read image data
        image_data = image_file.read()
        image_file.seek(0)  # Reset file pointer for any future use
        
        # Save image to database
        source_image_id = str(uuid.uuid4())
        query = """
            INSERT INTO images (id, user_id, data, mime_type, metadata) 
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """
        metadata = json.dumps({})  # Empty metadata for now
        execute_query(query, (source_image_id, user_id, image_data, image_file.content_type, metadata))
        logger.info(f"Saved source image with ID: {source_image_id}")
        
        return jsonify({
            'source_image_id': source_image_id
        })
            
    except Exception as e:
        logger.error(f"Error uploading image: {str(e)}")
        return jsonify({'error': f'Error uploading image: {str(e)}'}), 500

@app.route('/api/roll', methods=['POST'])
def roll_themes():
    """
    Create image generation requests for a previously uploaded image:
    1. Check user credits
    2. Get themes for user
    3. Create result_image_ids for async processing
    """
    try:
        logger.info("Received request to /api/roll")
        
        # Extract parameters from request
        source_image_id = request.form.get('source_image_id')
        user_id = request.form.get('user_id')
        user_description = request.form.get('user_description', '')
        num_themes = request.form.get('num_themes')
        request_id = request.form.get('request_id', str(uuid.uuid4()))
        album = request.form.get('album', 'default')
        app_name = request.form.get('app_name', 'multiverse')
        logger.info(f"Album: {album}")
        logger.info(f"App Name: {app_name}")
        
        # Validate required parameters
        if not all([source_image_id, user_id]):
            return jsonify({'error': 'Missing required parameters'}), 400
            
        # Step 1: Check user credits - we don't actually deduct credits at this stage,
        # but we need to verify they have at least 1 credit
        if not use_credits(user_id, 0, "Credit check for roll themes"):
            return jsonify({'error': 'User not found or invalid account'}), 404
            
        # Step 2: Get themes for user
        selected_themes = get_themes(user_id, num_themes, album, app_name)
        
        # Step 3: Create result_image_ids for async processing
        result_image_ids = []
        image_info = []
        
        for theme in selected_themes:
            result_image_id = str(uuid.uuid4())
            
            # Record the processing request in the database
            query = """
                INSERT INTO image_requests 
                (request_id, source_image_id, theme_id, result_image_id, user_id, user_description, status, created_at) 
                VALUES (%s, %s, %s, %s, %s, %s, %s, NOW())
            """
            execute_query(query, (
                request_id, 
                source_image_id, 
                theme["id"], 
                result_image_id, 
                user_id,
                user_description,
                'new'
            ))
            
            result_image_ids.append(result_image_id)
            image_info.append({
                "result_image_id": result_image_id,
                "theme_id": theme["id"],
                "theme_name": theme["name"]
            })
            
        # Step 4: In a production environment, we would trigger async processing here
        logger.info(f"Would trigger async processing for {len(result_image_ids)} themes")
        
        # Return the list of result_image_ids and theme information
        return jsonify({
            'request_id': request_id,
            'source_image_id': source_image_id,
            'images': image_info
        })
            
    except Exception as e:
        logger.error(f"Error rolling themes: {str(e)}")
        return jsonify({'error': f'Error rolling themes: {str(e)}'}), 500

@app.route('/api/roll/test', methods=['POST'])
def roll_themes_test():
    """
    Test endpoint that mimics /api/roll but returns existing 'ready' image requests.
    Returns at least num_themes imageInfo objects with 'ready' status.
    """
    try:
        logger.info("Received request to /api/roll/test")
        
        # Extract parameters from request
        user_id = request.form.get('user_id')
        num_themes = int(request.form.get('num_themes', 9))
        source_image_id = request.form.get('source_image_id', str(uuid.uuid4()))
        album = request.form.get('album', 'default')
        logger.info(f"Album: {album}")
        
        # Validate user_id
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        # Find request_ids that have at least num_themes 'ready' images
        count_query = """
            SELECT request_id, COUNT(*) as count
            FROM image_requests
            WHERE user_id = %s AND status = 'ready'
            GROUP BY request_id
            HAVING COUNT(*) >= %s
            ORDER BY MAX(created_at) DESC
            LIMIT 1
        """
        count_result = execute_query(count_query, (user_id, num_themes))
        
        if not count_result:
            logger.info(f"No requests with at least {num_themes} 'ready' images found for user {user_id}")
            
            # Get any 'ready' images for this user
            backup_query = """
                SELECT ir.result_image_id, ir.theme_id, t.name as theme_name
                FROM image_requests ir
                JOIN themes t ON ir.theme_id = t.id
                WHERE ir.user_id = %s AND ir.status = 'ready'
                ORDER BY ir.created_at DESC
                LIMIT %s
            """
            backup_results = execute_query(backup_query, (user_id, num_themes))
            
            # Create a response with a new request_id
            request_id = str(uuid.uuid4())
            image_info = []
            
            for row in backup_results:
                result_image_id, theme_id, theme_name = row
                image_info.append({
                    'result_image_id': result_image_id,
                    'theme_id': theme_id,
                    'theme_name': theme_name,
                    'status': 'ready'
                })
            
            # If we still don't have enough images, generate dummy ones
            if len(image_info) < num_themes:
                # Use get_themes to fill the remaining spots
                remaining = num_themes - len(image_info)
                remaining_themes = get_themes(user_id, remaining, album)
                
                for theme in remaining_themes:
                    image_info.append({
                        'result_image_id': str(uuid.uuid4()),
                        'theme_id': theme["id"],
                        'theme_name': theme["name"],
                        'status': 'ready'
                    })
            
            return jsonify({
                'request_id': request_id,
                'source_image_id': source_image_id,
                'images': image_info
            })
        
        # We found a request with enough images
        request_id = count_result[0][0]
        
        # Get the image details for this request
        query = """
            SELECT ir.result_image_id, ir.theme_id, t.name as theme_name, ir.source_image_id
            FROM image_requests ir
            JOIN themes t ON ir.theme_id = t.id
            WHERE ir.request_id = %s AND ir.status = 'ready'
            LIMIT %s
        """
        results = execute_query(query, (request_id, num_themes))
        
        # Use the actual source_image_id from the first result
        if results and len(results) > 0:
            source_image_id = results[0][3]
        
        # Format the response
        image_info = []
        for row in results:
            result_image_id, theme_id, theme_name, _ = row
            image_info.append({
                'result_image_id': result_image_id,
                'theme_id': theme_id,
                'theme_name': theme_name,
                'status': 'ready'
            })
        
        logger.info(f"Found {len(image_info)} 'ready' images for request {request_id}")
        
        return jsonify({
            'request_id': request_id,
            'source_image_id': source_image_id,
            'images': image_info
        })
            
    except Exception as e:
        logger.error(f"Error getting test themes: {str(e)}")
        return jsonify({'error': f'Error getting test themes: {str(e)}'}), 500

@app.route('/api/action', methods=['POST'])
def create_action():
    """
    Create an action in the database.
    """
    try:
        logger.info("Received request to /api/action")
        
        # Extract parameters from request
        user_id = request.json.get('user_id')
        action = request.json.get('action')
        metadata = request.json.get('metadata', {})
        
        # Validate required parameters
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        
        if not action:
            return jsonify({'error': 'Missing action parameter'}), 400
            
        # Insert the action into the database
        query = """
            INSERT INTO actions (user_id, action, metadata) 
            VALUES (%s, %s, %s)
            RETURNING created_at
        """
        result = execute_query(query, (user_id, action, json.dumps(metadata)))
        
        
        return jsonify({
            'success': result == 1
        })
            
    except Exception as e:
        logger.error(f"Error logging action: {str(e)}")
        return jsonify({'error': f'Error logging action: {str(e)}'}), 500

@app.route('/api/init_user', methods=['POST'])
def initialize_user():
    """
    Initialize a user in the system.
    """
    try:
        logger.info("Received request to /api/init_user")
        
        # Extract user_id parameter from request
        user_id = request.json.get('user_id')
        
        # Validate required parameter
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        # Initialize the user
        init_user(user_id, "API user initialization")
        
        return jsonify({
            'success': True,
            'user_id': user_id
        })
            
    except Exception as e:
        logger.error(f"Error initializing user: {str(e)}")
        return jsonify({'error': f'Error initializing user: {str(e)}'}), 500

@app.route('/api/fashion', methods=['POST'])
def apply_fashion():
    """
    Apply clothing from one image to a person in another image.
    
    Request should contain:
    - 'source_image_id': The ID of the person image
    - 'theme_id': The ID of the theme containing the clothing image
    - 'user_id': The user ID for credit tracking
    
    Returns:
        JSON with request_id and status
    """
    try:
        # Parse input from JSON request
        request_data = request.get_json()
        
        # Get required parameters
        source_image_id = request_data.get('source_image_id')
        theme_id = request_data.get('theme_id')
        user_id = request_data.get('user_id')
        
        # Validate required parameters
        if not all([source_image_id, theme_id, user_id]):
            return jsonify({'error': 'Missing required parameters'}), 400
            
        # Check if user has enough credits (1 credit for fashion editing)
        if not use_credits(user_id, 1, reason='Fashion image processing'):
            return jsonify({'error': 'Insufficient credits'}), 402
        
        # Create a request ID for tracking
        request_id = str(uuid.uuid4())
        
        # Create a result image ID
        result_image_id = str(uuid.uuid4())
        
        # Insert into image_requests table
        query = """
            INSERT INTO image_requests (
                id, request_id, source_image_id, theme_id, result_image_id, 
                user_id, status, engine, created_at
            )
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
            RETURNING id
        """
        image_request_id = str(uuid.uuid4())
        execute_query(
            query, 
            (
                image_request_id, 
                request_id, 
                source_image_id, 
                theme_id, 
                result_image_id, 
                user_id, 
                'new', 
                'fashion'
            )
        )
        
        # Return success response with request ID and status
        return jsonify({
            'request_id': request_id,
            'result_image_id': result_image_id,
            'status': 'new'
        })
            
    except Exception as e:
        logger.error(f"Error in fashion image processing: {str(e)}")
        return jsonify({'error': f'Error in fashion image processing: {str(e)}'}), 500

@app.route('/api/fashion_theme', methods=['POST'])
def upload_fashion_theme():
    """
    Create a new theme for a clothing item.
    
    Request should contain:
    - 'image': The image file of the clothing
    - 'type': The type of clothing ('upper_body', 'lower_body', 'dress', etc.)
    - 'user_id': The user ID
    
    Returns:
        JSON with theme_id
    """
    try:
        logger.info("Received request to /api/theme")
        
        # Extract parameters from request
        user_id = request.form.get('user_id')
        cloth_type = request.form.get('type', 'upper_body')
        
        # Validate required parameters
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        # Check if an image file was uploaded
        if 'image' not in request.files:
            return jsonify({'error': 'Missing image file'}), 400
            
        image_file = request.files['image']
        logger.info(f"Received theme image file: {image_file.filename}")
        
        # Read image data
        image_data = image_file.read()
        
        # Create metadata with image data
        metadata = {
            'image': image_data.hex(),  # Store binary image as hex string
            'mime_type': 'image/jpeg',
            'type': cloth_type
        }
        
        # Generate a theme ID
        theme_id = str(uuid.uuid4())
        
        # Insert theme into database
        query = """
            INSERT INTO themes (id, name, theme, metadata, type, public, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
            RETURNING id
        """
        execute_query(
            query, 
            (
                theme_id,
                '',  # Empty name
                '',  # Empty theme
                json.dumps(metadata),
                'user_upload',
                False  # Not public
            )
        )
        logger.info(f"Created theme with ID: {theme_id}")
        
        return jsonify({
            'theme_id': theme_id
        })
            
    except Exception as e:
        logger.error(f"Error creating theme: {str(e)}")
        return jsonify({'error': f'Error creating theme: {str(e)}'}), 500

@app.route('/api/fashion_theme_from_id', methods=['POST'])
def upload_fashion_theme_from_id():
    """
    Create a new theme for a clothing item using an already uploaded image.
    
    Request should contain:
    - 'image_id': The ID of the already uploaded image
    - 'type': The type of clothing ('upper_body', 'lower_body', 'dress', etc.)
    - 'user_id': The user ID
    
    Returns:
        JSON with theme_id
    """
    try:
        logger.info("Received request to /api/fashion_theme_from_id")
        
        # Parse JSON request
        request_data = request.get_json()
        if not request_data:
            return jsonify({'error': 'Invalid JSON data'}), 400
            
        # Extract parameters from request
        image_id = request_data.get('image_id')
        user_id = request_data.get('user_id')
        cloth_type = request_data.get('type', 'upper_body')
        
        # Validate required parameters
        if not image_id:
            return jsonify({'error': 'Missing image_id parameter'}), 400
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        # Fetch the image data from the images table
        query = "SELECT data, mime_type FROM images WHERE id = %s AND user_id = %s"
        image_result = execute_query(query, (image_id, user_id))
        
        if not image_result:
            return jsonify({'error': 'Image not found or access denied'}), 404
            
        # Get image data and mime_type
        image_data, mime_type = image_result[0]
        
        # Create metadata with image data
        metadata = {
            'image': image_data.hex(),  # Store binary image as hex string
            'mime_type': mime_type,
            'type': cloth_type,
            'source_image_id': image_id  # Store reference to original image
        }
        
        # Generate a theme ID
        theme_id = str(uuid.uuid4())
        
        # Insert theme into database
        query = """
            INSERT INTO themes (id, name, theme, metadata, type, public, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, CURRENT_TIMESTAMP)
            RETURNING id
        """
        execute_query(
            query, 
            (
                theme_id,
                '',  # Empty name
                '',  # Empty theme
                json.dumps(metadata),
                'user_upload',
                False  # Not public
            )
        )
        logger.info(f"Created theme with ID: {theme_id} from image ID: {image_id}")
        
        return jsonify({
            'theme_id': theme_id
        })
            
    except Exception as e:
        logger.error(f"Error creating theme from image ID: {str(e)}")
        return jsonify({'error': f'Error creating theme from image ID: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=FLASK_PORT)
