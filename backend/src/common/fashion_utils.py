import os
import base64
import requests
import time
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
        BytesIO: A file-like object containing the processed image (in binary format)
    """
    logger.info(f"Processing fashion image with cloth type: {cloth_type}")
    
    try:
        # Handle if person_image or cloth_image is base64 encoded string
        if isinstance(person_image, str) and person_image.startswith('data:image'):
            # Extract base64 content from data URL
            _, base64_content = person_image.split(',', 1)
            init_image_bytes = base64.b64decode(base64_content)
            person_image = BytesIO(init_image_bytes)
        elif isinstance(person_image, str):
            # Assume it's a base64 string without data URL prefix
            init_image_bytes = base64.b64decode(person_image)
            person_image = BytesIO(init_image_bytes)
            
        if isinstance(cloth_image, str) and cloth_image.startswith('data:image'):
            # Extract base64 content from data URL
            _, base64_content = cloth_image.split(',', 1)
            cloth_bytes = base64.b64decode(base64_content)
            cloth_image = BytesIO(cloth_bytes)
        elif isinstance(cloth_image, str):
            # Assume it's a base64 string without data URL prefix
            cloth_bytes = base64.b64decode(cloth_image)
            cloth_image = BytesIO(cloth_bytes)
        
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
        
        # Handle both immediate success and processing status
        if 'status' in result_data:
            if result_data['status'] == 'success' and 'output' in result_data and result_data['output']:
                # Get the image URL from the output array
                image_url = result_data['output'][0]
                
                # Check if the response is already a base64 string
                if image_url.startswith('data:image'):
                    # Extract base64 content from data URL
                    _, base64_content = image_url.split(',', 1)
                    image_bytes = base64.b64decode(base64_content)
                    result = BytesIO(image_bytes)
                    result.seek(0)
                    return result
                
                # Special handling for URLs that end with .base64
                if image_url.endswith('.base64'):
                    # These URLs return data URLs like "data:image/jpeg;base64,..."
                    logger.info(f"Fetching base64 content from URL: {image_url}")
                    response = requests.get(image_url)
                    logger.info(f"Image Response: {response}")
                    response.raise_for_status()
                    
                    # The response text is a data URL, extract the base64 part
                    data_url = response.text
                    if data_url.startswith('data:image'):
                        # Extract just the base64 portion after the comma
                        _, base64_content = data_url.split(',', 1)
                        image_bytes = base64.b64decode(base64_content)
                        
                        # Create a BytesIO object with the binary data
                        result = BytesIO(image_bytes)
                        result.seek(0)
                        return result
                    else:
                        # If not a data URL, try decoding directly
                        try:
                            image_bytes = base64.b64decode(data_url)
                            result = BytesIO(image_bytes)
                            result.seek(0)
                            return result
                        except Exception as e:
                            logger.error(f"Failed to decode base64 content: {str(e)}")
                            # Fall back to treating as regular binary content
                            result = BytesIO(response.content)
                            result.seek(0)
                            return result
                
                # Download the image from the URL (normal case)
                image_response = requests.get(image_url)
                image_response.raise_for_status()
                
                # Create a BytesIO object from the downloaded image
                result = BytesIO(image_response.content)
                result.seek(0)
                
                return result
            
            elif result_data['status'] == 'processing' and 'fetch_result' in result_data:
                # Handle asynchronous processing
                fetch_url = result_data.get('fetch_result')
                eta = result_data.get('eta', 5)  # Default to 5 seconds if not provided
                
                logger.info(f"Image processing in background, will fetch from {fetch_url} after {eta} seconds")
                
                # Wait for the suggested time before polling
                time.sleep(eta)
                
                # Poll the fetch URL with retries
                max_retries = 100
                api_key = os.environ.get("MODELSLAB_API_KEY", "")
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
                            
                            # Check if the response is already a base64 string
                            if image_url.startswith('data:image'):
                                # Extract base64 content from data URL
                                _, base64_content = image_url.split(',', 1)
                                image_bytes = base64.b64decode(base64_content)
                                result = BytesIO(image_bytes)
                                result.seek(0)
                                return result
                            
                            # Special handling for URLs that end with .base64
                            if image_url.endswith('.base64'):
                                # These URLs return data URLs like "data:image/jpeg;base64,..."
                                logger.info(f"Fetching base64 content from URL: {image_url}")
                                response = requests.get(image_url)
                                logger.info(f"Image Response: {response}")
                                response.raise_for_status()
                                
                                # The response text is a data URL, extract the base64 part
                                data_url = response.text
                                if data_url.startswith('data:image'):
                                    # Extract just the base64 portion after the comma
                                    _, base64_content = data_url.split(',', 1)
                                    image_bytes = base64.b64decode(base64_content)
                                    
                                    # Create a BytesIO object with the binary data
                                    result = BytesIO(image_bytes)
                                    result.seek(0)
                                    return result
                                else:
                                    # If not a data URL, try decoding directly
                                    try:
                                        image_bytes = base64.b64decode(data_url)
                                        result = BytesIO(image_bytes)
                                        result.seek(0)
                                        return result
                                    except Exception as e:
                                        logger.error(f"Failed to decode base64 content: {str(e)}")
                                        # Fall back to treating as regular binary content
                                        result = BytesIO(response.content)
                                        result.seek(0)
                                        return result
                            
                            # Download the image from the URL (normal case)
                            image_response = requests.get(image_url)
                            image_response.raise_for_status()
                            
                            # Create a BytesIO object from the downloaded image
                            result = BytesIO(image_response.content)
                            result.seek(0)
                            
                            return result
                        
                        elif fetch_data.get('status') == 'processing':
                            # Still processing, wait and retry
                            logger.info("Image still processing, waiting before next attempt")
                            time.sleep(10)  # Wait 10 seconds between polls
                            continue
                        
                        else:
                            # Unexpected response
                            raise ValueError(f"Unexpected fetch response: {fetch_data}")
                    
                    except Exception as e:
                        logger.warning(f"Fetch attempt {attempt+1} failed: {str(e)}")
                        time.sleep(3)  # Wait before retrying
                
                # If we get here, all retries have failed
                raise TimeoutError("Maximum retries reached while polling for fashion image result")
            
            else:
                raise ValueError(f"Unexpected API response: {result_data}")
        else:
            raise ValueError(f"API response missing status field: {result_data}")
        
    except Exception as e:
        logger.error(f"Error in fashion image processing: {str(e)}")
        logger.debug(f"Stack trace:", exc_info=True)
        raise 