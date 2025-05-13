#!/bin/bash

# Ensure log directories exist
mkdir -p ./logs_web
mkdir -p ./logs_background
mkdir -p ./logs_db

# Set proper permissions
chmod -R 777 ./logs_web
chmod -R 777 ./logs_background
chmod -R 777 ./logs_db

echo "Log directories created and permissions set" 