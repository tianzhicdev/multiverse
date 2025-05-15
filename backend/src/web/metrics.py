from flask import jsonify, request, render_template_string
import os
from datetime import datetime, timedelta
from src.common.db import execute_query
from src.common.logging_config import setup_logger

# Configure logger
logger = setup_logger(__name__, 'metrics.log')

def get_new_users_data(hours=48):
    """Get count of new users by hour for the specified hours."""
    try:
        # Calculate the timestamp for hours ago
        hours_ago = datetime.now() - timedelta(hours=hours)
        
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
        
        results = execute_query(query, (hours_ago,))
        
        # Format the response
        hourly_data = []
        for row in results:
            hour, count = row
            hourly_data.append({
                'hour': hour.isoformat() if hour else None,
                'count': count
            })
        
        return hourly_data
            
    except Exception as e:
        logger.error(f"Error retrieving new users metrics: {str(e)}")
        raise e

def get_image_requests_data(hours=48):
    """Get count of unique request_ids by hour for the specified hours."""
    try:
        # Calculate the timestamp for hours ago
        hours_ago = datetime.now() - timedelta(hours=hours)
        
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
        
        results = execute_query(query, (hours_ago,))
        
        # Format the response
        hourly_data = []
        for row in results:
            hour, count = row
            hourly_data.append({
                'hour': hour.isoformat() if hour else None,
                'count': count
            })
        
        return hourly_data
            
    except Exception as e:
        logger.error(f"Error retrieving image requests metrics: {str(e)}")
        raise e

def get_transactions_data(limit=100):
    """Get the most recent transactions."""
    try:
        # Query to get the most recent transactions
        query = """
            SELECT 
                id,
                user_id,
                credit,
                reason,
                created_at
            FROM transactions
            ORDER BY created_at DESC
            LIMIT %s
        """
        
        results = execute_query(query, (limit,))
        
        # Format the response
        transactions = []
        for row in results:
            id, user_id, credit, reason, created_at = row
            transactions.append({
                'id': id,
                'user_id': user_id,
                'credit': credit,
                'reason': reason,
                'created_at': created_at.isoformat() if created_at else None
            })
        
        return transactions
            
    except Exception as e:
        logger.error(f"Error retrieving transaction metrics: {str(e)}")
        raise e

def register_routes(app):
    @app.route('/api/metrics/new_users', methods=['GET'])
    def new_users_last_48h():
        """
        Get count of new users by hour for the last 48 hours.
        Returns a list of {hour, count} objects sorted by hour descending.
        """
        try:
            hourly_data = get_new_users_data()
            return jsonify(hourly_data)
                
        except Exception as e:
            logger.error(f"Error retrieving new users metrics: {str(e)}")
            error_response = {'error': f'Error retrieving new users metrics: {str(e)}'}
            return jsonify(error_response), 500

    @app.route('/api/metrics/image_requests', methods=['GET'])
    def image_requests_last_48h():
        """
        Get count of unique request_ids by hour for the last 48 hours.
        Returns a list of {hour, count} objects sorted by hour descending.
        """
        try:
            hourly_data = get_image_requests_data()
            return jsonify(hourly_data)
                
        except Exception as e:
            logger.error(f"Error retrieving image requests metrics: {str(e)}")
            error_response = {'error': f'Error retrieving image requests metrics: {str(e)}'}
            return jsonify(error_response), 500

    @app.route('/api/metrics/transactions', methods=['GET'])
    def recent_transactions():
        """
        Get the most recent 100 transactions.
        Returns a list of transaction details sorted by created_at descending.
        """
        try:
            transactions = get_transactions_data()
            return jsonify(transactions)
                
        except Exception as e:
            logger.error(f"Error retrieving transaction metrics: {str(e)}")
            error_response = {'error': f'Error retrieving transaction metrics: {str(e)}'}
            return jsonify(error_response), 500

    # New HTML table endpoints
    @app.route('/metrics/new_users_table', methods=['GET'])
    def new_users_table():
        """Display new users metrics as an HTML table."""
        try:
            hourly_data = get_new_users_data()
            
            html_template = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>New Users - Last 48 Hours</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 20px; }
                    h1 { color: #333; }
                    table { border-collapse: collapse; width: 100%; }
                    th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
                    th { background-color: #f2f2f2; }
                    tr:hover { background-color: #f5f5f5; }
                </style>
            </head>
            <body>
                <h1>New Users - Last 48 Hours</h1>
                <table>
                    <tr>
                        <th>Hour</th>
                        <th>Count</th>
                    </tr>
                    {% for item in data %}
                    <tr>
                        <td>{{ item.hour }}</td>
                        <td>{{ item.count }}</td>
                    </tr>
                    {% endfor %}
                </table>
            </body>
            </html>
            """
            
            return render_template_string(html_template, data=hourly_data)
                
        except Exception as e:
            logger.error(f"Error displaying new users table: {str(e)}")
            return f"Error: {str(e)}", 500

    @app.route('/metrics/image_requests_table', methods=['GET'])
    def image_requests_table():
        """Display image requests metrics as an HTML table."""
        try:
            hourly_data = get_image_requests_data()
            
            html_template = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Image Requests - Last 48 Hours</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 20px; }
                    h1 { color: #333; }
                    table { border-collapse: collapse; width: 100%; }
                    th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
                    th { background-color: #f2f2f2; }
                    tr:hover { background-color: #f5f5f5; }
                </style>
            </head>
            <body>
                <h1>Image Requests - Last 48 Hours</h1>
                <table>
                    <tr>
                        <th>Hour</th>
                        <th>Count</th>
                    </tr>
                    {% for item in data %}
                    <tr>
                        <td>{{ item.hour }}</td>
                        <td>{{ item.count }}</td>
                    </tr>
                    {% endfor %}
                </table>
            </body>
            </html>
            """
            
            return render_template_string(html_template, data=hourly_data)
                
        except Exception as e:
            logger.error(f"Error displaying image requests table: {str(e)}")
            return f"Error: {str(e)}", 500

    @app.route('/metrics/transactions_table', methods=['GET'])
    def transactions_table():
        """Display recent transactions as an HTML table."""
        try:
            transactions = get_transactions_data()
            
            html_template = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>Recent Transactions</title>
                <style>
                    body { font-family: Arial, sans-serif; margin: 20px; }
                    h1 { color: #333; }
                    table { border-collapse: collapse; width: 100%; }
                    th, td { padding: 8px; text-align: left; border-bottom: 1px solid #ddd; }
                    th { background-color: #f2f2f2; }
                    tr:hover { background-color: #f5f5f5; }
                </style>
            </head>
            <body>
                <h1>Recent Transactions</h1>
                <table>
                    <tr>
                        <th>ID</th>
                        <th>User ID</th>
                        <th>Credit</th>
                        <th>Reason</th>
                        <th>Created At</th>
                    </tr>
                    {% for item in data %}
                    <tr>
                        <td>{{ item.id }}</td>
                        <td>{{ item.user_id }}</td>
                        <td>{{ item.credit }}</td>
                        <td>{{ item.reason }}</td>
                        <td>{{ item.created_at }}</td>
                    </tr>
                    {% endfor %}
                </table>
            </body>
            </html>
            """
            
            return render_template_string(html_template, data=transactions)
                
        except Exception as e:
            logger.error(f"Error displaying transactions table: {str(e)}")
            return f"Error: {str(e)}", 500
