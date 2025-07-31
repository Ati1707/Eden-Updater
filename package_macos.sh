#!/bin/bash

echo "Packaging Eden Updater for macOS..."

# Build the release version
echo "Building release version..."
flutter build macos --release
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
SOURCE_DIR="build/macos/Build/Products/Release"
TARGET_DIR="$OUTER_PACKAGE_DIR/$INNER_PACKAGE_DIR"

# Copy the .app bundle
cp -R "$SOURCE_DIR/eden_updater.app" "$TARGET_DIR/"

# Rename the app bundle to a simpler name for distribution
if [ -d "$TARGET_DIR/eden_updater.app" ]; then
    mv "$TARGET_DIR/eden_updater.app" "$TARGET_DIR/EdenUpdater.app"
else
    echo "Error: Failed to copy the application bundle. Aborting."
    exit 1
fi

# Create a simple README
echo "Creating README..."
cat > "$TARGET_DIR/README.txt" << 'EOF'
Eden Updater - macOS

To run Eden Updater:
1. Double-click EdenUpdater.app

Or from Terminal:
1. Open Terminal in this directory
2. Run: open EdenUpdater.app

Command line options (when running from Terminal):
  --auto-launch    : Automatically launch Eden after update
  --channel stable : Use stable channel (default)
  --channel nightly: Use nightly channel

Example Terminal usage:
  open EdenUpdater.app --args --auto-launch --channel nightly

This is a portable version - no installation required.
All files in this folder are needed for the application to work.

For desktop shortcuts, run the updater and enable "Create desktop shortcut"
in the settings. The shortcut will have auto-update functionality.

Installation:
- You can drag EdenUpdater.app to your Applications folder for easy access
- Or keep it in this folder and create an alias to your desktop
- The app will work from any location
EOF

# Create a simple launcher script for command-line usage
echo "Creating launcher script..."
cat > "$TARGET_DIR/launch_eden_updater.sh" << 'EOF'
#!/bin/bash
# Eden Updater Launcher Script for macOS
# This script launches the Eden Updater with command-line arguments

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Launch the updater with any provided arguments
open "$SCRIPT_DIR/EdenUpdater.app" --args "$@"
EOF

chmod +x "$TARGET_DIR/launch_eden_updater.sh"

# Create an installation script
echo "Creating installation script..."
cat > "$TARGET_DIR/install_to_applications.sh" << 'EOF'
#!/bin/bash
# Eden Updater Installation Script
# This script copies the app to the Applications folder

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing Eden Updater to Applications folder..."

# Check if Applications folder exists
if [ ! -d "/Applications" ]; then
    echo "Error: Applications folder not found!"
    exit 1
fi

# Copy the app to Applications
if [ -d "$SCRIPT_DIR/EdenUpdater.app" ]; then
    cp -R "$SCRIPT_DIR/EdenUpdater.app" "/Applications/"
    if [ $? -eq 0 ]; then
        echo "Eden Updater installed successfully to /Applications/"
        echo "You can now find it in Launchpad or run it from Applications folder."
        
        # Ask if user wants to launch it
        read -p "Would you like to launch Eden Updater now? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "/Applications/EdenUpdater.app"
        fi
    else
        echo "Error: Failed to copy app to Applications folder!"
        echo "You may need to run this script with sudo or check permissions."
        exit 1
    fi
else
    echo "Error: EdenUpdater.app not found in current directory!"
    exit 1
fi
EOF

chmod +x "$TARGET_DIR/install_to_applications.sh"

echo ""
echo "Package created successfully in $OUTER_PACKAGE_DIR/"
echo "You can distribute this entire folder or create a DMG file from it."
echo ""

# Show files included
echo "Files included:"
find "$OUTER_PACKAGE_DIR" -type f | sed 's|^'\"$OUTER_PACKAGE_DIR\"'/|  |'

