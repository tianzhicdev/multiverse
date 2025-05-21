import os
import base64
import requests
import json
from io import BytesIO
from PIL import Image
import logging
from src.common.logging_config import setup_logger
import openai
from src.common.db import execute_query
from src.bg.image_generator import image_gen, generate_with_openai_image_1, generate_with_stability, generate_with_replicate

# Configure logger using centralized logging config
logger = setup_logger(__name__, 'helper.log')

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
    MUST NOT use realistic style. MUST NOT display explicit nudity.
    """
    
    result = generate_with_openai_image_1(img2img_prompt, image_file)
    if result:
        image, engine = result
        return image, engine
    
    # result = generate_with_stability(img2img_prompt, image_file)
    # if result:
    #     image, engine = result
    #     return image, engine
    
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
                            MUST NOT use realistic style. MUST NOT display explicit nudity.
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

def use_credits(user_id, credits, reason="Unspecified use"):
    """
    Deduct credits from a user's account and record the transaction.
    
    Args:
        user_id: The user's ID
        credits: Number of credits to deduct
        reason: Reason for the credit deduction
        
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
        
        if update_result != 1:
            logger.error(f"Failed to update credits for user {user_id}")
            return False
            
        # Record the transaction
        transaction_query = "INSERT INTO transactions (user_id, credit, reason) VALUES (%s, %s, %s)"
        transaction_result = execute_query(transaction_query, (user_id, -credits, reason))
        
        if transaction_result != 1:
            logger.error(f"Failed to record transaction for user {user_id}")
            # If transaction recording fails, try to revert the credits change
            revert_query = "UPDATE users SET credits = credits + %s WHERE user_id = %s"
            execute_query(revert_query, (credits, user_id))
            return False
            
        return True
        
    except Exception as e:
        logger.error(f"Error in use_credits: {str(e)}")
        return False

def add_credits(user_id, credits, reason="Unspecified addition", transaction_id=None):
    """
    Add credits to a user's account and record the transaction.
    
    Args:
        user_id: The user's ID
        credits: Number of credits to add
        reason: Reason for adding credits
        transaction_id: Optional transaction ID to use instead of auto-generated UUID
        
    Returns:
        bool: True if successful, False if user not found or on error
    """
    try:
        # First check if the user exists
        query = "SELECT user_id FROM users WHERE user_id = %s"
        result = execute_query(query, (user_id,))
        
        if not result:
            logger.error(f"User with ID {user_id} not found")
            # Create user if they don't exist
            return init_user(user_id, reason)
        
        # Record the transaction first
        if transaction_id:
            transaction_query = "INSERT INTO transactions (id, user_id, credit, reason) VALUES (%s, %s, %s, %s) ON CONFLICT (id, user_id) DO NOTHING"
            transaction_result = execute_query(transaction_query, (transaction_id, user_id, credits, reason))
        else:
            transaction_query = "INSERT INTO transactions (user_id, credit, reason) VALUES (%s, %s, %s)"
            transaction_result = execute_query(transaction_query, (user_id, credits, reason))
        
        if transaction_result != 1:
            logger.error(f"Failed to record transaction for user {user_id}")
            return False
            
        # Only update user credits after successful transaction recording
        query = "UPDATE users SET credits = credits + %s WHERE user_id = %s RETURNING credits"
        update_result = execute_query(query, (credits, user_id))
        
        if update_result != 1:
            logger.error(f"Failed to add credits to user {user_id}")
            return False
            
        return True
        
    except Exception as e:
        logger.error(f"Error in add_credits: {str(e)}")
        return False

