#!/bin/bash
set -e

# Start static file server for frontend
echo "Starting frontend static server on port 5173..."
serve -s /app/frontend/dist -l 5173 &

# Start Rust API server
echo "Starting API server on port 3001..."
/app/web-server
