#!/bin/bash
# Script to safely pull changes from GitHub

echo "🔄 Fetching and merging latest updates from GitHub..."
git pull origin main

if [ $? -eq 0 ]; then
    echo "✅ Project successfully updated!"
else
    echo "❌ Update failed. Check for uncommitted local conflicts."
fi