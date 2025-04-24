from flask import Flask
from flask import request, send_file, jsonify    
import io
import logging
import os
from dotenv import load_dotenv
from helper import process_image_with_theme
from helper import theme_descriptions
from helper import use_credits
from helper import init_user
import random
from io import BytesIO  
import uuid
from db import execute_query
import json
from helper import get_themes
# Load environment variables from .env file if present
load_dotenv()
FLASK_PORT = os.getenv('FLASK_PORT')
print(f"FLASK_PORT: {FLASK_PORT}")

# Enable CORS for all routes
from flask_cors import CORS

app = Flask(__name__)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize CORS with default settings to allow all origins
CORS(app)

@app.route('/')
def hello_world():
    return 'Hello, World!'

@app.route('/api/gen', methods=['POST'])
def generate_image():
    try:
        logger.info("Received request to /api/gen")
        logger.info(f"Request headers: {dict(request.headers)}")
        logger.info(f"Request form data: {request.form.to_dict()}")
        logger.info(f"Request files: {request.files.to_dict()}")
        
        # Get the prompt (required)
        user_description = request.form.get('user_description')
        theme_description = request.form.get('theme_description')
            
        logger.info(f"Received user description: {user_description}")
        logger.info(f"Received theme description: {theme_description}")
        
        # Check if all required parameters are provided
        if not user_description:
            user_description = ""
            # return {'error': 'Missing user_description parameter'}, 400
            
        if not theme_description:
            theme_description = random.choice(theme_descriptions)
            # return {'error': 'Missing theme_description parameter'}, 400
        
        # Check if an image file was uploaded (required)
        if 'image' in request.files:
            image_file = request.files['image']
            logger.info(f"Received image file: {image_file.filename}")
            logger.info(f"Image content type: {image_file.content_type}")
            
            # Process the image using OpenAI APIs
            try:
                result_image = process_image_with_theme(
                    image_file, 
                    user_description, 
                    theme_description
                )
                
                # Return the generated image
                return send_file(
                    result_image,
                    mimetype='image/jpeg',  # DALL-E usually returns JPEGs
                    as_attachment=True,
                    download_name='generated_image.jpg'
                )
            except Exception as e:
                logger.error(f"Error processing image: {str(e)}")
                return {'error': f'Error processing image: {str(e)}'}, 500
        else:
            logger.error("No image file provided")
            return {'error': 'Missing image file'}, 400
            
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        return {'error': f'Error processing request: {str(e)}'}, 500


@app.route('/api/gen/test', methods=['POST'])
def generate_image_test():
    """
    Test endpoint that simply returns the uploaded image without processing.
    """
    try:
        logger.info("Received test image generation request")
        
        # Check if an image file was uploaded
        if 'image' in request.files:
            image_file = request.files['image']
            logger.info(f"Received image file: {image_file.filename}")
            logger.info(f"Image content type: {image_file.content_type}")
            
            # Create a BytesIO object to hold the image data
            result_image = BytesIO()
            # Read the image file and write it to the BytesIO object
            image_file.seek(0)
            result_image.write(image_file.read())
            result_image.seek(0)
            # Add a random delay between 1 and 4 seconds to simulate processing time
            import random
            import time
            
            delay_seconds = random.uniform(1.0, 4.0)
            logger.info(f"Adding test delay of {delay_seconds:.2f} seconds")
            time.sleep(delay_seconds)
            
            # Return the original image
            return send_file(
                result_image,
                mimetype=image_file.content_type,
                as_attachment=True,
                download_name='test_image.jpg'
            )
        else:
            logger.error("No image file provided")
            return {'error': 'Missing image file'}, 400
            
    except Exception as e:
        logger.error(f"Error processing test request: {str(e)}")
        return {'error': f'Error processing test request: {str(e)}'}, 500
        

