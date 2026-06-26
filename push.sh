#!/bin/bash
# Script to stage, commit, and push changes

# Check if a commit message was provided
if [ -z "$1" ]; then
    echo "⚠️ Error: Please provide a commit message."
    echo "Usage: ./push.sh \"your commit message\""
    exit 1
fi

echo "📦 Staging changes (including subdirectories)..."
git add .

echo "💾 Committing changes..."
git commit -m "$1"

echo "🚀 Pushing to GitHub..."
git push origin main

if [ $? -eq 0 ]; then
    echo "✅ Successfully pushed to GitHub!"
else
    echo "❌ Push failed. Check your network or token permissions."
fi