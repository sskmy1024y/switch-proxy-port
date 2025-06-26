#!/bin/bash

# Simple SwitchProxyPort.app Builder (without custom icons)
set -e

echo "🚀 Building SwitchProxyPort.app (simple version)..."

# Configuration
APP_NAME="SwitchProxyPort"
BUNDLE_ID="com.example.switchproxyport"
VERSION="1.0.0"
BUILD_DIR=".build/release"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

# Clean previous build
if [ -d "$APP_DIR" ]; then
    echo "🧹 Cleaning previous build..."
    rm -rf "$APP_DIR"
fi

# Build release version
echo "🔨 Building release binary..."
swift build -c release

# Create app bundle structure
echo "📁 Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
echo "📦 Copying executable..."
cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/"

# Create Info.plist (without icon reference if no icon available)
echo "📄 Creating Info.plist..."
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleDisplayName</key>
    <string>SwitchProxyPort</string>
    <key>CFBundleGetInfoString</key>
    <string>SwitchProxyPort $VERSION</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
</dict>
</plist>
EOF

# Try to copy a system icon as fallback
echo "🎨 Setting up app icon..."
SYSTEM_ICONS=(
    "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"
    "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ExecutableBinaryIcon.icns"
    "/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns"
)

ICON_COPIED=false
for icon_path in "${SYSTEM_ICONS[@]}"; do
    if [ -f "$icon_path" ]; then
        echo "📋 Using system icon: $(basename "$icon_path")"
        cp "$icon_path" "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null && {
            ICON_COPIED=true
            
            # Update Info.plist to include icon
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS_DIR/Info.plist" 2>/dev/null
            
            /usr/libexec/PlistBuddy -c "Add :CFBundleIconName string AppIcon" "$CONTENTS_DIR/Info.plist" 2>/dev/null || \
            /usr/libexec/PlistBuddy -c "Set :CFBundleIconName AppIcon" "$CONTENTS_DIR/Info.plist" 2>/dev/null
            
            break
        }
    fi
done

if [ "$ICON_COPIED" = false ]; then
    echo "⚠️  No system icons found, app will use default icon"
fi

# Set permissions
echo "🔐 Setting permissions..."
chmod +x "$MACOS_DIR/$APP_NAME"

# Create launch script for easier distribution
echo "📜 Creating launch helper..."
cat > "Launch-$APP_NAME.command" << EOF
#!/bin/bash
cd "\$(dirname "\$0")"
open "$APP_NAME.app"
EOF
chmod +x "Launch-$APP_NAME.command"

# Verify bundle structure
echo "🔍 Verifying app bundle..."
if [ -f "$MACOS_DIR/$APP_NAME" ] && [ -f "$CONTENTS_DIR/Info.plist" ]; then
    echo "✅ App bundle created successfully!"
    echo ""
    echo "📱 SwitchProxyPort.app is ready!"
    echo "📍 Location: $(pwd)/$APP_DIR"
    echo ""
    echo "🚀 To run the app:"
    echo "   • Double-click SwitchProxyPort.app"
    echo "   • Or run: open $APP_DIR"
    echo "   • Or use: ./Launch-$APP_NAME.command"
    echo ""
    echo "📦 Distribution:"
    echo "   • The entire $APP_DIR folder can be distributed"
    echo "   • Users can drag it to Applications folder"
    echo "   • Or run directly from any location"
    echo ""
    
    # Show bundle info
    echo "📋 Bundle Information:"
    echo "   • Name: $APP_NAME"
    echo "   • Version: $VERSION"
    echo "   • Bundle ID: $BUNDLE_ID"
    echo "   • Minimum macOS: 12.0"
    echo "   • Architecture: $(uname -m)"
    
    if [ "$ICON_COPIED" = true ]; then
        echo "   • Icon: System icon (AppIcon.icns)"
    else
        echo "   • Icon: Default system icon"
    fi
    
    # Calculate size
    BUNDLE_SIZE=$(du -sh "$APP_DIR" | cut -f1)
    echo "   • Size: $BUNDLE_SIZE"
    
    echo ""
    echo "🎯 Quick Test:"
    echo "   open $APP_DIR"
    
else
    echo "❌ Failed to create app bundle"
    exit 1
fi