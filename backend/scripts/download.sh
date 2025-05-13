#!/bin/bash

# Configuration
API_URL=${API_URL:-"http://localhost:5000"}
OUTPUT_DIR="$(dirname "$0")/images"
USER_ID=${USER_ID:-""}  # Optional user ID filter
PAGE_SIZE=100

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Function to download an image and its metadata
download_image() {
    local result_image_id=$1
    local metadata=$2
    local user_id=$3
    
    # Download the image
    echo "Downloading image: $result_image_id"
    curl -s "$API_URL/api/image/$result_image_id?user_id=$user_id" -o "$OUTPUT_DIR/$result_image_id.jpg"
    
    # Save metadata as JSON
    echo "$metadata" > "$OUTPUT_DIR/$result_image_id.json"
}

# Function to fetch a page of images
fetch_page() {
    local page=$1
    local user_param=""
    
    if [ -n "$USER_ID" ]; then
        user_param="&user_id=$USER_ID"
    fi
    
    echo "Fetching page $page..."
    response=$(curl -s "$API_URL/api/download/images?page=$page&limit=$PAGE_SIZE$user_param")
    
    # Check if the response contains an error
    if echo "$response" | grep -q "error"; then
        echo "Error: $(echo "$response" | jq -r '.error // "Unknown error"')"
        return 1
    fi
    
    # Extract pagination info
    total_pages=$(echo "$response" | jq -r '.pagination.total_pages')
    total_count=$(echo "$response" | jq -r '.pagination.total_count')
    
    # Extract and download images
    echo "$response" | jq -c '.images[]' | while read -r image_data; do
        result_image_id=$(echo "$image_data" | jq -r '.result_image_id')
        user_id=$(echo "$image_data" | jq -r '.user_id')
        
        # Download the image and save metadata
        download_image "$result_image_id" "$image_data" "$user_id"
    done
    
    echo "Page $page/$total_pages complete"
    
    # Return total pages for the caller
    echo "$total_pages"
}

# Main script execution
echo "Starting download of images to $OUTPUT_DIR"
echo "API URL: $API_URL"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq."
    exit 1
fi

# Start with page 1
page=1
total_pages=1

# Fetch first page to get total pages
total_pages=$(fetch_page $page)

# Continue fetching remaining pages
while [ $page -lt $total_pages ]; do
    page=$((page + 1))
    fetch_page $page
done

echo "Download complete. Downloaded images are in $OUTPUT_DIR"
echo "Total images: $(ls -1 "$OUTPUT_DIR"/*.jpg 2>/dev/null | wc -l)"
