#!/bin/bash

# Exit on error
set -e

# Ensure we are in the project root
cd "$(dirname "$0")/.."

echo "🚀 Starting deployment process..."

# 1. Install dependencies
echo "📦 Installing dependencies..."
npm install

# 2. Build the project (Optional: Vercel usually does this, but good for local validation)
# echo "🏗️ Building project..."
# npm run build

# 3. Deploy to Vercel
echo "☁️ Deploying to Vercel (Production)..."
# --yes skips confirmation prompts
# --prod deploys to production
vercel --prod --yes

echo "✅ Deployment successful!"
