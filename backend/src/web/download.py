from flask import jsonify, request
import os
from src.common.db import execute_query
from src.common.logging_config import setup_logger

# Configure logger
logger = setup_logger(__name__, 'download.log')

def register_routes(app):
    @app.route('/api/download/images', methods=['GET'])
    def download_images():
        """
        Get all images from image_requests with pagination support.
        Query parameters:
        - page: page number (default: 1)
        - limit: items per page (default: 100)
        - user_id: optional filter by user_id
        """
        try:
            # Get pagination parameters
            page = int(request.args.get('page', 1))
            limit = int(request.args.get('limit', 100))
            user_id = request.args.get('user_id')
            
            # Validate pagination parameters
            if page < 1:
                return jsonify({'error': 'Page must be greater than 0'}), 400
            if limit < 1 or limit > 1000:
                return jsonify({'error': 'Limit must be between 1 and 1000'}), 400
                
            # Calculate offset
            offset = (page - 1) * limit
            
            # Build query based on whether user_id is provided
            query_params = []
            count_query = "SELECT COUNT(*) FROM image_requests WHERE status = 'ready'"
            data_query = """
                SELECT 
                    ir.result_image_id, 
                    ir.user_id, 
                    ir.source_image_id, 
                    ir.theme_id, 
                    ir.user_description, 
                    ir.request_id, 
                    ir.created_at, 
                    ir.engine,
                    t.name as theme_name,
                    i.mime_type
                FROM image_requests ir
                JOIN themes t ON ir.theme_id = t.id
                LEFT JOIN images i ON ir.result_image_id = i.id
                WHERE ir.status = 'ready'
            """
            
            if user_id:
                count_query += " AND user_id = %s"
                data_query += " AND ir.user_id = %s"
                query_params.append(user_id)
            
            # Add pagination
            data_query += " ORDER BY ir.created_at DESC LIMIT %s OFFSET %s"
            query_params.extend([limit, offset])
            
            # Get total count
            count_result = execute_query(count_query, query_params[:-2] if user_id else [])
            total_count = count_result[0][0] if count_result else 0
            
            # Get paginated data
            results = execute_query(data_query, query_params)
            
            # Format the response
            images = []
            for row in results:
                result_image_id, user_id, source_image_id, theme_id, user_description, \
                request_id, created_at, engine, theme_name, mime_type = row
                
                images.append({
                    'result_image_id': result_image_id,
                    'user_id': user_id,
                    'source_image_id': source_image_id,
                    'theme_id': theme_id,
                    'theme_name': theme_name,
                    'user_description': user_description,
                    'request_id': request_id,
                    'created_at': created_at.isoformat() if created_at else None,
                    'engine': engine,
                    'mime_type': mime_type
                })
            
            # Calculate pagination metadata
            total_pages = (total_count + limit - 1) // limit if limit > 0 else 0
            
            return jsonify({
                'images': images,
                'pagination': {
                    'page': page,
                    'limit': limit,
                    'total_count': total_count,
                    'total_pages': total_pages
                }
            })
                
        except Exception as e:
            logger.error(f"Error retrieving images: {str(e)}")
            return jsonify({'error': f'Error retrieving images: {str(e)}'}), 500
