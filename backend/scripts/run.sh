#!/bin/bash

# Check if a Python file is specified
if [ $# -eq 0 ]; then
    echo "Usage: $0 <python_file.py>"
    echo "Available Python files:"
    ls -1 *.py
    exit 1
fi

PYTHON_FILE=$1

# Create virtual environment if it doesn't exist
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi

# Activate virtual environment
echo "Activating virtual environment..."
source .venv/bin/activate

# Install requirements
echo "Installing requirements..."
pip install -r ../requirements.txt

# Check and load environment variables
if [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    set -a
    source .env
    set +a
else
    echo "Warning: .env file not found. Environment variables may not be properly set."
fi

# Add parent directory to PYTHONPATH to make imports work
export PYTHONPATH=$PYTHONPATH:$(dirname $(pwd))

# Run the specified Python file
echo "Running $PYTHON_FILE..."
python $PYTHON_FILE

# Deactivate virtual environment
deactivate
