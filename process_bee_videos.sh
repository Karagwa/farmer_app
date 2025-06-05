#!/bin/bash
# process_bee_videos.sh
# Script to be run via cron job for automatic video processing

# Directory where the Flutter project is located
PROJECT_DIR="/home/aheebwa/Pictures/farmer_app"
FLUTTER_PATH="/snap/bin/flutter"
# Replace the path above with the actual full path to your project

# Go to project directory
cd $PROJECT_DIR

# Create logs directory if it doesn't exist
mkdir -p logs

# Process videos for today's date
echo "Running bee video processing $(date)"
flutter run bin/process_bee_videos.dart --verbose >> logs/video_processing_$(date +%Y-%m-%d).log 2>&1

echo "Processing complete"