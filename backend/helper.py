import os
import base64
import requests
from io import BytesIO
from PIL import Image
import logging
import openai

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

theme_descriptions = [
    "Harry Potter: Magical wizarding world with wands, spells, and Hogwarts castle in Studio Ghibli animation style",
    "Star Wars: Futuristic space battles with lightsabers and the Force in Art Deco poster style",
    "Pride and Prejudice: Regency era England with elegant ballrooms and countryside estates in Impressionist painting style",
    "Blade Runner: Dystopian cyberpunk city with neon lights and flying cars in Vaporwave digital art style",
    "Ancient Egypt: Pyramids, sphinxes, and hieroglyphics along the Nile River in Art Nouveau illustration style",
    "The Matrix: Digital reality with green code and agents in black suits in Pixel Art style",
    "Lord of the Rings: Fantasy realm with elves, dwarves, and epic mountain landscapes in Romantic oil painting style",
    "Jurassic Park: Prehistoric setting with dinosaurs in a tropical environment in Photorealistic digital art style",
    "1920s Jazz Age: Art deco style, flappers, and speakeasies in prohibition America in Vintage poster art style",
    "Avatar: Alien world with floating mountains and bioluminescent flora in Luminism painting style",
    "Victorian London: Foggy streets, gas lamps, and Gothic architecture in Dark Academia illustration style",
    "Mad Max: Post-apocalyptic wasteland with modified vehicles and dust storms in Grunge comic book style",
    "Inception: Dream-like cityscapes with impossible architecture and physics in Surrealist painting style",
    "Ancient Rome: Colosseum, togas, and marble statues during the height of the empire in Neoclassical art style",
    "The Great Gatsby: Lavish 1920s parties with champagne towers and luxury cars in Art Deco illustration style",
    "Interstellar: Space exploration with realistic spacecraft and exotic planets in Sci-Fi concept art style",
    "Medieval Fantasy: Castles, knights, dragons, and magical forests in Pre-Raphaelite painting style",
    "Samurai Japan: Edo period with cherry blossoms, katanas, and traditional architecture in Ukiyo-e woodblock print style",
    "The Wild West: Dusty frontier towns, cowboys, and desert landscapes in American Frontier painting style",
    "Atlantis: Underwater civilization with ancient technology and sea creatures in Watercolor illustration style",
    "Steampunk: Victorian era with brass gadgets, airships, and mechanical contraptions in Technical drawing style",
    "Renaissance Italy: Art, architecture, and culture during the time of Da Vinci in Renaissance fresco style",
    "Noir Detective: 1940s crime drama with shadows, rain-slicked streets, and fedoras in Black and white film noir style",
    "Mayan Civilization: Ancient temples, jungles, and astronomical knowledge in Mesoamerican codex style",
    "Cyberpunk City: Neon-lit streets with high-tech gadgets and corporate dystopia in Synthwave digital art style",
    "Fairy Tale Forest: Enchanted woods with magical creatures and hidden cottages in Disney animation style",
    "Space Opera: Vast galactic empires with diverse alien species in Retro sci-fi pulp magazine style",
    "Underwater Seascape: Colorful coral reefs and exotic sea creatures in Pointillist painting style",
    "Haunted Mansion: Creepy Victorian house with ghosts and supernatural elements in Gothic horror illustration style",
    "Superhero Universe: Masked vigilantes with superpowers in Comic book pop art style",
]


def process_image_with_theme(image_file, user_description, theme_description):
    """
    Process an image with OpenAI APIs:
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
                            "text": f"Describe this image in detail. User says it is: {user_description}"
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
        logger.info(f"Received AI description: {ai_description[:100]}...")
        
        # Step 2: Generate new image based on description and theme
        # Combine AI description with theme
        generation_prompt = f"Create an image based on this description: {ai_description}. Style it with this theme: {theme_description}"
        
        logger.info("Requesting image generation from OpenAI")
        dalle_response = client.images.generate(
            model="dall-e-3",
            prompt=generation_prompt,
            n=1,
            size="1024x1024"
        )
        
        # Get the generated image URL
        image_url = dalle_response.data[0].url
        
        # Download the generated image
        logger.info("Downloading generated image")
        image_response = requests.get(image_url)
        image_response.raise_for_status()
        
        # Return image as BytesIO object
        result = BytesIO(image_response.content)
        return result
        
    except Exception as e:
        logger.error(f"Error in process_image_with_theme: {str(e)}")
        raise
