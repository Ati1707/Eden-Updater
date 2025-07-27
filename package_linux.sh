#!/bin/bash

echo "Packaging Eden Updater for Linux..."

# Build the release version
echo "Building release version..."
flutter build linux --release
if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Create package directory structure
INNER_PACKAGE_DIR="eden_updater"
OUTER_PACKAGE_DIR="EdenUpdater"

# Clean up any existing directories
if [ -d "$OUTER_PACKAGE_DIR" ]; then
    rm -rf "$OUTER_PACKAGE_DIR"
fi
if [ -d "$INNER_PACKAGE_DIR" ]; then
    rm -rf "$INNER_PACKAGE_DIR"
fi

# Create the nested directory structure
mkdir -p "$OUTER_PACKAGE_DIR/$INNER_PACKAGE_DIR"

# Copy all necessary files
echo "Copying files..."
SOURCE_DIR="build/linux/x64/release/bundle"
TARGET_DIR="$OUTER_PACKAGE_DIR/$INNER_PACKAGE_DIR"

cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"

# Make the executable actually executable
chmod +x "$TARGET_DIR/eden_updater"

# Create a simple README
echo "Creating README..."
cat > "$TARGET_DIR/README.txt" << 'EOF'
Eden Updater - Linux

To run Eden Updater:
1. Open terminal in this directory
2. Run: ./eden_updater

Or double-click eden_updater in your file manager (if it supports executable files)

Command line options:
  --auto-launch    : Automatically launch Eden after update
  --channel stable : Use stable channel (default)
  --channel nightly: Use nightly channel

This is a portable version - no installation required.
All files in this folder are needed for the application to work.

For desktop shortcuts, run the updater and enable "Create desktop shortcut"
in the settings. The shortcut will have auto-update functionality.
EOF

# Create a simple launcher script
echo "Creating launcher script..."
cat > "$TARGET_DIR/launch_eden_updater.sh" << 'EOF'
#!/bin/bash
# Eden Updater Launcher Script
# This script ensures the executable has proper permissions and launches the updater

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make sure the executable has execute permissions
chmod +x "$SCRIPT_DIR/eden_updater"

# Launch the updater with any provided arguments
"$SCRIPT_DIR/eden_updater" "$@"
EOF

chmod +x "$TARGET_DIR/launch_eden_updater.sh"

echo ""
echo "Package created successfully in $OUTER_PACKAGE_DIR/"
echo "You can distribute this entire folder or create a tar.gz file from it."
echo ""

# Show files included
echo "Files included:"
find "$OUTER_PACKAGE_DIR" -type f | sed 's|^'\"$OUTER_PACKAGE_DIR\"'/|  |'

# Calculate total size
TOTAL_SIZE=$(du -sb "$OUTER_PACKAGE_DIR" | cut -f1)
SIZE_IN_MB=$(echo "scale=2; $TOTAL_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "$(($TOTAL_SIZE / 1024 / 1024))")

echo ""
echo "Total size: ${SIZE_IN_MB} MB ($TOTAL_SIZE bytes)"

# Automatically create tar.gz file
echo ""
TAR_NAME="EdenUpdater_Linux.tar.gz"
echo "Creating tar.gz file..."

if [ -f "$TAR_NAME" ]; then
    rm "$TAR_NAME"
fi

tar -czf "$TAR_NAME" -C "$OUTER_PACKAGE_DIR" "$INNER_PACKAGE_DIR"

if [ -f "$TAR_NAME" ]; then
    TAR_SIZE=$(stat -f%z "$TAR_NAME" 2>/dev/null || stat -c%s "$TAR_NAME" 2>/dev/null)
    TAR_SIZE_IN_MB=$(echo "scale=2; $TAR_SIZE / 1024 / 1024" | bc -l 2>/dev/null || echo "$(($TAR_SIZE / 1024 / 1024))")
    echo "tar.gz file created: $TAR_NAME (${TAR_SIZE_IN_MB} MB)"
fi

echo ""
echo "Packaging complete!"