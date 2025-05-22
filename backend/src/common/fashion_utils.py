import os
import base64
import requests
from io import BytesIO
import logging
from src.common.logging_config import setup_logger

# Configure logger using centralized logging config
logger = setup_logger(__name__, 'fashion_utils.log')

def models_fashion(person_image, cloth_image, cloth_type):
    """
    Use ModelsLab fashion API to apply clothing to a person image
    
    Args:
        person_image: BytesIO object containing the person image
        cloth_image: BytesIO object containing the clothing image
        cloth_type: Type of clothing (e.g., 'upper_body', 'lower_body', 'dress')
        
    Returns:
        BytesIO: A file-like object containing the processed image
    """
    logger.info(f"Processing fashion image with cloth type: {cloth_type}")
    
    try:
        # Get base64 encoding of the person image
        person_image.seek(0)
        init_image_bytes = person_image.read()
        init_image_base64 = base64.b64encode(init_image_bytes).decode('utf-8')
        
        # Get base64 encoding of the cloth image
        cloth_image.seek(0)
        cloth_bytes = cloth_image.read()
        cloth_image_base64 = base64.b64encode(cloth_bytes).decode('utf-8')
        
        # Prepare API request
        url = "https://modelslab.com/api/v6/image_editing/fashion"
        
        payload = {
            "key": os.environ.get("MODELSLAB_API_KEY", ""),
            "prompt": "wear the clothe",
            "negative_prompt": "Low quality, unrealistic, bad cloth, warped cloth",
            "init_image": init_image_base64,
            "cloth_image": cloth_image_base64,
            "cloth_type": cloth_type,
            "guidance_scale": 7.5,
            "num_inference_steps": 21,
            "seed": None,
            "base64": True,
            "webhook": None,
            "track_id": None
        }
        
        # Make API request
        response = requests.post(url, json=payload)
        response.raise_for_status()
        
        # Process response
        result_data = response.json()
        
        # Check if the response contains the 'output' array with the image URL
        if 'status' in result_data and result_data['status'] == 'success' and 'output' in result_data and result_data['output']:
            # Get the image URL from the output array
            image_url = result_data['output'][0]
            
            # Download the image from the URL
            image_response = requests.get(image_url)
            image_response.raise_for_status()
            
            # Create a BytesIO object from the downloaded image
            result = BytesIO(image_response.content)
            result.seek(0)
            
            return result
        else:
            raise ValueError(f"API response missing expected data: {result_data}")
        
    except Exception as e:
        logger.error(f"Error in fashion image processing: {str(e)}")
        logger.debug(f"Stack trace:", exc_info=True)
        raise 