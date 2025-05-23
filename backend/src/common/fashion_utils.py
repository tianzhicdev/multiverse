import os
import base64
import requests
import time
from io import BytesIO
import logging
from src.common.logging_config import setup_logger

# Configure logger using centralized logging config
logger = setup_logger(__name__, 'fashion_utils.log')

def convert_to_bytesio(image_data):
    """
    Convert various image input formats to BytesIO
    
    Args:
        image_data: Image data as BytesIO, base64 string, or data URL
        
    Returns:
        BytesIO: Image data as BytesIO object
    """
    if isinstance(image_data, BytesIO):
        # Already BytesIO, just seek to start
        image_data.seek(0)
        return image_data
        
    if isinstance(image_data, str):
        if image_data.startswith('data:image'):
            # Extract base64 content from data URL
            _, base64_content = image_data.split(',', 1)
            image_bytes = base64.b64decode(base64_content)
        else:
            # Assume it's a base64 string without data URL prefix
            image_bytes = base64.b64decode(image_data)
        
        return BytesIO(image_bytes)
    
    # Fallback for unsupported types
    raise ValueError(f"Unsupported image data type: {type(image_data)}")

def encode_image_base64(image_data):
    """
    Convert BytesIO image data to base64 string
    
    Args:
        image_data: BytesIO object containing image
        
    Returns:
        str: Base64 encoded string
    """
    image_data.seek(0)
    image_bytes = image_data.read()
    return base64.b64encode(image_bytes).decode('utf-8')

def process_image_url(image_url):
    """
    Process an image URL and return the image as BytesIO
    
    Args:
        image_url: URL to the image or base64 data URL
        
    Returns:
        BytesIO: Image data as BytesIO object
    """
    logger.info(f"Processing image URL: {image_url}")
    
    # Handle data URLs directly
    if image_url.startswith('data:image'):
        _, base64_content = image_url.split(',', 1)
        image_bytes = base64.b64decode(base64_content)
        result = BytesIO(image_bytes)
        result.seek(0)
        return result
    
    # Special handling for URLs that end with .base64
    if image_url.endswith('.base64'):
        logger.info(f"Fetching base64 content from URL: {image_url}")
        response = requests.get(image_url)
        response.raise_for_status()
        
        data_url = response.text
        if data_url.startswith('data:image'):
            _, base64_content = data_url.split(',', 1)
            image_bytes = base64.b64decode(base64_content)
        else:
            try:
                image_bytes = base64.b64decode(data_url)
            except Exception as e:
                logger.error(f"Failed to decode base64 content: {str(e)}")
                # Fall back to treating as regular binary content
                return BytesIO(response.content)
        
        result = BytesIO(image_bytes)
        result.seek(0)
        return result
    
    # Standard image URL
    image_response = requests.get(image_url)
    image_response.raise_for_status()
    result = BytesIO(image_response.content)
    result.seek(0)
    return result

def poll_result(fetch_url, api_key, max_retries=100, initial_wait=10):
    """
    Poll for fashion API result
    
    Args:
        fetch_url: URL to poll for results
        api_key: ModelsLab API key
        max_retries: Maximum number of polling attempts
        initial_wait: Wait time in seconds between polling attempts
        
    Returns:
        BytesIO: Processed image as BytesIO
        
    Raises:
        TimeoutError: When max retries are exceeded
        ValueError: When API returns unexpected response
    """
    for attempt in range(max_retries):
        try:
            logger.info(f"Polling for result, attempt {attempt+1}/{max_retries}")
            fetch_response = requests.post(fetch_url, json={"key": api_key})
            fetch_response.raise_for_status()
            fetch_data = fetch_response.json()
            
            if fetch_data.get('status') == 'success' and 'output' in fetch_data and fetch_data['output']:
                # Get the image URL from the output array
                image_url = fetch_data['output'][0]
                logger.info(f"Image URL: {image_url}")
                return process_image_url(image_url)
            
            elif fetch_data.get('status') == 'processing':
                # Still processing, wait and retry
                logger.info("Image still processing, waiting before next attempt")
                time.sleep(initial_wait)
                continue
            
            else:
                # Unexpected response
                raise ValueError(f"Unexpected fetch response: {fetch_data}")
        
        except Exception as e:
            logger.warning(f"Fetch attempt {attempt+1} failed: {str(e)}")
            time.sleep(3)  # Wait before retrying
    
    # If we get here, all retries have failed
    raise TimeoutError("Maximum retries reached while polling for fashion image result")

def models_fashion(person_image, cloth_image, cloth_type):
    """
    Use ModelsLab fashion API to apply clothing to a person image
    
    Args:
        person_image: Person image as BytesIO, base64 string, or data URL
        cloth_image: Clothing image as BytesIO, base64 string, or data URL
        cloth_type: Type of clothing (e.g., 'upper_body', 'lower_body', 'dress')
        
    Returns:
        BytesIO: A file-like object containing the processed image
        
    Raises:
        ValueError: When API returns unexpected response
        TimeoutError: When max retries are exceeded during polling
    """
    logger.info(f"Processing fashion image with cloth type: {cloth_type}")
    
    try:
        # Convert inputs to BytesIO and encode as base64
        person_bytesio = convert_to_bytesio(person_image)
        cloth_bytesio = convert_to_bytesio(cloth_image)
        
        person_base64 = encode_image_base64(person_bytesio)
        cloth_base64 = encode_image_base64(cloth_bytesio)
        
        # Prepare API request
        url = "https://modelslab.com/api/v6/image_editing/fashion"
        api_key = os.environ.get("MODELSLAB_API_KEY", "")
        
        payload = {
            "key": api_key,
            "prompt": "do not change the person's face. make the cloth fit the person. ",
            "negative_prompt": "Low quality, unrealistic, bad cloth, warped cloth, altered face, anything above the neck",
            "init_image": person_base64,
            "cloth_image": cloth_base64,
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
        result_data = response.json()
        
        # Process response
        if 'status' not in result_data:
            raise ValueError(f"API response missing status field: {result_data}")
            
        # Handle immediate success
        if result_data['status'] == 'success' and 'output' in result_data and result_data['output']:
            # Get the image URL from the output array and process it
            image_url = result_data['output'][0]
            return process_image_url(image_url)
        
        # Handle asynchronous processing
        elif result_data['status'] == 'processing' and 'fetch_result' in result_data:
            fetch_url = result_data.get('fetch_result')
            eta = result_data.get('eta', 5)  # Default to 5 seconds if not provided
            
            logger.info(f"Image processing in background, will fetch from {fetch_url} after {eta} seconds")
            time.sleep(eta)  # Wait for the suggested time before polling
            
            # Poll for results
            return poll_result(fetch_url, api_key)
        
        else:
            raise ValueError(f"Unexpected API response: {result_data}")
        
    except Exception as e:
        logger.error(f"Error in fashion image processing: {str(e)}")
        logger.debug(f"Stack trace:", exc_info=True)
        raise 