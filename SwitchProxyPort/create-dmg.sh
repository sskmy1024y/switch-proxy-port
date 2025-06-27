#!/bin/bash

# Create DMG for distribution
set -e

APP_NAME="SwitchProxyPort"
VERSION="1.0.0"
DMG_NAME="$APP_NAME-$VERSION"
DMG_FILE="$DMG_NAME.dmg"
TEMP_DMG="temp_$DMG_NAME.dmg"
VOLUME_NAME="$APP_NAME $VERSION"

echo "📦 Creating DMG for $APP_NAME..."

# Check if app exists
if [ ! -d "$APP_NAME.app" ]; then
    echo "❌ $APP_NAME.app not found. Run ./build-app.sh first."
    exit 1
fi

# Clean previous DMG
if [ -f "$DMG_FILE" ]; then
    echo "🧹 Removing existing DMG..."
    rm "$DMG_FILE"
fi

if [ -f "$TEMP_DMG" ]; then
    rm "$TEMP_DMG"
fi

# Create temporary directory for DMG contents
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Copy app to temp directory
echo "📋 Copying app..."
cp -R "$APP_NAME.app" "$TEMP_DIR/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "$TEMP_DIR/Applications"

# Create README for DMG
echo "📝 Creating installation instructions..."
cat > "$TEMP_DIR/Install Instructions.txt" << EOF
SwitchProxyPort Installation Instructions
========================================

1. Drag SwitchProxyPort.app to the Applications folder
2. Double-click SwitchProxyPort.app to launch
3. The app will appear in your menu bar
4. Click the menu bar icon to configure and use the proxy

Features:
- Proxy server with configurable ports
- Menu bar interface for easy access
- Modern preferences window
- Automatic settings persistence

System Requirements:
- macOS 12.0 or later
- No additional dependencies required

For support or issues, please visit the project repository.
EOF

# Calculate size needed for DMG (add 50MB padding)
SIZE_KB=$(du -sk "$TEMP_DIR" | cut -f1)
SIZE_MB=$((SIZE_KB / 1024 + 50))

echo "📏 DMG size: ${SIZE_MB}MB"

# Create DMG
echo "🔨 Creating DMG..."
hdiutil create -srcfolder "$TEMP_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${SIZE_MB}m" \
    "$TEMP_DMG"

# Mount the DMG for customization
echo "🔧 Mounting DMG for customization..."
# Capture the full output and extract device info
ATTACH_OUTPUT=$(hdiutil attach "$TEMP_DMG" -readwrite -noautoopen)
# Extract the base device (e.g., /dev/disk9 from /dev/disk9s1)
DEVICE=$(echo "$ATTACH_OUTPUT" | awk '/Apple_HFS/ {print $1}' | sed 's/s[0-9]*$//')
MOUNT_POINT="/Volumes/$VOLUME_NAME"

# Debug output
echo "Attach output: $ATTACH_OUTPUT"
echo "Extracted device: $DEVICE"
echo "Mount point: $MOUNT_POINT"

# Wait for mount to complete
sleep 2

# Verify mount point exists
if [ ! -d "$MOUNT_POINT" ]; then
    echo "⚠️  Mount point not found at expected location, skipping customization"
else
    # Set DMG window properties (if possible)
    echo "🎨 Customizing DMG appearance..."
    if command -v osascript &> /dev/null; then
        osascript << EOF
tell application "Finder"
    try
        tell disk "$VOLUME_NAME"
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set the bounds of container window to {100, 100, 600, 400}
            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 128
            delay 1
            set position of item "$APP_NAME.app" of container window to {150, 200}
            set position of item "Applications" of container window to {350, 200}
            update without registering applications
            delay 2
            close
        end tell
    on error errMsg
        -- Ignore errors during customization
        -- echo "AppleScript error (ignored): " & errMsg
    end try
end tell
EOF
    fi
fi

# Unmount DMG
echo "📤 Unmounting DMG..."

# Try unmounting by mount point first (more reliable)
if [ -d "$MOUNT_POINT" ]; then
    echo "Unmounting $MOUNT_POINT..."
    diskutil unmount "$MOUNT_POINT" 2>/dev/null || true
    sleep 2
fi

# Then try to detach the device if it still exists
if [ -n "$DEVICE" ]; then
    echo "Detaching device $DEVICE..."
    hdiutil detach "$DEVICE" -quiet 2>/dev/null || hdiutil detach "$DEVICE" -force 2>/dev/null || true
fi

# Extra wait to ensure resources are released
sleep 3

# Convert to read-only compressed DMG
echo "🗜️  Converting to compressed DMG..."
hdiutil convert "$TEMP_DMG" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_FILE"

# Clean up
rm "$TEMP_DMG"
rm -rf "$TEMP_DIR"

# Verify DMG
if [ -f "$DMG_FILE" ]; then
    DMG_SIZE=$(du -sh "$DMG_FILE" | cut -f1)
    echo "✅ DMG created successfully!"
    echo ""
    echo "📁 File: $DMG_FILE"
    echo "📏 Size: $DMG_SIZE"
    echo ""
    echo "🚀 Distribution ready!"
    echo "   • Users can double-click the DMG to open"
    echo "   • Drag $APP_NAME.app to Applications folder"
    echo "   • The app will be installed and ready to use"
    echo ""
    echo "🔍 To test the DMG:"
    echo "   open \"$DMG_FILE\""
else
    echo "❌ Failed to create DMG"
    exit 1
fi