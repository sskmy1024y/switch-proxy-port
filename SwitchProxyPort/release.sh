#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

# Check if gh command is available
if ! command -v gh &> /dev/null; then
    print_error "gh command is not installed. Please install GitHub CLI first."
    exit 1
fi

# Claude command is not required, we'll use a fallback

# Get version from argument or prompt
if [ -z "$1" ]; then
    read -p "Enter version tag (e.g., v1.0.1): " VERSION
else
    VERSION=$1
fi

# Validate version format
if ! [[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_error "Invalid version format. Please use vX.Y.Z format (e.g., v1.0.1)"
    exit 1
fi

# Extract version number without 'v' prefix
VERSION_NUMBER=${VERSION#v}

print_status "Starting release process for version $VERSION"

# Step 1: Build the app
print_status "Step 1/4: Building the application..."

if [ -f "./build-app.sh" ]; then
    # Update version in build script
    sed -i '' "s/VERSION=\"[0-9.]*\"/VERSION=\"$VERSION_NUMBER\"/" ./build-app.sh
    
    # Run build
    ./build-app.sh
    
    if [ -d "SwitchProxyPort.app" ]; then
        print_status "✓ Application built successfully"
    else
        print_error "Application build failed"
        exit 1
    fi
else
    print_error "build-app.sh not found"
    exit 1
fi

# Step 2: Create DMG
print_status "Step 2/4: Creating DMG..."

if [ -f "./create-dmg.sh" ]; then
    # Update version in DMG script
    sed -i '' "s/SwitchProxyPort-[0-9.]*.dmg/SwitchProxyPort-$VERSION_NUMBER.dmg/" ./create-dmg.sh
    
    # Run DMG creation
    ./create-dmg.sh
    
    DMG_FILE="SwitchProxyPort-$VERSION_NUMBER.dmg"
    if [ -f "$DMG_FILE" ]; then
        print_status "✓ DMG created: $DMG_FILE"
    else
        print_error "DMG creation failed"
        exit 1
    fi
else
    print_error "create-dmg.sh not found"
    exit 1
fi

# Step 3: Generate release notes
print_status "Step 3/4: Generating release notes..."

# Get the previous tag
PREVIOUS_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [ -z "$PREVIOUS_TAG" ]; then
    # First release
    RELEASE_NOTES="## SwitchProxyPort $VERSION

🎉 **First Release!**

### Features
- 🌐 Simple HTTP proxy server with configurable ports
- 🎨 Modern macOS menu bar interface
- ⚙️ Easy proxy configuration via preferences window
- 🔄 Quick proxy toggle with keyboard shortcuts
- 💾 Automatic settings persistence
- 🚀 Launch at login support

### Installation
1. Download the DMG file below
2. Drag SwitchProxyPort to your Applications folder
3. Launch the app from Applications
4. The app will appear in your menu bar

### Requirements
- macOS 12.0 or later
- No additional dependencies required
"
else
    # Get commit messages since last tag
    COMMITS=$(git log --pretty=format:"- %s" $PREVIOUS_TAG..HEAD 2>/dev/null || echo "")
    
    if [ -z "$COMMITS" ]; then
        COMMITS="- Various improvements and bug fixes"
    fi
    
    # Create release notes based on commits
    RELEASE_NOTES="## SwitchProxyPort $VERSION

### What's Changed
$COMMITS

### Installation
Download the DMG file below and follow the installation instructions.

### Full Changelog
Compare changes: [$PREVIOUS_TAG...$VERSION](../../compare/$PREVIOUS_TAG...$VERSION)
"
fi

print_status "✓ Release notes prepared"

# Save release notes to file
echo "$RELEASE_NOTES" > release_notes.md
print_status "✓ Release notes generated"

# Step 4: Create GitHub release
print_status "Step 4/4: Creating GitHub release..."

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    print_error "Not in a git repository"
    exit 1
fi

# Check if the tag already exists
if git rev-parse "$VERSION" >/dev/null 2>&1; then
    print_error "Tag $VERSION already exists"
    exit 1
fi

# Create and push tag
print_status "Creating tag $VERSION..."
git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

# Create release with gh command
print_status "Creating GitHub release..."
gh release create "$VERSION" \
    --title "SwitchProxyPort $VERSION" \
    --notes-file release_notes.md \
    "$DMG_FILE"

# Clean up
rm -f release_notes.md

print_status "🎉 Release $VERSION completed successfully!"
print_status "View the release at: $(gh release view $VERSION --json url -q .url)"

# Notify user (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e "display notification \"Release $VERSION completed successfully!\" with title \"SwitchProxyPort Release\" sound name \"Glass\""
fi