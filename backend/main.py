from flask import Flask
from flask import request, send_file    
import io
import logging
import os
from dotenv import load_dotenv
from helper import process_image_with_theme
from helper import theme_descriptions
import random
from io import BytesIO  
# Load environment variables from .env file if present
load_dotenv()

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
        

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
