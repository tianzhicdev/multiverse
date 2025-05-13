#!/usr/bin/env python3
"""
Background Processing Script for Image Requests

This script maintains a pool of worker threads that continuously process image requests
from a queue, allowing for better concurrency and reduced processing delays.
"""
        
import logging
from src.common.logging_config import setup_logger
import threading
import time
from io import BytesIO
from src.common.db import execute_query
from src.common.db import execute_query_with_results
import json
from src.common.helper import process_image_to_image, image_gen
from queue import Queue
import queue

# Configure logger using centralized logging config
logger = setup_logger(__name__, f'background.{int(time.time())}.log')

# Global queue for image requests
request_queue = Queue()
# Event to signal workers to stop
stop_event = threading.Event()

def update_request_status(result_image_id, status):
    """Update the status of an image request."""
    query = "UPDATE image_requests SET status = %s WHERE result_image_id = %s"
    execute_query(query, (status, result_image_id))

def get_pending_requests():
    """Get all image requests with 'new' or 'retry' status and update them to 'pending'."""
    # Use a transaction to atomically select and update requests
    query = """
        WITH pending_requests AS (
            UPDATE image_requests ir
            SET status = 'pending'
            WHERE ir.status IN ('new', 'retry')
            RETURNING ir.id, ir.request_id, ir.result_image_id, ir.user_id, ir.theme_id, ir.source_image_id, ir.user_description
        )
        SELECT pr.id, pr.request_id, pr.result_image_id, pr.user_id, pr.theme_id, 
               t.name as theme_name, t.theme, pr.source_image_id, i.data, pr.user_description
        FROM pending_requests pr
        LEFT JOIN themes t ON pr.theme_id = t.id
        LEFT JOIN images i ON pr.source_image_id = i.id
        ORDER BY pr.id
    """
    results = execute_query_with_results(query)
    logger.info(f"Found and updated {len(results) if results else 0} pending requests")
    
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

def process_request(request):
    """Process a single image request."""
    try:
        logger.info(f"Processing request {request['request_id']}")
        
        # Create a BytesIO object from the source image data
        image_file = BytesIO(request['source_image_data'])
        
        # Process the image with the selected theme
        result_image, engine = process_image_to_image(
            request['result_image_id'],
            image_file,
            request['user_description'],
            request['theme']
        )
        
        # Save the processed image data to the database
        result_data = result_image.getvalue()
        metadata = {"theme_id": request['theme_id'], "process_method": "process_image_to_image", "engine": engine}
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
            (request['result_image_id'], request['user_id'], result_data, 'image/jpeg', metadata_json)
        )
        # Update the database with engine and finished timestamp
        engine_query = "UPDATE image_requests SET engine = %s, finished_at = CURRENT_TIMESTAMP WHERE result_image_id = %s"
        execute_query(engine_query, (engine, request['result_image_id']))
        # Update the request status to ready
        update_request_status(request['result_image_id'], 'ready')
        
        logger.info(f"Successfully processed request {request['request_id']} with engine {engine}")
        
    except Exception as e:
        logger.error(f"Error processing request {request['request_id']}: {str(e)}")
        logger.debug(f"Stack trace:", exc_info=True)
        
        # Update the request status to retry
        update_request_status(request['result_image_id'], 'retry')

def worker():
    """Worker thread that continuously processes requests from the queue."""
    while not stop_event.is_set():
        try:
            # Get a request from the queue with a timeout
            request = request_queue.get(timeout=1)
            if request:
                process_request(request)
                request_queue.task_done()
        except queue.Empty:
            # Queue is empty, continue waiting
            continue
        except Exception as e:
            logger.error(f"Error in worker thread: {str(e)}")
            logger.debug("Stack trace:", exc_info=True)

def main():
    """Main background process loop."""
    logger.info("Starting background image request processor")
    
    # Create and start worker threads
    num_workers = 10
    workers = []
    for _ in range(num_workers):
        t = threading.Thread(target=worker)
        t.daemon = True
        t.start()
        workers.append(t)
    
    try:
        while not stop_event.is_set():
            try:
                # Get pending requests
                pending_requests = get_pending_requests()
                
                if pending_requests:
                    logger.info(f"Adding {len(pending_requests)} requests to queue")
                    for request in pending_requests:
                        request_queue.put(request)
                
                # Sleep before checking again
                time.sleep(1)
                    
            except Exception as e:
                logger.error(f"Error in main loop: {str(e)}")
                logger.debug("Stack trace:", exc_info=True)
                time.sleep(30)  # Sleep longer if there was an error
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        stop_event.set()
        # Wait for all workers to finish
        for worker_thread in workers:
            worker_thread.join()

if __name__ == "__main__":
    main()
