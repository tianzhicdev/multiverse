import os
import json
import requests
import logging
from io import BytesIO
import openai
import base64
from pyrate_limiter import Duration, Rate, Limiter, BucketFullException
import tempfile
from PIL import Image 
# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

# Configure rate limiters
openai_rate = Rate(5, Duration.MINUTE)
modelslab_rate = Rate(500, Duration.MINUTE)
pollinations_rate = Rate(500, Duration.MINUTE)
openai_image1_rate = Rate(9, Duration.MINUTE)  # New rate for GPT Image 1
stability_rate = Rate(150, Duration.SECOND * 10)  # 150 requests per 10 seconds

openai_limiter = Limiter(openai_rate)
modelslab_limiter = Limiter(modelslab_rate)
pollinations_limiter = Limiter(pollinations_rate)
openai_image1_limiter = Limiter(openai_image1_rate)  # New limiter for GPT Image 1
stability_limiter = Limiter(stability_rate)  # Limiter for Stability AI

def generate_with_stability(prompt, image_file):
    """
    Generate an image using Stability AI's control structure API.
    
    Args:
        prompt: The text prompt for image generation
        image_file: The input image file object
        
    Returns:
        tuple: (BytesIO, str) - A file-like object containing the generated image and the engine name
    """
    try:
        # Try to acquire a rate limit token
        stability_limiter.try_acquire("stability_image_gen")
        logger.info("Generating image with Stability AI")
        
        # Check if Stability AI API key is configured
        api_key = os.environ.get("STABILITY_API_KEY")
        if not api_key:
            raise ValueError("STABILITY_API_KEY environment variable not set")
        
        # Make API request to Stability AI
        response = requests.post(
            "https://api.stability.ai/v2beta/stable-image/control/structure",
            headers={
                "authorization": f"Bearer {api_key}",
                "accept": "image/*"
            },
            files={
                "image": image_file
            },
            data={
                "prompt": prompt,
                "control_strength": 0.7,
                "output_format": "webp"
            },
        )
        
        # Handle response
        if response.status_code == 200:
            # Create a BytesIO object from the response content
            image_data = BytesIO(response.content)
            engine = "stability-structure"
            return image_data, engine
        else:
            logger.error(f"Stability AI API error: {response.status_code}, {response.text}")
            raise Exception(f"Stability AI API error: {response.text}")
            
    except BucketFullException:
        logger.warning("Stability AI rate limit reached")
        return None
    except Exception as e:
        logger.error(f"Error in generate_with_stability: {str(e)}")
        raise



def generate_with_openai_image_1(prompt, image_file):
    """Generate image using OpenAI's GPT-image-1 model with image editing"""
    try:
        openai_image1_limiter.try_acquire("openai_image1_gen")
        logger.info("Generating image with OpenAI image 1")
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable not set")
            
        # Configure OpenAI client
        client = openai.OpenAI(api_key=api_key)
        
        # Generate image with GPT-image-1
        img = Image.open(image_file)
        
        # Create a temporary file with JPEG extension to ensure correct mimetype
        with tempfile.NamedTemporaryFile(suffix='.jpeg', delete=False) as temp_file:
            # Save the image as JPEG format
            if img.mode == 'RGBA':
                # Convert RGBA to RGB for JPEG compatibility
                img = img.convert('RGB')
            img.save(temp_file, format="JPEG", quality=95)
            temp_file_path = temp_file.name
        
        try:
            # Open the temporary file with proper mimetype for the API call
            with open(temp_file_path, 'rb') as image:
                result = client.images.edit(
                    model="gpt-image-1",
                    image=image,
                    prompt=prompt
                )
        finally:
            # Clean up the temporary file
            if os.path.exists(temp_file_path):
                os.unlink(temp_file_path)

        # Get the generated image data
        if hasattr(result.data[0], 'b64_json'):
            image_base64 = result.data[0].b64_json
            image_bytes = base64.b64decode(image_base64)
            return BytesIO(image_bytes), "image1"
        elif hasattr(result.data[0], 'url'):
            # Download the generated image if URL is provided instead
            image_url = result.data[0].url
            image_response = requests.get(image_url)
            image_response.raise_for_status()
            return BytesIO(image_response.content), "image1"
        else:
            raise ValueError("No image data found in OpenAI response")
    
    except BucketFullException:
        logger.warning("OpenAI rate limit reached, falling back to ModelsLab")
        return None
    except Exception as e:
        logger.error(f"Error in OpenAI image edit: {str(e)}")
        return None


