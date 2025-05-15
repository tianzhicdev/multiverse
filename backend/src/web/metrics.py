from flask import jsonify, request
import os
from datetime import datetime, timedelta
from src.common.db import execute_query
from src.common.logging_config import setup_logger

# Configure logger
logger = setup_logger(__name__, 'metrics.log')

def register_routes(app):
    @app.route('/api/metrics/new_users', methods=['GET'])
    def new_users_last_48h():
        """
        Get count of new users by hour for the last 48 hours.
        Returns a list of {hour, count} objects sorted by hour descending.
        """
        try:
            # Calculate the timestamp for 48 hours ago
            hours_48_ago = datetime.now() - timedelta(hours=48)
            
            # Query to get new users by hour
            query = """
                SELECT 
                    DATE_TRUNC('hour', created_at) as hour,
                    COUNT(*) as count
                FROM users
                WHERE created_at >= %s
                GROUP BY DATE_TRUNC('hour', created_at)
                ORDER BY hour DESC
            """
            
            results = execute_query(query, (hours_48_ago,))
            
            # Format the response
            hourly_data = []
            for row in results:
                hour, count = row
                hourly_data.append({
                    'hour': hour.isoformat() if hour else None,
                    'count': count
                })
            
            return jsonify(hourly_data)
                
        except Exception as e:
            logger.error(f"Error retrieving new users metrics: {str(e)}")
            return jsonify({'error': f'Error retrieving new users metrics: {str(e)}'}), 500

    @app.route('/api/metrics/image_requests', methods=['GET'])
    def image_requests_last_48h():
        """
        Get count of unique request_ids by hour for the last 48 hours.
        Returns a list of {hour, count} objects sorted by hour descending.
        """
        try:
            # Calculate the timestamp for 48 hours ago
            hours_48_ago = datetime.now() - timedelta(hours=48)
            
            # Query to get unique request_ids by hour
            query = """
                SELECT 
                    DATE_TRUNC('hour', created_at) as hour,
                    COUNT(DISTINCT request_id) as count
                FROM image_requests
                WHERE created_at >= %s
                GROUP BY DATE_TRUNC('hour', created_at)
                ORDER BY hour DESC
            """
            
            results = execute_query(query, (hours_48_ago,))
            
            # Format the response
            hourly_data = []
            for row in results:
                hour, count = row
                hourly_data.append({
                    'hour': hour.isoformat() if hour else None,
                    'count': count
                })
            
            return jsonify(hourly_data)
                
        except Exception as e:
            logger.error(f"Error retrieving image requests metrics: {str(e)}")
            return jsonify({'error': f'Error retrieving image requests metrics: {str(e)}'}), 500

    @app.route('/api/metrics/transactions', methods=['GET'])
    def recent_transactions():
        """
        Get the most recent 100 transactions.
        Returns a list of transaction details sorted by created_at descending.
        """
        try:
            # Query to get the most recent 100 transactions
            query = """
                SELECT 
                    id,
                    user_id,
                    amount,
                    credits,
                    status,
                    payment_method,
                    created_at,
                    metadata
                FROM transactions
                ORDER BY created_at DESC
                LIMIT 100
            """
            
            results = execute_query(query)
            
            # Format the response
            transactions = []
            for row in results:
                id, user_id, amount, credits, status, payment_method, created_at, metadata = row
                transactions.append({
                    'id': id,
                    'user_id': user_id,
                    'amount': float(amount) if amount else 0,
                    'credits': credits,
                    'status': status,
                    'payment_method': payment_method,
                    'created_at': created_at.isoformat() if created_at else None,
                    'metadata': metadata
                })
            
            return jsonify(transactions)
                
        except Exception as e:
            logger.error(f"Error retrieving transaction metrics: {str(e)}")
            return jsonify({'error': f'Error retrieving transaction metrics: {str(e)}'}), 500
