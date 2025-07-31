#!/bin/bash

echo "Packaging Eden Updater for macOS..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Build the release version
echo -e "${YELLOW}Building release version...${NC}"
flutter build macos --release
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
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

echo -e "${YELLOW}Creating package structure...${NC}"
mkdir -p "$OUTER_PACKAGE_DIR/$INNER_PACKAGE_DIR"

# Copy the built app bundle
echo -e "${YELLOW}Copying application bundle...${NC}"
cp -R "build/macos/Build/Products/Release/eden_updater.app" "$OUTER_PACKAGE_DIR/$INNER_PACKAGE_DIR/"

# Copy additional files
echo -e "${YELLOW}Copying additional files...${NC}"
cp README.md "$OUTER_PACKAGE_DIR/"
cp LICENSE "$OUTER_PACKAGE_DIR/"

# Create a simple launcher script
echo -e "${YELLOW}Creating launcher script...${NC}"
cat > "$OUTER_PACKAGE_DIR/Eden Updater.command" << 'EOF'
#!/bin/bash
# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Launch the Eden Updater app
open "$SCRIPT_DIR/eden_updater/eden_updater.app"
EOF

# Make the launcher script executable
chmod +x "$OUTER_PACKAGE_DIR/Eden Updater.command"

# Create a simple uninstaller script
echo -e "${YELLOW}Creating uninstaller script...${NC}"
cat > "$OUTER_PACKAGE_DIR/Uninstall.command" << 'EOF'
#!/bin/bash
echo "Eden Updater Uninstaller"
echo "========================"
echo ""
echo "This will remove Eden Updater and its data."
echo "Eden emulator installations will NOT be removed."
echo ""
read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing Eden Updater..."
    
    # Remove from Applications if symlinked
    if [ -L "/Applications/Eden Updater.app" ]; then
        rm "/Applications/Eden Updater.app"
        echo "Removed Applications shortcut"
    fi
    
    # Remove preferences (optional)
    read -p "Remove preferences and settings? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf ~/Library/Preferences/com.example.eden_updater.plist 2>/dev/null
        echo "Removed preferences"
    fi
    
    echo "Eden Updater has been uninstalled."
    echo "You can now delete this folder."
else
    echo "Uninstall cancelled."
fi

read -p "Press any key to continue..."
EOF

# Make the uninstaller script executable
chmod +x "$OUTER_PACKAGE_DIR/Uninstall.command"

# Create installation instructions
echo -e "${YELLOW}Creating installation instructions...${NC}"
cat > "$OUTER_PACKAGE_DIR/INSTALL.txt" << 'EOF'
Eden Updater for macOS - Installation Instructions
==================================================

Installation Options:

1. SIMPLE INSTALLATION (Recommended)
   - Double-click "Eden Updater.command" to run the application
   - The app will run directly from this folder
   - You can move this entire folder anywhere you like

2. APPLICATIONS FOLDER INSTALLATION
   - Drag "eden_updater/eden_updater.app" to your Applications folder
   - Launch from Applications or Spotlight search

3. DESKTOP SHORTCUT
   - Right-click "eden_updater/eden_updater.app" and select "Make Alias"
   - Drag the alias to your Desktop
   - Rename it to "Eden Updater" if desired

System Requirements:
- macOS 10.14 (Mojave) or later
- 64-bit Intel or Apple Silicon Mac

First Run:
- You may see a security warning on first launch
- Go to System Preferences > Security & Privacy > General
- Click "Open Anyway" to allow Eden Updater to run

Uninstallation:
- Run "Uninstall.command" to remove Eden Updater
- Or simply delete this folder

Support:
- For issues, check the GitHub repository
- Eden emulator files are stored in ~/Documents/Eden/
EOF

# Get the size of the package
PACKAGE_SIZE=$(du -sh "$OUTER_PACKAGE_DIR" | cut -f1)

echo -e "${GREEN}Package created successfully!${NC}"
echo -e "Package location: ${YELLOW}$OUTER_PACKAGE_DIR/${NC}"
echo -e "Package size: ${YELLOW}$PACKAGE_SIZE${NC}"
echo ""
echo -e "${YELLOW}Contents:${NC}"
echo "  - eden_updater.app (Main application)"
echo "  - Eden Updater.command (Launcher script)"
echo "  - Uninstall.command (Uninstaller)"
echo "  - INSTALL.txt (Installation instructions)"
echo "  - README.md and LICENSE"
echo ""

# Offer to create a DMG
read -p "Create a DMG disk image? (y/N): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    DMG_NAME="EdenUpdater_macOS.dmg"
    
    echo -e "${YELLOW}Creating DMG disk image...${NC}"
    
    # Remove existing DMG if it exists
    if [ -f "$DMG_NAME" ]; then
        rm "$DMG_NAME"
    fi
    
    # Create DMG
    hdiutil create -volname "Eden Updater" -srcfolder "$OUTER_PACKAGE_DIR" -ov -format UDZO "$DMG_NAME"
    
    if [ $? -eq 0 ]; then
        DMG_SIZE=$(du -sh "$DMG_NAME" | cut -f1)
        echo -e "${GREEN}DMG created successfully!${NC}"
        echo -e "DMG location: ${YELLOW}$DMG_NAME${NC}"
        echo -e "DMG size: ${YELLOW}$DMG_SIZE${NC}"
    else
        echo -e "${RED}Failed to create DMG${NC}"
    fi
fi

echo ""
echo -e "${GREEN}macOS packaging complete!${NC}"