# Calculate total size
TOTAL_SIZE=$(du -s "$OUTER_PACKAGE_DIR" | cut -f1)
# Convert from 512-byte blocks to bytes, then to MB
TOTAL_SIZE_BYTES=$((TOTAL_SIZE * 512))
SIZE_IN_MB=$(echo "scale=2; $TOTAL_SIZE_BYTES / 1024 / 1024" | bc -l 2>/dev/null || echo "$(($TOTAL_SIZE_BYTES / 1024 / 1024))")

echo ""
echo "Total size: ${SIZE_IN_MB} MB ($TOTAL_SIZE_BYTES bytes)"

# Check if hdiutil is available for DMG creation
echo ""
if command -v hdiutil >/dev/null 2>&1; then
    DMG_NAME="EdenUpdater_macOS.dmg"
    echo "Creating DMG file..."
    
    if [ -f "$DMG_NAME" ]; then
        rm "$DMG_NAME"
    fi
    
    # Create a temporary DMG
    TEMP_DMG="temp_$DMG_NAME"
    
    # Calculate size needed (add 10MB buffer)
    DMG_SIZE=$((TOTAL_SIZE_BYTES / 1024 / 1024 + 10))
    
    # Create the DMG
    hdiutil create -size ${DMG_SIZE}m -fs HFS+ -volname "Eden Updater" "$TEMP_DMG" >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # Mount the DMG
        MOUNT_POINT=$(hdiutil attach "$TEMP_DMG" | grep "/Volumes" | cut -f3)
        
        if [ -n "$MOUNT_POINT" ]; then
            # Copy files to the mounted DMG
            cp -R "$OUTER_PACKAGE_DIR/$INNER_PACKAGE_DIR"/* "$MOUNT_POINT/"
            
            # Create a symbolic link to Applications folder for easy installation
            ln -s /Applications "$MOUNT_POINT/Applications"
            
            # Unmount the DMG
            hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1
            
            # Convert to compressed read-only DMG
            hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_NAME" >/dev/null 2>&1
            
            # Clean up temporary DMG
            rm "$TEMP_DMG"
            
            if [ -f "$DMG_NAME" ]; then
                DMG_SIZE_ACTUAL=$(stat -f%z "$DMG_NAME" 2>/dev/null || stat -c%s "$DMG_NAME" 2>/dev/null)
                DMG_SIZE_IN_MB=$(echo "scale=2; $DMG_SIZE_ACTUAL / 1024 / 1024" | bc -l 2>/dev/null || echo "$(($DMG_SIZE_ACTUAL / 1024 / 1024))")
                echo "DMG file created: $DMG_NAME (${DMG_SIZE_IN_MB} MB)"
                echo ""
                echo "The DMG includes:"
                echo "  - EdenUpdater.app (drag to Applications folder to install)"
                echo "  - README.txt with usage instructions"
                echo "  - Command-line launcher script"
                echo "  - Installation script for Applications folder"
                echo "  - Applications folder shortcut for easy installation"
            else
                echo "Warning: DMG creation failed during compression"
            fi
        else
            echo "Warning: Failed to mount temporary DMG"
            rm "$TEMP_DMG"
        fi
    else
        echo "Warning: Failed to create temporary DMG"
    fi
else
    echo "hdiutil not found - DMG creation skipped"
    echo "You can manually create a DMG using Disk Utility or distribute the folder as-is"
fi

echo ""
echo "Packaging complete!"
echo ""
echo "Distribution options:"
echo "1. Distribute the $OUTER_PACKAGE_DIR/ folder as a ZIP file"
if [ -f "EdenUpdater_macOS.dmg" ]; then
    echo "2. Distribute the EdenUpdater_macOS.dmg file (recommended for macOS)"
fi
echo ""
echo "Users can:"
echo "- Double-click EdenUpdater.app to run"
echo "- Drag EdenUpdater.app to Applications folder to install"
echo "- Run install_to_applications.sh for automatic installation"