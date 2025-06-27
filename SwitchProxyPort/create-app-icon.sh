#!/bin/bash

# App Icon Generator for SwitchProxyPort
# Creates a proper app icon using macOS built-in tools

set -e

ICONSET_DIR="$1"
if [ -z "$ICONSET_DIR" ]; then
    ICONSET_DIR="SwitchProxyPort.app/Contents/Resources/AppIcon.iconset"
fi

echo "🎨 Creating app icon using macOS built-in tools..."

# Create iconset directory
mkdir -p "$ICONSET_DIR"

# Create a base SVG icon content (as a temporary solution)
BASE_ICON_SVG=$(cat << 'EOF'
<svg width="512" height="512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="grad1" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#4682B4;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#1E3A8A;stop-opacity:1" />
    </linearGradient>
  </defs>
  
  <!-- Background circle -->
  <circle cx="256" cy="256" r="200" fill="url(#grad1)" stroke="#0F172A" stroke-width="8"/>
  
  <!-- Double arrow symbols (proxy indication) -->
  <!-- Right arrow -->
  <path d="M 200 256 L 280 200 L 280 230 L 320 230 L 320 282 L 280 282 L 280 312 Z" fill="white"/>
  
  <!-- Left arrow -->
  <path d="M 312 256 L 232 200 L 232 230 L 192 230 L 192 282 L 232 282 L 232 312 Z" fill="white" opacity="0.8"/>
  
  <!-- Center dot -->
  <circle cx="256" cy="256" r="12" fill="white"/>
</svg>
EOF
)

# Create temporary base icon file
TEMP_ICON="/tmp/switchproxyport_icon.svg"
echo "$BASE_ICON_SVG" > "$TEMP_ICON"

# Function to create PNG from SVG using qlmanage (Quick Look)
create_icon_png() {
    local size=$1
    local output_file="$2"
    
    # Try different methods to convert SVG to PNG
    if command -v rsvg-convert &> /dev/null; then
        # Method 1: rsvg-convert (if available)
        rsvg-convert -w $size -h $size "$TEMP_ICON" -o "$output_file"
    elif command -v convert &> /dev/null; then
        # Method 2: ImageMagick convert (if available)
        convert -background transparent -size ${size}x${size} "$TEMP_ICON" "$output_file"
    else
        # Method 3: Create a simple colored square using sips and system tools
        # Create a temporary colored image
        TEMP_BG="/tmp/temp_bg_${size}.png"
        
        # Create a simple gradient background using a 1x1 pixel and sips
        # First create a small base image
        printf "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x00\x00\x00\x01\x00\x01\x00\x00\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB\x60\x82" > /tmp/1x1.png
        
        # Resize and create colored version
        sips -z $size $size /tmp/1x1.png --out "$TEMP_BG" &>/dev/null || {
            # Fallback: create using printf and hex data for a simple blue square
            python3 -c "
from PIL import Image, ImageDraw
import sys

try:
    # Create icon with gradient and arrows
    img = Image.new('RGBA', ($size, $size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw circular background
    center = $size // 2
    radius = int($size * 0.35)
    
    # Main circle with blue gradient effect
    draw.ellipse([center-radius, center-radius, center+radius, center+radius], 
                fill=(70, 130, 180, 255), outline=(15, 23, 42, 255), width=max(1, $size//128))
    
    # Double arrow (proxy symbol)
    arrow_size = max(4, radius // 4)
    
    # Right arrow
    if $size >= 32:
        draw.polygon([
            (center + arrow_size//2, center - arrow_size//2),
            (center + arrow_size, center),
            (center + arrow_size//2, center + arrow_size//2)
        ], fill=(255, 255, 255, 255))
        
        # Left arrow
        draw.polygon([
            (center - arrow_size//2, center - arrow_size//2),
            (center - arrow_size, center),
            (center - arrow_size//2, center + arrow_size//2)
        ], fill=(255, 255, 255, 200))
    
    # Center dot
    dot_size = max(1, $size // 64)
    draw.ellipse([center-dot_size, center-dot_size, center+dot_size, center+dot_size], 
                fill=(255, 255, 255, 255))
    
    img.save('$output_file', 'PNG')
    print('✅ Created ${size}x${size} icon')
    
except ImportError:
    # Fallback to simple solid color
    print('⚠️  PIL not available, creating simple colored square')
    img = Image.new('RGBA', ($size, $size), (70, 130, 180, 255))
    img.save('$output_file', 'PNG')
    
except Exception as e:
    print(f'⚠️  Error creating icon: {e}')
    # Create minimal fallback
    with open('$output_file', 'wb') as f:
        # Minimal PNG header for blue square
        f.write(bytes.fromhex('89504e470d0a1a0a0000000d49484452000000200000002008020000006e6bbd93000000174944415478da63f84000000001000100000018dd8db4000000004945' + '4e44ae426082'))
" 2>/dev/null || {
                # Ultimate fallback: copy a system icon
                if [ -f "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" ]; then
                    echo "📋 Using system fallback icon"
                    sips -s format png -z $size $size "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns" --out "$output_file" &>/dev/null
                else
                    echo "⚠️  Creating minimal PNG placeholder"
                    touch "$output_file"
                fi
            }
        }
        
        rm -f "$TEMP_BG" /tmp/1x1.png 2>/dev/null
    fi
}

# Icon sizes for macOS app
declare -a sizes=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

echo "🖼️  Generating icon files..."

# Generate all icon sizes
for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    output_path="$ICONSET_DIR/$filename"
    
    create_icon_png "$size" "$output_path"
    
    # Verify the file was created and has content
    if [ -f "$output_path" ] && [ -s "$output_path" ]; then
        echo "✅ Created $filename (${size}x${size})"
    else
        echo "⚠️  Failed to create $filename, using fallback"
        # Create minimal fallback
        touch "$output_path"
    fi
done

# Clean up
rm -f "$TEMP_ICON" 2>/dev/null

# Create Contents.json for iconset
cat > "$ICONSET_DIR/Contents.json" << 'EOF'
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

# Check if we have valid PNG files
valid_files=0
for size_info in "${sizes[@]}"; do
    IFS=':' read -r size filename <<< "$size_info"
    if [ -s "$ICONSET_DIR/$filename" ]; then
        ((valid_files++))
    fi
done

if [ $valid_files -gt 0 ]; then
    echo "✅ Created iconset with $valid_files valid icon files"
    echo "📁 Iconset location: $ICONSET_DIR"
    return 0
else
    echo "⚠️  No valid icon files created"
    return 1
fi