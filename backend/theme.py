import uuid
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
        existing_themes = execute_query("SELECT theme FROM themes")
        existing_theme_texts = [theme[0] for theme in existing_themes] if existing_themes else []
        
        # Add themes that don't already exist
        for theme_description in theme_descriptions:
            if theme_description not in existing_theme_texts:
                # Insert the new theme
                query = """
                    INSERT INTO themes (id, theme, created_at)
                    VALUES (%s, %s, NOW())
                """
                execute_query(query, (str(uuid.uuid4()), theme_description))
                theme_count += 1
                print(f"Added theme: {theme_description[:50]}...")
            else:
                print(f"Theme already exists: {theme_description[:50]}...")
        
        print(f"Theme dump completed. Added {theme_count} new themes.")
        return theme_count
        
    except Exception as e:
        print(f"Error dumping themes to database: {str(e)}")
        raise

if __name__ == "__main__":
    # Execute the theme dump when this script is run directly
    dump_themes_to_db()
