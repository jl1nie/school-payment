#!/bin/bash
set -e

# Set environment variables for Lean
export ELAN_HOME="/root/.elan"
export PATH="$ELAN_HOME/bin:$PATH"
export LEAN_BACKEND_PATH="/app/lean-backend"

# Start static file server for frontend (using npx serve)
echo "Starting frontend static server on port 5173..."
npx serve -s /app/frontend/dist -l 5173 &

# Start API server
echo "Starting API server on port 3001..."
cd /app/api-server
node dist/index.js
