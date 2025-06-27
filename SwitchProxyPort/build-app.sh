#!/bin/bash

# SwitchProxyPort.app Bundle Creator
# This script creates a distributable macOS app bundle

set -e

echo "🚀 Building SwitchProxyPort.app..."

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

# Create Info.plist
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
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

# Create simple app icon (using SF Symbols reference)
echo "🎨 Creating app icon..."
# Create a simple iconset structure
ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

# Create Contents.json for iconset
cat > "$ICONSET_DIR/Contents.json" << EOF
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16",
      "filename" : "icon_16x16.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16",
      "filename" : "icon_16x16@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32",
      "filename" : "icon_32x32.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32",
      "filename" : "icon_32x32@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128",
      "filename" : "icon_128x128.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128",
      "filename" : "icon_128x128@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256",
      "filename" : "icon_256x256.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256",
      "filename" : "icon_256x256@2x.png"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512",
      "filename" : "icon_512x512.png"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512",
      "filename" : "icon_512x512@2x.png"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

# Use the new CenteredAppIcon.icns if available
echo "🖼️  Setting up app icon..."
# First check for Resources/AppIcon.png
if [ -f "Resources/AppIcon.png" ]; then
    echo "✅ Using Resources/AppIcon.png"
    # Create temporary iconset
    mkdir -p "$ICONSET_DIR"
    
    # Generate all required sizes
    sips -z 16 16     Resources/AppIcon.png --out "$ICONSET_DIR/icon_16x16.png" >/dev/null 2>&1
    sips -z 32 32     Resources/AppIcon.png --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null 2>&1
    sips -z 32 32     Resources/AppIcon.png --out "$ICONSET_DIR/icon_32x32.png" >/dev/null 2>&1
    sips -z 64 64     Resources/AppIcon.png --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null 2>&1
    sips -z 128 128   Resources/AppIcon.png --out "$ICONSET_DIR/icon_128x128.png" >/dev/null 2>&1
    sips -z 256 256   Resources/AppIcon.png --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null 2>&1
    sips -z 256 256   Resources/AppIcon.png --out "$ICONSET_DIR/icon_256x256.png" >/dev/null 2>&1
    sips -z 512 512   Resources/AppIcon.png --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null 2>&1
    sips -z 512 512   Resources/AppIcon.png --out "$ICONSET_DIR/icon_512x512.png" >/dev/null 2>&1
    sips -z 1024 1024 Resources/AppIcon.png --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null 2>&1
    
    # Convert to icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null
    rm -rf "$ICONSET_DIR"
elif [ -f "../assets/icons/CenteredAppIcon.icns" ]; then
    echo "✅ Using CenteredAppIcon.icns"
    cp "../assets/icons/CenteredAppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
else
    # Fall back to generating icons
    echo "⚠️  CenteredAppIcon.icns not found, generating app icons..."
    if [ -f "./create-app-icon.sh" ]; then
        source ./create-app-icon.sh "$ICONSET_DIR"
        ICON_RESULT=$?
    else
        echo "⚠️  create-app-icon.sh not found, creating placeholder icons..."
        for size in "16x16" "16x16@2x" "32x32" "32x32@2x" "128x128" "128x128@2x" "256x256" "256x256@2x" "512x512" "512x512@2x"; do
            touch "$ICONSET_DIR/icon_$size.png"
        done
        ICON_RESULT=1
    fi

    # Convert iconset to icns (if iconutil is available and we have valid icons)
    if command -v iconutil &> /dev/null && [ $ICON_RESULT -eq 0 ]; then
        echo "🎯 Converting iconset to icns..."
        if iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null; then
            echo "✅ Successfully created AppIcon.icns"
            rm -rf "$ICONSET_DIR"
        else
            echo "⚠️  Failed to convert iconset to icns, keeping iconset folder"
            echo "📝 You can manually replace icons in: $ICONSET_DIR"
        fi
    else
        if [ $ICON_RESULT -ne 0 ]; then
            echo "⚠️  Skipping ICNS conversion due to icon generation issues"
        else
            echo "⚠️  iconutil not available, keeping iconset folder"
        fi
        echo "📝 You can manually replace icons in: $ICONSET_DIR"
    fi
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
    
    # Calculate size
    BUNDLE_SIZE=$(du -sh "$APP_DIR" | cut -f1)
    echo "   • Size: $BUNDLE_SIZE"
    
else
    echo "❌ Failed to create app bundle"
    exit 1
fi
