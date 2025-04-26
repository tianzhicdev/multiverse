#!/usr/bin/env python3
"""
Background Processing Script for Image Requests

This script continually polls the image_requests table for entries with 'new' or 'retry' status,
then processes each request in a separate thread.
"""
        
import logging
import threading
import time
from io import BytesIO
from db import execute_query
from dotenv import load_dotenv
import json
from helper import process_image_to_image
# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger(__name__)

def update_request_status(result_image_id, status):
    """Update the status of an image request."""
    query = "UPDATE image_requests SET status = %s WHERE result_image_id = %s"
    execute_query(query, (status, result_image_id))

def get_pending_requests():
    """Get all image requests with 'new' or 'retry' status."""
    query = """
        SELECT ir.id, ir.request_id, ir.result_image_id, ir.user_id, ir.theme_id, 
               t.name as theme_name, t.theme, ir.source_image_id, i.data, ir.user_description
        FROM image_requests ir
        LEFT JOIN themes t ON ir.theme_id = t.id
        LEFT JOIN images i ON ir.source_image_id = i.id
        WHERE ir.status IN ('new', 'retry')
        ORDER BY ir.created_at
    """
    results = execute_query(query)
    logger.info(f"Found {len(results) if results else 0} pending requests")
    
    # Convert results to a list of objects
    pending_requests = []
    if results:
        for row in results:
            pending_requests.append({
                "id": row[0],
                "request_id": row[1],
                "result_image_id": row[2],
                "user_id": row[3],
                "theme_id": row[4],
                "theme_name": row[5],
                "theme": row[6],
                "source_image_id": row[7],
                "source_image_data": row[8],
                "user_description": row[9]
            })
    
    return pending_requests

def process_request(request_id, result_image_id, user_id, theme_id, theme_name, theme, source_image_id, source_image_data, user_description):
    """Process a single image request in a separate thread."""
    try:
        logger.info(f"Processing request {request_id}")
        
        # Update status to pending
        update_request_status(result_image_id, 'pending')
        
        # Create a BytesIO object from the source image data
        image_file = BytesIO(source_image_data)
        
        # Process the image with the selected theme
        result_image = process_image_to_image(
            image_file,
            user_description,
            theme
        )
        
        # Save the processed image data to the database
        result_data = result_image.getvalue()
        metadata = {"theme_id": theme_id, "process_method": "process_image_to_image"}
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
        update_request_status(result_image_id, 'ready')
        
        logger.info(f"Successfully processed request {request_id}")
        
    except Exception as e:
        logger.error(f"Error processing request {request_id}: {str(e)}")
        logger.debug(f"Stack trace:", exc_info=True)
        
        # Update the request status to retry
        update_request_status(result_image_id, 'retry')

def process_request_test(request_id, result_image_id, user_id, theme_id):
    """Process a single image request in a separate thread."""
    try:
        logger.info(f"Processing test request {request_id}")
        
        # Update status to pending
        update_request_status(result_image_id, 'pending')
        
        # Get an existing image from the database to use as test data
        fetch_query = "SELECT data, mime_type FROM images LIMIT 1"
        image_result = execute_query(fetch_query)
        
        if not image_result:
            logger.error("Test image not found in database")
            raise Exception("Test image not found in database")
            
        real_image_data = image_result[0][0]
        mime_type = image_result[0][1]
        
        # Insert the image
        metadata = {"theme_id": theme_id, "process_method": "test_existing_image"}
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
            (result_image_id, user_id, real_image_data, mime_type, metadata_json)
        )
        
        # Update the request status to ready
        update_request_status(result_image_id, 'ready')
        
        logger.info(f"Successfully processed test request {request_id}")
        
    except Exception as e:
        logger.error(f"Error processing test request {request_id}: {str(e)}")
        logger.debug("Stack trace:", exc_info=True)
        
        # Update the request status to retry
        update_request_status(result_image_id, 'retry')

def request_processor(requests):
    """Process multiple requests, each in its own thread."""
    threads = []
    
    for request in requests:
        id = request["id"]
        request_id = request["request_id"]
        result_image_id = request["result_image_id"]
        user_id = request["user_id"]
        theme_id = request["theme_id"]
        theme_name = request["theme_name"]
        theme = request["theme"]
        source_image_id = request["source_image_id"]
        source_image_data = request["source_image_data"]
        user_description = request["user_description"]
        
        # Create and start a new thread for each request
        thread = threading.Thread(
            target=process_request,
            args=(request_id, result_image_id, user_id, theme_id, theme_name, theme, source_image_id, source_image_data, user_description)
        )
        thread.start()
        threads.append(thread)
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()

def main():
    """Main background process loop."""
    logger.info("Starting background image request processor")
    
    while True:
        try:
            # Get pending requests
            pending_requests = get_pending_requests()
            
            if pending_requests:
                logger.info(f"Processing {len(pending_requests)} pending requests")
                request_processor(pending_requests)
            else:
                logger.info("No pending requests found")
            
            # Sleep before checking again
            time.sleep(5)
                
        except Exception as e:
            logger.error(f"Error in main loop: {str(e)}")
            logger.debug("Stack trace:", exc_info=True)
            time.sleep(30)  # Sleep longer if there was an error

if __name__ == "__main__":
    main()
