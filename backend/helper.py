import os
import base64
import requests
import json
from io import BytesIO
from PIL import Image
import logging
import openai
from db import execute_query
from image_generator import image_gen, generate_with_openai_image_1, generate_with_stability, generate_with_replicate

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
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




def process_image_to_image(result_image_id, image_file, user_description, theme_description):

    img2img_prompt = f"""
    Generate an image that incorporates the theme: {theme_description}. 
    MUST follow the user's instruction: {user_description}. 
    MUST use precisely the layout of the image, including the main characters/objects and their positions. 
    MUST focus on the main characters/obejcts and critical features of the characters/objects in the image.
    MUST create clothing, accessories, and visual elements in your description that aligns with the theme.
    MAINTAIN the exact layout of the original image. Characters in the foreground must remain in the foreground, and background elements must stay in the background. 
    MUST NOT use realistic style.
    """
    
    result = generate_with_openai_image_1(img2img_prompt, image_file)
    if result:
        image, engine = result
        return image, engine
    
    result = generate_with_stability(img2img_prompt, image_file)
    if result:
        image, engine = result
        return image, engine
    
    result = generate_with_replicate(img2img_prompt, image_file)
    if result:
        image, engine = result
        return image, engine
    else:
        # Fall back to the other image generation method
        image, engine = process_description_to_image(image_file, user_description, theme_description)
    
    return image, engine

def process_description_to_image(image_file, user_description, theme_description):
    """
    Process an image with AI vision and generation APIs:
    1. First get a description of the image using Vision API
    2. Then generate a new image based on the description and theme
    
    Args:
        image_file: The input image file object
        user_description: User's description of the image
        theme_description: Description of the theme to apply
        
    Returns:
        tuple: (BytesIO, str) - A file-like object containing the generated image and the engine name
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

        image_description_prompt = f"""
                            Analyze this image and provide a detailed prompt 
                            that will be used to generate a new image that incorporates 
                            the theme: {theme_description}. 
                            MUST follow the user's instruction: {user_description}. 
                            MUST use precisely the layout of the image, including the main characters/objects and their positions.
                            MUST focus on the main characters/obejcts and critical features of the characters/objects in the image. 
                            MUST create clothing, accessories, and visual elements in your description that aligns with the theme. 
                            MUST NOT use realistic style.
                            MAINTAIN the exact layout of the original image. Characters in the foreground must remain in the foreground, and background elements must stay in the background. Spatial relationships between all elements must be preserved.
                            MUST use less than 200 words."""
        logger.info(f"Image description prompt: {image_description_prompt}")

        vision_response = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "text",
                            "text": image_description_prompt
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
        
        # Use image_gen function to generate the image
        return image_gen(generation_prompt)
        
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
        result = execute_query(query, (user_id, 100))
        logger.info(f"init_user db result: {result}")
        
        if result == 1:
            logger.info(f"Created new user {user_id} with 100 credits")
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
        query = "SELECT id, name FROM themes ORDER BY RANDOM() LIMIT %s"
        result = execute_query(query, (num,))
        
        # Extract IDs and names from result
        themes = [{"id": row[0], "name": row[1]} for row in result] if result else []
        
        logger.info(f"Retrieved {len(themes)} themes from database")
        return themes
    except Exception as e:
        logger.error(f"Error in get_themes: {str(e)}")
        return []
