#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Get current branch as default
CURRENT_BRANCH=$(git branch --show-current)

# Get the branch name from command line argument or use current branch as default
BRANCH=${1:-$CURRENT_BRANCH}

echo "Redeploying from branch: $BRANCH"

# Fetch the latest changes and checkout the specified branch
git fetch origin $BRANCH
git checkout $BRANCH
git pull origin $BRANCH

# Determine which Docker Compose command format to use
if command -v docker &> /dev/null && docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
elif command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    echo "Error: Neither 'docker compose' nor 'docker-compose' found"
    exit 1
fi

# Restart Docker containers
$DOCKER_COMPOSE down
$DOCKER_COMPOSE build
$DOCKER_COMPOSE up -d

echo "Redeployment complete!"