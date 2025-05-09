import uuid
import csv
from db import execute_query
from helper import theme_descriptions

def dump_themes_to_db():
    """
    Dump predefined theme descriptions to the database.
    Each theme from the theme_descriptions list in helper.py will be added
    to the themes table if it doesn't already exist.
    
    Returns:
        int: Number of themes added to the database
    """
    theme_count = 0
    
    try:
        print("Starting theme dump to database...")
        
        # First, check which themes already exist in the database
        existing_themes = execute_query("SELECT name FROM themes")
        existing_theme_names = [theme[0] for theme in existing_themes] if existing_themes else []
        
        # Add themes that don't already exist
        for theme in theme_descriptions:
            if theme["name"] not in existing_theme_names:
                # Insert the new theme
                query = """
                    INSERT INTO themes (id, name, theme, created_at)
                    VALUES (%s, %s, %s, NOW())
                """
                execute_query(query, (str(uuid.uuid4()), theme["name"], theme["description"]))
                theme_count += 1
                print(f"Added theme: {theme['name']}")
            else:
                print(f"Theme already exists: {theme['name']}")
        
        print(f"Theme dump completed. Added {theme_count} new themes.")
        return theme_count
        
    except Exception as e:
        print(f"Error dumping themes to database: {str(e)}")
        raise

def dump_themes_csv_to_db():
    """
    Dump theme descriptions from themes.csv to the database.
    Each theme from the CSV file will be added to the themes table if it doesn't already exist.
    
    Returns:
        int: Number of themes added to the database
    """
    theme_count = 0
    
    try:
        print("Starting theme CSV dump to database...")
        
        # First, check which themes already exist in the database
        existing_themes = execute_query("SELECT name FROM themes")
        existing_theme_names = [theme[0] for theme in existing_themes] if existing_themes else []
        
        # Read themes from CSV file
        with open('themes.csv', 'r') as csvfile:
            csvreader = csv.reader(csvfile)
            for row in csvreader:
                if len(row) != 2:
                    print(f"Skipping invalid row: {row}")
                    continue
                    
                theme_name, theme_description = row
                
                if theme_name not in existing_theme_names:
                    # Insert the new theme
                    query = """
                        INSERT INTO themes (id, name, theme, created_at)
                        VALUES (%s, %s, %s, NOW())
                    """
                    execute_query(query, (str(uuid.uuid4()), theme_name.strip(), theme_description.strip()))
                    theme_count += 1
                    print(f"Added theme: {theme_name}")
                else:
                    print(f"Theme already exists: {theme_name}")
        
        print(f"Theme CSV dump completed. Added {theme_count} new themes.")
        return theme_count
        
    except Exception as e:
        print(f"Error dumping themes from CSV to database: {str(e)}")
        raise

if __name__ == "__main__":
    # Execute the theme dump when this script is run directly
    dump_themes_csv_to_db()