def generate_with_openai(prompt):
    """Generate image using OpenAI's DALL-E"""
    try:
        openai_limiter.try_acquire("openai_image_gen")
        logger.info("Generating image with OpenAI")
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable not set")
            
        # Configure OpenAI client
        client = openai.OpenAI(api_key=api_key)
        
        # Generate image with DALL-E
        dalle_response = client.images.generate(
            model="dall-e-3",
            prompt=prompt,
            n=1,
            size="1024x1024"
        )
        
        # Get the generated image URL
        image_url = dalle_response.data[0].url
        
        # Download the generated image
        image_response = requests.get(image_url)
        image_response.raise_for_status()
        
        # Return image as BytesIO object
        return BytesIO(image_response.content)
    except BucketFullException:
        logger.warning("OpenAI rate limit reached, falling back to ModelsLab")
        return None
    except Exception as e:
        logger.error(f"Error in OpenAI image generation: {str(e)}")
        return None

def generate_with_modelslab(prompt):
    """Generate image using ModelsLab"""
    try:
        modelslab_limiter.try_acquire("modelslab_image_gen")
        logger.info("Generating image with ModelsLab")
        url = "https://modelslab.com/api/v6/realtime/text2img"
        
        payload = json.dumps({
            "key": os.environ.get("MODELSLAB_API_KEY", ""),
            "model_id": "midjourney",
            "prompt": prompt,
            "width": "1024",
            "height": "1024",
            "safety_checker": True,
            "seed": None,
            "samples": 1,
            "base64": False,
            "webhook": None,
            "track_id": None,
            "lora_model": "all-disney-princess-xl-lo",
            # "enhance_style": "pixel-art",
        })
        logger.info(f"ModelsLab payload: {payload}")
        
        headers = {
            'Content-Type': 'application/json'
        }
        
        response = requests.request("POST", url, headers=headers, data=payload)
        response_data = response.json()
        
        if response_data.get("status") == "success":
            # Download the generated image
            image_url = response_data.get("output")[0]
            image_response = requests.get(image_url)
            image_response.raise_for_status()
            
            # Return image as BytesIO object
            return BytesIO(image_response.content)
        else:
            logger.error(f"ModelLabs image generation failed: {response.text}")
            return None
    except BucketFullException:
        logger.warning("ModelsLab rate limit reached, falling back to Pollinations")
        return None
    except Exception as e:
        logger.error(f"Error in ModelsLab image generation: {str(e)}")
        return None

def generate_with_pollinations(prompt):
    """Generate image using Pollinations.ai"""
    try:
        pollinations_limiter.try_acquire("pollinations_image_gen")
        logger.info("Generating image with Pollinations")
        # URL encode the prompt for use in the URL path
        encoded_prompt = requests.utils.quote(prompt)
        url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?height=1024&nologo=true&model=turbo"
        
        # Make a direct GET request to the API
        response = requests.get(url)
        response.raise_for_status()
        
        # Return image as BytesIO object
        return BytesIO(response.content)
    except BucketFullException:
        logger.warning("Pollinations rate limit reached, all services exhausted")
        return None
    except Exception as e:
        logger.error(f"Error in Pollinations image generation: {str(e)}")
        return None

def image_gen(prompt):
    """
    Generate an image using either ModelLabs, OpenAI, or Pollinations.ai based on the specified model type.
    Implements fallback logic if rate limits are reached.
    
    Args:
        prompt: The text prompt to generate the image
        
    Returns:
        tuple: (BytesIO, str) - A file-like object containing the generated image and the engine name
    """
    try:
        logger.info(f"Using prompt: {prompt}")

        # Try OpenAI first
        result = generate_with_openai(prompt)
        if result:
            return result, "openai"
        
        # If OpenAI fails, fall back to ModelsLab
        logger.info("OpenAI image generation failed, falling back to ModelsLab")
        result = generate_with_modelslab(prompt)
        if result:
            return result, "modelslab"
            
        # If ModelsLab fails, fall back to Pollinations
        logger.info("ModelsLab image generation failed, falling back to Pollinations")
        result = generate_with_pollinations(prompt)
        if result:
            return result, "pollinations"
        
        # If all providers fail
        logger.error("All image generation services failed or rate limited")
        raise Exception("All image generation services failed or rate limited")

    except Exception as e:
        logger.error(f"Error in image_gen: {str(e)}")
        raise 