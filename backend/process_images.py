#!/usr/bin/env python3
"""
Image Processing Worker Script

This script processes pending image generation requests in the database.
It should be run as a background process or scheduled task.
"""

import logging
import os
import time
from io import BytesIO
from db import execute_query
from helper import process_image_with_theme, theme_descriptions
from dotenv import load_dotenv
import random

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def get_pending_requests(limit=10):
    """Get a batch of pending image requests to process."""
    query = """
        SELECT ir.request_id, ir.source_image_id, ir.theme_id, ir.result_image_id, ir.user_id,
               ir.user_description, i.data, i.mime_type
        FROM image_requests ir
        JOIN images i ON ir.source_image_id = i.id
        WHERE ir.status = 'pending'
        ORDER BY ir.created_at
        LIMIT %s
    """
    return execute_query(query, (limit,))

def get_theme_description(theme_id):
    """Get the theme description for a given theme ID."""
    # In a real implementation, this would fetch from the database
    # For now, we'll extract the theme index from the ID and use the list
    try:
        if theme_id.startswith('theme_'):
            index = int(theme_id.split('_')[1])
            if 0 <= index < len(theme_descriptions):
                return theme_descriptions[index]
    except (ValueError, IndexError):
        pass
    
    # Return a default theme if we couldn't find the specified one
    return random.choice(theme_descriptions)

def process_request(request):
    """Process a single image request."""
    request_id, source_image_id, theme_id, result_image_id, user_id, user_description, image_data, mime_type = request
    
    try:
        logger.info(f"Processing request {request_id} with theme {theme_id}")
        
        # Update status to processing
        query = "UPDATE image_requests SET status = 'processing' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))
        
        # Create a BytesIO object from the image data
        image_file = BytesIO(image_data)
        
        # Get the theme description
        theme_description = get_theme_description(theme_id)
        
        # Process the image with the theme
        result_image = process_image_with_theme(
            image_file,
            user_description or '',
            theme_description
        )
        
        # Save the result image to the database
        result_data = result_image.getvalue()
        query = """
            INSERT INTO images (id, data, mime_type, created_at)
            VALUES (%s, %s, %s, NOW())
            ON CONFLICT (id) DO UPDATE 
            SET data = EXCLUDED.data, 
                mime_type = EXCLUDED.mime_type
        """
        execute_query(query, (result_image_id, result_data, 'image/jpeg'))
        
        # Update the request status to completed
        query = "UPDATE image_requests SET status = 'completed' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))
        
        logger.info(f"Successfully processed request {request_id} with theme {theme_id}")
        return True
        
    except Exception as e:
        logger.error(f"Error processing request {request_id}: {str(e)}")
        
        # Update the request status to failed
        query = "UPDATE image_requests SET status = 'failed', error = %s WHERE result_image_id = %s"
        execute_query(query, (str(e), result_image_id))
        
        return False

def main():
    """Main worker loop."""
    logger.info("Starting image processing worker")
    
    while True:
        try:
            # Get pending requests
            pending_requests = get_pending_requests()
            
            if not pending_requests:
                logger.info("No pending requests found, sleeping...")
                time.sleep(10)  # Sleep for 10 seconds before checking again
                continue
                
            logger.info(f"Found {len(pending_requests)} pending requests")
            
            # Process each request
            for request in pending_requests:
                process_request(request)
                
        except Exception as e:
            logger.error(f"Error in main worker loop: {str(e)}")
            time.sleep(30)  # Sleep longer if there was an error
            
if __name__ == "__main__":
    main() 