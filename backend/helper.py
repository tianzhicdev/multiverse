import os
import base64
import requests
import json
from io import BytesIO
from PIL import Image
import logging
import openai
from db import execute_query

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

theme_descriptions = [
    {
        "name": "Harry Potter",
        "description": "Magical wizarding world with wands, spells, and Hogwarts castle in Studio Ghibli animation style"
    },
    {
        "name": "Star Wars",
        "description": "Futuristic space battles with lightsabers and the Force in Art Deco poster style"
    },
    {
        "name": "Blade Runner",
        "description": "Dystopian cyberpunk city with neon lights and flying cars in Vaporwave digital art style"
    },
    {
        "name": "Ancient Egypt",
        "description": "Pyramids, sphinxes, and hieroglyphics along the Nile River in Art Nouveau illustration style"
    },
    {
        "name": "The Matrix",
        "description": "Digital reality with green code and agents in black suits in Pixel Art style"
    },
    {
        "name": "Lord of the Rings",
        "description": "Fantasy realm with elves, dwarves, and epic mountain landscapes in Romantic oil painting style"
    },
    {
        "name": "Jurassic Park",
        "description": "Prehistoric setting with dinosaurs in a tropical environment in Photorealistic digital art style"
    },
    {
        "name": "Avatar",
        "description": "Alien world with floating mountains and bioluminescent flora in Luminism painting style"
    },
    {
        "name": "Victorian London",
        "description": "Foggy streets, gas lamps, and Gothic architecture in Dark Academia illustration style"
    },
    {
        "name": "Mad Max",
        "description": "Post-apocalyptic wasteland with modified vehicles and dust storms in Grunge comic book style"
    },
    {
        "name": "Inception",
        "description": "Dream-like cityscapes with impossible architecture and physics in Surrealist painting style"
    },
    {
        "name": "Ancient Rome",
        "description": "Colosseum, togas, and marble statues during the height of the empire in Neoclassical art style"
    },
    {
        "name": "Interstellar",
        "description": "Space exploration with realistic spacecraft and exotic planets in Sci-Fi concept art style"
    },
    {
        "name": "Samurai Japan",
        "description": "Edo period with cherry blossoms, katanas, and traditional architecture in Ukiyo-e woodblock print style"
    },
    {
        "name": "The Wild West",
        "description": "Dusty frontier towns, cowboys, and desert landscapes in American Frontier painting style"
    },
    {
        "name": "Steampunk",
        "description": "Victorian era with brass gadgets, airships, and mechanical contraptions in Technical drawing style"
    },
    {
        "name": "Renaissance Italy",
        "description": "Art, architecture, and culture during the time of Da Vinci in Renaissance fresco style"
    },
    {
        "name": "Mayan Civilization",
        "description": "Ancient temples, jungles, and astronomical knowledge in Mesoamerican codex style"
    },
    {
        "name": "Cyberpunk City",
        "description": "Neon-lit streets with high-tech gadgets and corporate dystopia in Synthwave digital art style"
    },
    {
        "name": "Fairy Tale Forest",
        "description": "Enchanted woods with magical creatures and hidden cottages in Disney animation style"
    },
]


def image_gen(prompt, model_type="openai"):
    """
    Generate an image using either ModelLabs, OpenAI, or Pollinations.ai based on the specified model type.
    
    Args:
        prompt: The text prompt to generate the image
        model_type: The model type to use ('modelslab', 'openai', or 'pollinations')
        
    Returns:
        BytesIO: A file-like object containing the generated image
    """
    try:
        # Log the model type and prompt being used for image generation
        logger.info(f"Generating image with model: {model_type}")
        logger.info(f"Using prompt: {prompt}")
        if model_type.lower() == "modelslab":
            # ModelLabs implementation
            url = "https://modelslab.com/api/v6/realtime/text2img"
            
            payload = json.dumps({
                "key": os.environ.get("MODELSLAB_API_KEY", ""),
                "prompt": prompt,
                "negative_prompt": "bad quality",
                "width": "1024",
                "height": "1024",
                "safety_checker": False,
                "seed": None,
                "samples": 1,
                "base64": False,
                "webhook": None,
                "track_id": None
            })
            
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
                raise Exception(f"ModelLabs image generation failed: {response.text}")
                
        elif model_type.lower() == "openai":
            # OpenAI implementation
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
        
        elif model_type.lower() == "pollinations":
            # Pollinations.ai implementation
            # URL encode the prompt for use in the URL path
            encoded_prompt = requests.utils.quote(prompt)
            url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?height=1024&nologo=true&model=turbo"
            
            # Make a direct GET request to the API
            response = requests.get(url)
            response.raise_for_status()
            
            # Return image as BytesIO object
            return BytesIO(response.content)
            
        else:
            raise ValueError(f"Unsupported model type: {model_type}. Must be 'modelslab', 'openai', or 'pollinations'")
            
    except Exception as e:
        logger.error(f"Error in image_gen: {str(e)}")
        raise

