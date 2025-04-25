#!/usr/bin/env python3
"""
Background Processing Script for Image Requests

This script continually polls the image_requests table for entries with 'new' or 'retry' status,
then processes each request in a separate thread.
"""
        
import logging
import threading
import time
import uuid
from io import BytesIO
from db import execute_query
from dotenv import load_dotenv
import json
from helper import process_image_with_theme
# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def get_pending_requests():
    """Get all image requests with 'new' or 'retry' status."""
    logger.debug("Querying database for pending requests")
    query = """
        SELECT ir.id, ir.request_id, ir.result_image_id, ir.user_id, ir.theme_id
        FROM image_requests ir
        WHERE ir.status IN ('new', 'retry')
        ORDER BY ir.created_at
    """
    results = execute_query(query)
    logger.debug(f"Found {len(results) if results else 0} pending requests")
    return results

def process_request(request_id, result_image_id, user_id, theme_id):
    """Process a single image request in a separate thread."""
    try:
        logger.info(f"Processing request {request_id} with result image {result_image_id}")
        
        # Update status to pending
        logger.debug(f"Updating request {request_id} status to 'pending'")
        query = "UPDATE image_requests SET status = 'pending' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))
        
        # Get source image data and user description from the image_requests table
        logger.debug(f"Getting source image info for request {request_id}")
        source_query = """
            SELECT ir.source_image_id, ir.user_description, i.data, i.mime_type
            FROM image_requests ir
            JOIN images i ON ir.source_image_id = i.id
            WHERE ir.result_image_id = %s
        """
        source_result = execute_query(source_query, (result_image_id,))
        
        if not source_result:
            logger.error(f"Source image not found for request {request_id}")
            raise Exception("Source image not found")
            
        source_image_id, user_description, image_data, mime_type = source_result[0]
        
        # Create a BytesIO object from the source image data
        logger.debug(f"Creating BytesIO object from source image data")
        image_file = BytesIO(image_data)
        
        # Get theme description from the database
        logger.debug(f"Getting theme description for theme_id {theme_id}")
        theme_query = "SELECT theme FROM themes WHERE id = %s"
        theme_result = execute_query(theme_query, (theme_id,))
        
        if not theme_result:
            logger.error(f"Theme not found for theme_id {theme_id}")
            # Use a default theme description if not found
            theme_description = "Create a beautiful artistic image"
        else:
            theme_description = theme_result[0][0]
        
        # Process the image with the selected theme
        logger.debug(f"Processing image with theme for request {request_id}")
        
        result_image = process_image_with_theme(
            image_file,
            user_description or '',
            theme_description
        )
        
        # Save the processed image data to the database
        logger.debug(f"Saving processed image to database for request {request_id}")
        result_data = result_image.getvalue()
        metadata = {"theme_id": theme_id, "process_method": "process_image_with_theme"}
        metadata_json = json.dumps(metadata)
        
        query = """
            INSERT INTO images (id, user_id, data, mime_type, metadata) 
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE 
            SET data = EXCLUDED.data, 
                mime_type = EXCLUDED.mime_type,
                metadata = EXCLUDED.metadata
        """
        execute_query(
            query, 
            (result_image_id, user_id, result_data, 'image/jpeg', metadata_json)
        )
        
        # Update the request status to ready
        logger.debug(f"Updating request {request_id} status to 'ready'")
        query = "UPDATE image_requests SET status = 'ready' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))
        
        logger.info(f"Successfully processed request {request_id} with result image {result_image_id}")
        
    except Exception as e:
        logger.error(f"Error processing request {request_id}: {str(e)}")
        logger.debug(f"Stack trace for request {request_id}:", exc_info=True)
        
        # Update the request status to retry
        logger.debug(f"Setting request {request_id} status to 'retry'")
        query = "UPDATE image_requests SET status = 'retry' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))

def process_request_test(request_id, result_image_id, user_id, theme_id):
    """Process a single image request in a separate thread."""
    try:
        logger.info(f"Processing request {request_id} with result image {result_image_id}")
        
        # Update status to pending
        logger.debug(f"Updating request {request_id} status to 'pending'")
        query = "UPDATE image_requests SET status = 'pending' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))
        
        # Create a real image in the images table
        logger.debug(f"Preparing to insert image for request {request_id}")
        query = """
            INSERT INTO images (id, user_id, data, mime_type, metadata) 
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (id) DO UPDATE 
            SET data = EXCLUDED.data, 
                mime_type = EXCLUDED.mime_type,
                metadata = EXCLUDED.metadata
        """

        # Get an existing image from the database to use as test data
        logger.debug(f"Fetching existing test image from database for request {request_id}")
        fetch_query = "SELECT data, mime_type FROM images LIMIT 1"
        image_result = execute_query(fetch_query)
        
        if not image_result:
            logger.error(f"Test image not found in database")
            raise Exception(f"Test image not found in database")
            
        real_image_data = image_result[0][0]
        mime_type = image_result[0][1]
        logger.debug(f"Using existing image, size: {len(real_image_data)} bytes")
        
        # Insert the image
        metadata = {"theme_id": theme_id, "process_method": "test_existing_image"}
        logger.debug(f"Inserting image into database for request {request_id}")
        metadata_json = json.dumps(metadata)
        execute_query(
            query, 
            (result_image_id, user_id, real_image_data, mime_type, metadata_json)
        )
        
        # Update the request status to ready
        logger.debug(f"Updating request {request_id} status to 'ready'")
        query = "UPDATE image_requests SET status = 'ready' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))
        
        logger.info(f"Successfully processed request {request_id} with result image {result_image_id}")
        
    except Exception as e:
        logger.error(f"Error processing request {request_id}: {str(e)}")
        logger.debug(f"Stack trace for request {request_id}:", exc_info=True)
        
        # Update the request status to retry
        logger.debug(f"Setting request {request_id} status to 'retry'")
        query = "UPDATE image_requests SET status = 'retry' WHERE result_image_id = %s"
        execute_query(query, (result_image_id,))

def request_processor(requests):
    """Process multiple requests, each in its own thread."""
    logger.debug(f"Starting to process {len(requests)} requests")
    threads = []
    
    for request in requests:
        id, request_id, result_image_id, user_id, theme_id = request
        
        # Create and start a new thread for each request
        logger.debug(f"Creating thread for request {request_id}")
        thread = threading.Thread(
            target=process_request,
            args=(request_id, result_image_id, user_id, theme_id)
        )
        thread.start()
        threads.append(thread)
    
    # Wait for all threads to complete
    logger.debug(f"Waiting for {len(threads)} processing threads to complete")
    for thread in threads:
        thread.join()
    logger.debug("All processing threads completed")

def main():
    """Main background process loop."""
    logger.info("Starting background image request processor")
    
    while True:
        try:
            # Get pending requests
            logger.debug("Checking for pending requests")
            pending_requests = get_pending_requests()
            
            if pending_requests:
                logger.info(f"Found {len(pending_requests)} pending requests")
                request_processor(pending_requests)
            else:
                logger.info("No pending requests found, sleeping...")
            
            # Sleep before checking again
            logger.debug("Sleeping for 5 seconds before next check")
            time.sleep(5)
                
        except Exception as e:
            logger.error(f"Error in main background loop: {str(e)}")
            logger.debug("Stack trace for main loop error:", exc_info=True)
            logger.info("Sleeping for 30 seconds after error")
            time.sleep(30)  # Sleep longer if there was an error

if __name__ == "__main__":
    main()