@app.route('/api/create', methods=['POST'])
def create_image_request():
    """
    Create a new image generation request:
    1. Save uploaded image to database
    2. Check user credits
    3. Get 12 themes for user
    4. Return list of result_image_ids for async processing
    """
    try:
        logger.info("Received request to /api/create")
        
        # Extract parameters from request
        user_id = request.form.get('user_id')
        user_description = request.form.get('user_description', '')
        request_id = request.form.get('request_id', str(uuid.uuid4()))
        
        # Validate required parameters
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
        else:
            init_user(user_id)
            
        # Check if an image file was uploaded
        if 'image' not in request.files:
            return jsonify({'error': 'Missing image file'}), 400
            
        image_file = request.files['image']
        logger.info(f"Received image file: {image_file.filename}")
        
        # Read image data
        image_data = image_file.read()
        image_file.seek(0)  # Reset file pointer for any future use
        
        # Step 1: Save image to database
        source_image_id = str(uuid.uuid4())
        query = """
            INSERT INTO images (id, user_id, data, mime_type, metadata) 
            VALUES (%s, %s, %s, %s, %s)
            RETURNING id
        """
        metadata = json.dumps({"user_description": user_description})
        execute_query(query, (source_image_id, user_id, image_data, image_file.content_type, metadata))
        logger.info(f"Saved source image with ID: {source_image_id}")
        
        # Step 2: Check user credits - we don't actually deduct credits at this stage,
        # but we need to verify they have at least 1 credit
        if not use_credits(user_id, 0):
            return jsonify({'error': 'User not found or invalid account'}), 404
            
        # todo: get it from db
        selected_themes = get_themes(user_id, 12)
        
        # Step 4: Create result_image_ids for async processing
        result_image_ids = []
        
        for i, theme_id in enumerate(selected_themes):
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
                theme_id, 
                result_image_id, 
                user_id,
                user_description,
                'new'
            ))
            
            result_image_ids.append(result_image_id)
            
        # Step 5: In a production environment, we would trigger async processing here
        # For example, using a message queue or background tasks
        # For now, just log that this would happen
        logger.info(f"Would trigger async processing for {len(result_image_ids)} themes")
        
        # Return the list of result_image_ids
        return jsonify({
            'request_id': request_id,
            'source_image_id': source_image_id,
            'result_image_ids': result_image_ids
        })
            
    except Exception as e:
        logger.error(f"Error creating image request: {str(e)}")
        return jsonify({'error': f'Error creating image request: {str(e)}'}), 500

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
            
        # Look up the image request status
        query = """
            SELECT status, result_image_id FROM image_requests 
            WHERE result_image_id = %s AND user_id = %s
        """
        result = execute_query(query, (result_image_id, user_id))
        
        if not result:
            return jsonify({
                'ready': False,
                'status': 'not_found',
                'result_image_id': result_image_id
            })
            
        status, result_image_id = result[0]
        
        # If the image is still processing, return the status
        if status != 'ready':
            return jsonify({
                'ready': False,
                'status': status,
                'result_image_id': result_image_id
            })
            
        # Get the image data from the database
        query = "SELECT data, mime_type FROM images WHERE id = %s"
        image_result = execute_query(query, (result_image_id,))
        
        if not image_result:
            return jsonify({'error': 'Image data not found'}), 404
            
        image_data, mime_type = image_result[0]
        
        # Create a BytesIO object from the image data
        image_io = BytesIO(image_data)
        
        # Return the image
        return send_file(
            image_io,
            mimetype=mime_type,
            as_attachment=False
        )
            
    except Exception as e:
        logger.error(f"Error retrieving image: {str(e)}")
        return jsonify({'error': f'Error retrieving image: {str(e)}'}), 500


@app.route('/api/image/test/<result_image_id>', methods=['GET'])
def get_image_test(result_image_id):
    """
    Test endpoint to retrieve an image by its result_image_id.
    This is a simplified version of get_image without user authentication.
    """
    try:
        logger.info(f"Received test image request for image with ID: {result_image_id}")

        logger.info(f"use test image with id: c250ab6c-d9ac-4682-8486-d23d2ff7830c")
        
        # Get the image data from the database
        query = "SELECT data, mime_type FROM images WHERE id = %s"
        image_result = execute_query(query, ("c250ab6c-d9ac-4682-8486-d23d2ff7830c",))
        
        if not image_result:
            return jsonify({'error': 'Image data not found'}), 404
            
        image_data, mime_type = image_result[0]
        
        # Create a BytesIO object from the image data
        image_io = BytesIO(image_data)
        
        # Return the image
        return send_file(
            image_io,
            mimetype=mime_type,
            as_attachment=True,
            download_name=f'{result_image_id}.jpg'
        )
            
    except Exception as e:
        logger.error(f"Error retrieving test image: {str(e)}")
        return jsonify({'error': f'Error retrieving test image: {str(e)}'}), 500


        


@app.route('/api/download/<result_image_id>', methods=['POST'])
def download_image(result_image_id):
    """
    Download a generated image and decrement user credit.
    """
    try:
        logger.info(f"Received download request for image with ID: {result_image_id}")
        
        # Check if the user is authorized
        user_id = request.form.get('user_id')
        if not user_id:
            return jsonify({'error': 'Missing user_id parameter'}), 400
            
        # Verify the image exists and belongs to the user
        query = """
            SELECT ir.status FROM image_requests ir
            WHERE ir.result_image_id = %s AND ir.user_id = %s
        """
        result = execute_query(query, (result_image_id, user_id))
        
        if not result:
            return jsonify({'error': 'Image not found or unauthorized'}), 404
            
        status = result[0][0]
        
        if status != 'completed':
            return jsonify({'error': 'Image is not ready for download'}), 400
            
        # Use helper function to deduct credits
        if not use_credits(user_id, 1):
            return jsonify({'error': 'Insufficient credits'}), 403
            
        # Get remaining credits
        query = "SELECT credits FROM users WHERE user_id = %s"
        result = execute_query(query, (user_id,))
        remaining_credits = result[0][0]
        
        # Log the download action
        query = """
            INSERT INTO actions (user_id, action, metadata, created_at)
            VALUES (%s, %s, %s, NOW())
        """
        execute_query(query, (
            user_id, 
            'download_image', 
            {'result_image_id': result_image_id}
        ))
        
        return jsonify({
            'success': True,
            'remaining_credits': remaining_credits
        })
            
    except Exception as e:
        logger.error(f"Error downloading image: {str(e)}")
        return jsonify({'error': f'Error downloading image: {str(e)}'}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=FLASK_PORT)