def init_user(user_id, reason="User initialization"):
    """
    Initialize a new user with 100 credits in the database.
    
    Args:
        user_id: The user's ID
        reason: Reason for initializing the user
        
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
            
        # Insert new user with 0 credits
        query = "INSERT INTO users (user_id, credits) VALUES (%s, %s) RETURNING user_id"
        result = execute_query(query, (user_id, 0))
        
        if result == 1:
            logger.info(f"Created new user {user_id}")
            # Add 100 initial credits using add_credits function
            return add_credits(user_id, 30, f"Initial credits", None)
        else:
            logger.error(f"Failed to create user {user_id}")
            return False
            
    except Exception as e:
        logger.error(f"Error in init_user: {str(e)}")
        return False

def get_themes(user_id, num, album=None, app_name=None):
    """
    Get a specified number of themes from the database.
    If an album is specified, themes will be fetched from that album first.
    If there are not enough themes in the album, random themes will be used to fill the remainder.
    
    The album and app_name parameters are independent:
    - album controls where themes are fetched from (user's album or random)
    - app_name determines theme type filtering (art or product)
    
    Args:
        user_id: The user's ID
        num: Number of themes to return
        album: (Optional) Album name to fetch themes from
        app_name: (Optional) Application name - "multiverse" for art themes, "multiverse_shopping" for product themes
        
    Returns:
        list: List of theme IDs and names from the database
    """
    try:
        themes = []
        
        # Determine theme type based on app_name
        theme_type = None
        if app_name == "multiverse":
            theme_type = "art"
            logger.info(f"Filtering themes by type: 'art' for app '{app_name}'")
        elif app_name == "multiverse_shopping":
            theme_type = "product"
            logger.info(f"Filtering themes by type: 'product' for app '{app_name}'")
        else:
            logger.info(f"No theme type filtering applied for app '{app_name}'")
            raise ValueError(f"Invalid app name: '{app_name}'")
        
        # If album is specified and not default, fetch themes from that album first
        if album and album != "default":
            # Query to get theme IDs and names from the album
            params = [user_id]
            where_clause = "a.user_id = %s"
            
            if theme_type:
                where_clause += " AND t.type = %s"
                params.append(theme_type)
                logger.info(f"Applying theme type filter '{theme_type}' to album query")
                
            album_query = f"""
                SELECT t.id, t.name
                FROM albums a
                JOIN themes t ON a.theme_id = t.id
                WHERE {where_clause}
                ORDER BY RANDOM()
            """
            
            album_result = execute_query(album_query, params)
            
            # Extract IDs and names from album result
            if album_result:
                themes = [{"id": row[0], "name": row[1]} for row in album_result]
                logger.info(f"Retrieved {len(themes)} themes from album '{album}'" + (f" with type '{theme_type}'" if theme_type else ""))
            
            # If we already have enough themes from the album, return them
            if len(themes) >= int(num):
                return themes[:int(num)]
                
            # If we don't have enough themes, get more random ones to fill the gap
            remaining = int(num) - len(themes)
            if remaining > 0:
                # Exclude themes we already have
                theme_ids = [theme["id"] for theme in themes]
                
                # Build the query with appropriate filters
                where_clauses = ["1=1"]
                params = []
                
                if theme_ids:
                    exclude_clause = "id NOT IN ({})".format(','.join(['%s'] * len(theme_ids)))
                    where_clauses.append(exclude_clause)
                    params.extend(theme_ids)
                
                if theme_type:
                    where_clauses.append("type = %s")
                    params.append(theme_type)
                    logger.info(f"Applying theme type filter '{theme_type}' to supplementary random themes query")
                
                params.append(remaining)
                
                random_query = f"SELECT id, name FROM themes WHERE {' AND '.join(where_clauses)} ORDER BY RANDOM() LIMIT %s"
                    
                random_result = execute_query(random_query, params)
                if random_result:
                    random_themes = [{"id": row[0], "name": row[1]} for row in random_result]
                    themes.extend(random_themes)
                    logger.info(f"Added {len(random_themes)} random themes to complement album themes" + (f" with type '{theme_type}'" if theme_type else ""))
        else:
            # If no album specified or it's the default album, get random themes
            if theme_type:
                query = "SELECT id, name FROM themes WHERE type = %s ORDER BY RANDOM() LIMIT %s"
                params = (theme_type, num)
                logger.info(f"Getting random themes with type filter '{theme_type}'")
            else:
                query = "SELECT id, name FROM themes ORDER BY RANDOM() LIMIT %s"
                params = (num,)
                logger.info("Getting random themes with no type filter")
            
            result = execute_query(query, params)
            
            # Extract IDs and names from result
            if result:
                themes = [{"id": row[0], "name": row[1]} for row in result]
                logger.info(f"Retrieved {len(themes)} random themes" + (f" with type '{theme_type}'" if theme_type else ""))
        
        return themes
    except Exception as e:
        logger.error(f"Error in get_themes: {str(e)}")
        return []
