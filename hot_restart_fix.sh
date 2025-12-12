#!/bin/bash
# Script to force clean rebuild on hot restart issues

echo "Cleaning Flutter build..."
flutter clean
rm -rf build/web
rm -rf .dart_tool/flutter_build

echo "Getting dependencies..."
flutter pub get

echo "Starting Flutter with clean build..."
flutter run -d chrome --web-renderer html --web-port=8080
