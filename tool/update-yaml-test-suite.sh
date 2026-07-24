#!/bin/bash
set -e

# Go to the pkgs/yaml directory
cd "$(dirname "$0")/.."

TARGET_DIR="third_party/yaml-test-suite"

echo "Updating yaml-test-suite..."

# Remove the old directory if it exists
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"

# Clone the repository to a temporary directory
TMP_DIR=$(mktemp -d)
git clone https://github.com/yaml/yaml-test-suite.git "$TMP_DIR"

# Copy the required files and directories
cp -r "$TMP_DIR/src" "$TARGET_DIR/"
cp "$TMP_DIR/License" "$TARGET_DIR/LICENSE"

# Copy README
if [ -f "$TMP_DIR/ReadMe.md" ]; then
    cp "$TMP_DIR/ReadMe.md" "$TARGET_DIR/README.md"
elif [ -f "$TMP_DIR/README.md" ]; then
    cp "$TMP_DIR/README.md" "$TARGET_DIR/README.md"
fi

# Clean up
rm -rf "$TMP_DIR"

echo "yaml-test-suite updated successfully."
