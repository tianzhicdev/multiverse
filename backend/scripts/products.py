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
    Scan the amazon directory and import products as themes to the database.
    Each product can be either:
    1. A directory within a category containing link.txt and 1.jpg
    2. Files directly in the category directory
    
    The link.txt should contain 3 lines: link, full name, short name
    
    Returns:
        int: Number of products added to the database
    """
    product_count = 0
    
    try:
        print("Starting product import to database as themes...")
        
        # First, check which themes already exist in the database
        existing_themes = execute_query("SELECT name FROM themes")
        existing_theme_names = [theme[0] for theme in existing_themes] if existing_themes else []
        
        # Amazon directory path
        amazon_dir = Path('amazon')
        
        # Check if the directory exists
        if not amazon_dir.exists() or not amazon_dir.is_dir():
            print(f"Error: Amazon directory not found at {amazon_dir.absolute()}")
            return 0
        
        # Recursively scan amazon/* directories (categories)
        for product_category in amazon_dir.iterdir():
            if not product_category.is_dir():
                continue
                
            # Check if the files are directly in the category directory
            link_file = product_category / 'link.txt'
            image_file = product_category / '1.jpg'
            
            if link_file.exists() and image_file.exists():
                # Case 1: Files are directly in the category directory
                try:
                    # Read link.txt
                    with open(link_file, 'r') as f:
                        lines = f.read().strip().split('\n')
                        
                    if len(lines) < 3:
                        print(f"Skipping {product_category}: link.txt has insufficient data")
                        continue
                    
                    link = lines[0].strip()
                    full_name = lines[1].strip()
                    short_name = lines[2].strip()
                    
                    # Read image file
                    with open(image_file, 'rb') as f:
                        image_data = base64.b64encode(f.read()).decode('utf-8')
                    
                    # Prepare metadata
                    metadata = {
                        'link': link,
                        'image': image_data,
                        'product_id': product_category.name,
                        'category': product_category.name,
                        'mime_type': 'image/jpeg',
                        'type': 'upper_body'
                    }
                    
                    
                    # Insert the new theme
                    query = """
                        INSERT INTO themes (id, name, theme, metadata, created_at)
                        VALUES (%s, %s, %s, %s, NOW())
                    """
                    execute_query(
                        query, 
                        (
                            str(uuid.uuid4()), 
                            short_name, 
                            full_name, 
                            json.dumps(metadata)
                        )
                    )
                    product_count += 1
                    print(f"Added theme: {short_name}")
                except Exception as e:
                    print(f"Error processing {product_category}: {str(e)}")
                
            else:
                # Case 2: Original structure with subdirectories for products
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
                        image_data = base64.b64encode(f.read()).decode('utf-8')
                    
                    # Prepare metadata
                    metadata = {
                        'link': link,
                        'image': image_data,
                        'product_id': product_dir.name,
                        'category': product_category.name,
                        'mime_type': 'image/jpeg'
                    }
                    
                    # Skip if theme already exists
                    if short_name in existing_theme_names:
                        print(f"Theme already exists: {short_name}")
                        continue
                    
                    # Insert the new theme
                    query = """
                        INSERT INTO themes (id, name, theme, metadata, created_at)
                        VALUES (%s, %s, %s, %s, NOW())
                    """
                    execute_query(
                        query, 
                        (
                            str(uuid.uuid4()), 
                            short_name, 
                            full_name, 
                            json.dumps(metadata)
                        )
                    )
                    product_count += 1
                    print(f"Added theme: {short_name}")
        
        print(f"Product import completed. Added {product_count} new themes.")
        return product_count
        
    except Exception as e:
        print(f"Error importing products as themes: {str(e)}")
        raise

if __name__ == "__main__":
    # Execute the product import when this script is run directly
    dump_products_to_db() 