def process_image_with_theme(image_file, user_description, theme_description):
    """
    Process an image with AI vision and generation APIs:
    1. First get a description of the image using Vision API
    2. Then generate a new image based on the description and theme
    
    Args:
        image_file: The input image file object
        user_description: User's description of the image
        theme_description: Description of the theme to apply
        
    Returns:
        BytesIO: A file-like object containing the generated image
    """
    try:
        # Check if OpenAI API key is configured
        api_key = os.environ.get("OPENAI_API_KEY")
        if not api_key:
            raise ValueError("OPENAI_API_KEY environment variable not set")
        
        # Configure OpenAI client
        client = openai.OpenAI(api_key=api_key)
        
        # Convert image to base64 for API
        img = Image.open(image_file)
        buffered = BytesIO()
        img.save(buffered, format=img.format or "JPEG")
        encoded_image = base64.b64encode(buffered.getvalue()).decode("utf-8")
        
        # Step 1: Get description from OpenAI Vision API
        logger.info("Requesting image description from OpenAI")
        vision_response = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": f"Analyze this image and provide a detailed description that incorporates the theme: {theme_description}. Take into account the user's description: {user_description}. Create clothing, accessories, and visual elements in your description that aligns with the theme. Use less than 150 words."
                        },
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/{img.format.lower() if img.format else 'jpeg'};base64,{encoded_image}"
                            }
                        }
                    ]
                }
            ],
            max_tokens=500
        )
        
        # Extract the description
        ai_description = vision_response.choices[0].message.content
        
        # Step 2: Generate new image based on description and theme
        # Combine AI description with theme
        generation_prompt = f"{ai_description}"

        # Get model type from environment variable
        model_type = os.environ.get("MODEL_TYPE", "openai")
        
        # Use image_gen function to generate the image
        return image_gen(generation_prompt, model_type)
        
    except Exception as e:
        logger.error(f"Error in process_image_with_theme: {str(e)}")
        raise

def use_credits(user_id, credits):
    """
    Deduct credits from a user's account.
    
    Args:
        user_id: The user's ID
        credits: Number of credits to deduct
        
    Returns:
        bool: True if successful, False if insufficient credits
    """
    try:
        # First check if the user has enough credits
        query = "SELECT credits FROM users WHERE user_id = %s"
        result = execute_query(query, (user_id,))
        
        if not result:
            logger.error(f"User with ID {user_id} not found")
            return False
        
        logger.info(f"use_credits db result: {result}")
            
        current_credits = result[0][0]
        
        if current_credits < credits:
            logger.info(f"User {user_id} has insufficient credits: {current_credits} < {credits}")
            return False
            
        # Deduct credits from the user's account
        query = "UPDATE users SET credits = credits - %s WHERE user_id = %s RETURNING credits"
        update_result = execute_query(query, (credits, user_id))

        return update_result == 1
        
    except Exception as e:
        logger.error(f"Error in use_credits: {str(e)}")
        return False

def init_user(user_id):
    """
    Initialize a new user with 10 credits in the database.
    
    Args:
        user_id: The user's ID
        
    Returns:
        bool: True if successful, False if user already exists or on error
    """
    try:
        # Check if the user already exists
        query = "SELECT user_id FROM users WHERE user_id = %s"
        result = execute_query(query, (user_id,))
        
        if result:
            logger.info(f"User with ID {user_id} already exists")
            return False
            
        # Insert new user with 10 credits
        query = "INSERT INTO users (user_id, credits) VALUES (%s, %s) RETURNING user_id, credits"
        result = execute_query(query, (user_id, 10))
        logger.info(f"init_user db result: {result}")
        
        if result == 1:
            logger.info(f"Created new user {user_id} with 10 credits")
            return True
        else:
            logger.error(f"Failed to create user {user_id}")
            return False
            
    except Exception as e:
        logger.error(f"Error in init_user: {str(e)}")
        return False

def get_themes(user_id, num):
    """
    Get a specified number of themes from the database.
    
    Args:
        user_id: The user's ID (not used currently)
        num: Number of themes to return
        
    Returns:
        list: List of theme IDs and names from the database
    """
    try:
        # Query to get theme IDs and names from the database
        query = "SELECT id, name FROM themes ORDER BY created_at DESC LIMIT %s"
        result = execute_query(query, (num,))
        
        # Extract IDs and names from result
        themes = [{"id": row[0], "name": row[1]} for row in result] if result else []
        
        logger.info(f"Retrieved {len(themes)} themes from database")
        return themes
    except Exception as e:
        logger.error(f"Error in get_themes: {str(e)}")
        return []
