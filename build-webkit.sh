#!/bin/bash
set -e

echo "Building WebKit Claude Docker image..."

# Build the WebKit image
docker build -f Dockerfile.webkit -t claude-webkit:latest .

echo "WebKit Claude Docker image built successfully!"
echo "Tagged as: claude-webkit:latest"

# Optional: Push to a registry if needed
# docker tag claude-webkit:latest ghcr.io/oven-sh/claude-webkit:latest
# docker push ghcr.io/oven-sh/claude-webkit:latest