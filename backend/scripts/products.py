import uuid
import sys
import os
import json
import base64
from pathlib import Path

# Add the parent directory to sys.path to make src.common importable
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from src.common.db import execute_query

def dump_products_to_db():
    """
    Scan the amazon directory and import products to the database.
    Each product directory should contain:
    - link.txt with 3 lines: link, full name, short name
    - 1.jpg image file
    
    Returns:
        int: Number of products added to the database
    """
    product_count = 0
    
    try:
        print("Starting product import to database...")
        
        # First, check which products already exist in the database
        existing_products = execute_query("SELECT name FROM products")
        existing_product_names = [product[0] for product in existing_products] if existing_products else []
        
        # Amazon directory path
        amazon_dir = Path('amazon')
        
        # Check if the directory exists
        if not amazon_dir.exists() or not amazon_dir.is_dir():
            print(f"Error: Amazon directory not found at {amazon_dir.absolute()}")
            return 0
        
        # Recursively scan amazon/*/* directories
        for product_category in amazon_dir.iterdir():
            if not product_category.is_dir():
                continue
                
            for product_dir in product_category.iterdir():
                if not product_dir.is_dir():
                    continue
                
                link_file = product_dir / 'link.txt'
                image_file = product_dir / '1.jpg'
                
                # Skip if required files don't exist
                if not link_file.exists():
                    print(f"Skipping {product_dir}: link.txt not found")
                    continue
                    
                if not image_file.exists():
                    print(f"Skipping {product_dir}: 1.jpg not found")
                    continue
                
                # Read link.txt
                with open(link_file, 'r') as f:
                    lines = f.read().strip().split('\n')
                    
                if len(lines) < 3:
                    print(f"Skipping {product_dir}: link.txt has insufficient data")
                    continue
                
                link = lines[0].strip()
                full_name = lines[1].strip()
                short_name = lines[2].strip()
                
                # Read image file
                with open(image_file, 'rb') as f:
                    image_data = f.read()
                
                # Prepare metadata
                metadata = {
                    'link': link,
                    'full_name': full_name,
                    'product_id': product_dir.name,
                    'category': product_category.name
                }
                
                # Skip if product already exists
                if short_name in existing_product_names:
                    print(f"Product already exists: {short_name}")
                    continue
                
                # Insert the new product
                query = """
                    INSERT INTO products (id, name, image, metadata, mime_type, created_at)
                    VALUES (%s, %s, %s, %s, %s, NOW())
                """
                execute_query(
                    query, 
                    (
                        str(uuid.uuid4()), 
                        short_name, 
                        image_data, 
                        json.dumps(metadata), 
                        'image/jpeg'
                    )
                )
                product_count += 1
                print(f"Added product: {short_name}")
        
        print(f"Product import completed. Added {product_count} new products.")
        return product_count
        
    except Exception as e:
        print(f"Error importing products to database: {str(e)}")
        raise

if __name__ == "__main__":
    # Execute the product import when this script is run directly
    dump_products_to_db() 