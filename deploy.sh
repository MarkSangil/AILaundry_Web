#!/bin/bash
set -e

echo "🚀 Starting local deployment to Vercel..."

# Check if Node.js and npm are installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed."
    echo "📦 Please install Node.js first: https://nodejs.org/"
    echo "   Or use Homebrew: brew install node"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed."
    echo "📦 Please install npm first."
    exit 1
fi

# Check if Vercel CLI is installed
if ! command -v vercel &> /dev/null; then
    echo "❌ Vercel CLI is not installed."
    echo "📦 Installing Vercel CLI (this may take a minute)..."
    if npm install -g vercel; then
        echo "✅ Vercel CLI installed successfully!"
    else
        echo "❌ Failed to install Vercel CLI."
        echo "💡 You can try installing manually: npm install -g vercel"
        echo "   Or use npx: npx vercel --prod"
        exit 1
    fi
fi

# Build the Flutter web app first
echo ""
echo "🔨 Building Flutter web app..."
if flutter build web --release; then
    echo "✅ Build complete!"
else
    echo "❌ Build failed!"
    exit 1
fi

# Deploy to Vercel
echo ""
echo "📤 Deploying to Vercel..."
if vercel --prod; then
    echo ""
    echo "✅ Deployment complete!"
else
    echo ""
    echo "❌ Deployment failed!"
    exit 1
fi
