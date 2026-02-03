#!/bin/bash
# Setup script for NvrEndingTxt

set -e

echo "🚀 Setting up NvrEndingTxt..."

# Check for XcodeGen
if command -v xcodegen &> /dev/null; then
    echo "✅ XcodeGen found, generating project..."
    xcodegen generate
    echo "✅ Project generated! Open NvrEndingTxt.xcodeproj"
else
    echo "⚠️  XcodeGen not found."
    echo ""
    echo "Option 1: Install XcodeGen (recommended)"
    echo "  brew install xcodegen"
    echo "  Then run this script again."
    echo ""
    echo "Option 2: Create project manually in Xcode"
    echo "  1. Open Xcode → File → New → Project"
    echo "  2. Choose macOS → App"
    echo "  3. Product Name: NvrEndingTxt"
    echo "  4. Interface: SwiftUI, Language: Swift"
    echo "  5. Delete the auto-generated files"
    echo "  6. Drag the NvrEndingTxt folder into the project"
    echo "  7. Set Info.plist path in Build Settings"
    echo "  8. Enable LSUIElement in Info.plist"
    echo ""
    echo "Would you like to install XcodeGen? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if command -v brew &> /dev/null; then
            brew install xcodegen
            xcodegen generate
            echo "✅ Project generated! Open NvrEndingTxt.xcodeproj"
        else
            echo "❌ Homebrew not found. Install from https://brew.sh"
            exit 1
        fi
    fi
fi
