# Image Theme Processor

This application lets you upload an image along with a description and desired theme, then uses OpenAI's APIs to:
1. Generate a detailed description of your image
2. Create a new themed version of the image based on that description

## Setup

### Prerequisites
- Python 3.8+
- OpenAI API key

### Installation

1. Clone this repository
2. Install dependencies:
```bash
cd backend
pip install -r requirements.txt
```
3. Create a `.env` file in the backend directory (copy from `.env.example`):
```bash
cp backend/.env.example backend/.env
```
4. Add your OpenAI API key to the `.env` file:
```
OPENAI_API_KEY=your_openai_api_key_here
```

### Running the Application

```bash
cd backend
python main.py
```

The server will start at http://localhost:5000

## API Usage

### Generate Themed Image

**Endpoint:** `POST /api/gen`

**Form Parameters:**
- `image`: Image file to process
- `user_description`: Your description of the image
- `theme_description`: The theme you want to apply to the image

**Example request using curl:**
```bash
curl -X POST http://localhost:5000/api/gen \
  -F "image=@/path/to/your/image.jpg" \
  -F "user_description=A sunset over mountains" \
  -F "theme_description=cyberpunk style with neon colors"
```

**Response:**
- Success: The generated image file
- Error: JSON with error message

## Docker Deployment

You can also run the application using Docker:

```bash
# First ensure the log directories exist and have proper permissions
cd backend
./ensure-logs.sh

# Then start the containers
docker-compose up -d
```

This will build and start the container, making the application available at http://localhost:5000. 