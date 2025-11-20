#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory (export/scripts)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root (two levels up from export/scripts)
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Swift package directory (export/darwin)
DARWIN_DIR="$PROJECT_ROOT/export/darwin"
OUTPUT_DIR="$DARWIN_DIR/xcframework"
BUILD_DIR="$DARWIN_DIR/build"
HEADER_FILE="$PROJECT_ROOT/include/dianyaapi_ffi.h"

echo -e "${GREEN}=== Building DianyaAPI XCFramework ===${NC}"

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$OUTPUT_DIR"
rm -rf "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$BUILD_DIR"

# Check if cargo is available
if ! command -v cargo &> /dev/null; then
    echo -e "${RED}Error: cargo not found. Please install Rust toolchain.${NC}"
    exit 1
fi

# Check if xcodebuild is available
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
    exit 1
fi

# Check if header file exists
if [ ! -f "$HEADER_FILE" ]; then
    echo -e "${YELLOW}Header file not found, generating...${NC}"
    cd "$PROJECT_ROOT"
    cargo build --release -p dianyaapi-ffi
fi

# Define targets
TARGETS=(
    "aarch64-apple-ios"
    "aarch64-apple-ios-sim"
    "aarch64-apple-darwin"
    "x86_64-apple-darwin"
)

# Build Rust libraries for each target
echo -e "${GREEN}Building Rust libraries...${NC}"
cd "$PROJECT_ROOT"

for target in "${TARGETS[@]}"; do
    echo -e "${YELLOW}Building for $target...${NC}"
    cargo build --release --target "$target" -p dianyaapi-ffi
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to build for $target${NC}"
        exit 1
    fi
done

echo -e "${GREEN}All Rust libraries built successfully${NC}"

# Create frameworks for each platform
FRAMEWORKS=()

# iOS Device (arm64)
echo -e "${YELLOW}Creating iOS framework...${NC}"
IOS_FRAMEWORK="$BUILD_DIR/ios-arm64/DianyaAPIFFI.framework"
mkdir -p "$IOS_FRAMEWORK/Headers"
mkdir -p "$IOS_FRAMEWORK/Modules"

cp "$HEADER_FILE" "$IOS_FRAMEWORK/Headers/dianyaapi_ffi.h"
cp "$PROJECT_ROOT/target/aarch64-apple-ios/release/libdianyaapi_ffi.a" "$IOS_FRAMEWORK/DianyaAPIFFI"

# Create module map
cat > "$IOS_FRAMEWORK/Modules/module.modulemap" <<EOF
framework module DianyaAPIFFI {
    umbrella header "dianyaapi_ffi.h"
    export *
    module * { export * }
}
EOF

# Create Info.plist
cat > "$IOS_FRAMEWORK/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleIdentifier</key>
    <string>com.dianyaapi.ffi</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleExecutable</key>
    <string>DianyaAPIFFI</string>
    <key>CFBundleName</key>
    <string>DianyaAPIFFI</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>13.0</string>
</dict>
</plist>
EOF

FRAMEWORKS+=("$IOS_FRAMEWORK")

# iOS Simulator (arm64)
echo -e "${YELLOW}Creating iOS Simulator framework...${NC}"
IOS_SIM_FRAMEWORK="$BUILD_DIR/ios-arm64-simulator/DianyaAPIFFI.framework"
mkdir -p "$IOS_SIM_FRAMEWORK/Headers"
mkdir -p "$IOS_SIM_FRAMEWORK/Modules"

cp "$HEADER_FILE" "$IOS_SIM_FRAMEWORK/Headers/dianyaapi_ffi.h"
cp "$PROJECT_ROOT/target/aarch64-apple-ios-sim/release/libdianyaapi_ffi.a" "$IOS_SIM_FRAMEWORK/DianyaAPIFFI"

cp "$IOS_FRAMEWORK/Modules/module.modulemap" "$IOS_SIM_FRAMEWORK/Modules/module.modulemap"
cp "$IOS_FRAMEWORK/Info.plist" "$IOS_SIM_FRAMEWORK/Info.plist"

FRAMEWORKS+=("$IOS_SIM_FRAMEWORK")

# macOS (arm64 + x86_64 universal)
echo -e "${YELLOW}Creating macOS framework...${NC}"
MACOS_FRAMEWORK="$BUILD_DIR/macos/DianyaAPIFFI.framework"
mkdir -p "$MACOS_FRAMEWORK/Headers"
mkdir -p "$MACOS_FRAMEWORK/Modules"

cp "$HEADER_FILE" "$MACOS_FRAMEWORK/Headers/dianyaapi_ffi.h"

# Create universal binary for macOS
lipo -create \
    "$PROJECT_ROOT/target/aarch64-apple-darwin/release/libdianyaapi_ffi.a" \
    "$PROJECT_ROOT/target/x86_64-apple-darwin/release/libdianyaapi_ffi.a" \
    -output "$MACOS_FRAMEWORK/DianyaAPIFFI"

cp "$IOS_FRAMEWORK/Modules/module.modulemap" "$MACOS_FRAMEWORK/Modules/module.modulemap"

# Update Info.plist for macOS
cat > "$MACOS_FRAMEWORK/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleIdentifier</key>
    <string>com.dianyaapi.ffi</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleExecutable</key>
    <string>DianyaAPIFFI</string>
    <key>CFBundleName</key>
    <string>DianyaAPIFFI</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>10.15</string>
</dict>
</plist>
EOF

FRAMEWORKS+=("$MACOS_FRAMEWORK")

# Create XCFramework
echo -e "${GREEN}Creating XCFramework...${NC}"
XCFRAMEWORK_PATH="$OUTPUT_DIR/DianyaAPIFFI.xcframework"

xcodebuild -create-xcframework \
    -framework "$IOS_FRAMEWORK" \
    -framework "$IOS_SIM_FRAMEWORK" \
    -framework "$MACOS_FRAMEWORK" \
    -output "$XCFRAMEWORK_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to create XCFramework${NC}"
    exit 1
fi

# Verify architectures and library files
echo -e "${GREEN}Verifying architectures and libraries...${NC}"
echo "iOS framework architectures:"
lipo -info "$IOS_FRAMEWORK/DianyaAPIFFI"
echo "iOS Simulator framework architectures:"
lipo -info "$IOS_SIM_FRAMEWORK/DianyaAPIFFI"
echo "macOS framework architectures:"
lipo -info "$MACOS_FRAMEWORK/DianyaAPIFFI"
echo ""
echo -e "${GREEN}Library files verification:${NC}"
echo "  ✅ iOS: $IOS_FRAMEWORK/DianyaAPIFFI ($(stat -f%z "$IOS_FRAMEWORK/DianyaAPIFFI" 2>/dev/null || stat -c%s "$IOS_FRAMEWORK/DianyaAPIFFI" 2>/dev/null || echo "N/A") bytes)"
echo "  ✅ iOS Simulator: $IOS_SIM_FRAMEWORK/DianyaAPIFFI ($(stat -f%z "$IOS_SIM_FRAMEWORK/DianyaAPIFFI" 2>/dev/null || stat -c%s "$IOS_SIM_FRAMEWORK/DianyaAPIFFI" 2>/dev/null || echo "N/A") bytes)"
echo "  ✅ macOS: $MACOS_FRAMEWORK/DianyaAPIFFI ($(stat -f%z "$MACOS_FRAMEWORK/DianyaAPIFFI" 2>/dev/null || stat -c%s "$MACOS_FRAMEWORK/DianyaAPIFFI" 2>/dev/null || echo "N/A") bytes)"
echo ""
echo -e "${GREEN}Header files verification:${NC}"
echo "  ✅ iOS: $IOS_FRAMEWORK/Headers/dianyaapi_ffi.h"
echo "  ✅ iOS Simulator: $IOS_SIM_FRAMEWORK/Headers/dianyaapi_ffi.h"
echo "  ✅ macOS: $MACOS_FRAMEWORK/Headers/dianyaapi_ffi.h"

echo -e "${GREEN}=== Build Complete ===${NC}"
echo -e "XCFramework location: ${GREEN}$XCFRAMEWORK_PATH${NC}"

# Create complete distribution package
echo -e "${GREEN}Creating complete distribution package...${NC}"
DIST_DIR="$OUTPUT_DIR/DianyaAPI-Distribution"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 1. Copy XCFramework
echo -e "${YELLOW}  - Copying XCFramework...${NC}"
cp -R "$XCFRAMEWORK_PATH" "$DIST_DIR/"

# 2. Copy Swift Package (entire directory structure)
echo -e "${YELLOW}  - Copying Swift Package...${NC}"
cp "$DARWIN_DIR/Package.swift" "$DIST_DIR/"
cp "$DARWIN_DIR/README.md" "$DIST_DIR/"
cp -R "$DARWIN_DIR/Sources" "$DIST_DIR/"

# 2.1. Copy original header file to Sources directory for distribution
# Copy as dianyaapi_ffi_original.h to avoid conflict with bridge header
# This ensures the header file is available when distributing the package
echo -e "${YELLOW}  - Copying header file to Sources...${NC}"
cp "$HEADER_FILE" "$DIST_DIR/Sources/DianyaAPI/dianyaapi_ffi_original.h"
echo -e "${GREEN}    ✓ Header file copied: $DIST_DIR/Sources/DianyaAPI/dianyaapi_ffi_original.h${NC}"

# 3. Check for and copy LICENSE file if exists
if [ -f "$PROJECT_ROOT/LICENSE" ]; then
    echo -e "${YELLOW}  - Copying LICENSE...${NC}"
    cp "$PROJECT_ROOT/LICENSE" "$DIST_DIR/"
elif [ -f "$PROJECT_ROOT/LICENSE.txt" ]; then
    echo -e "${YELLOW}  - Copying LICENSE.txt...${NC}"
    cp "$PROJECT_ROOT/LICENSE.txt" "$DIST_DIR/LICENSE"
fi

# 4. Create .gitignore for distribution
cat > "$DIST_DIR/.gitignore" <<EOF
xcframework/
build/
.DS_Store
*.xcodeproj
*.xcworkspace
EOF

# 5. Create installation instructions
cat > "$DIST_DIR/INSTALL.md" <<EOF
# Installation Instructions

## Option 1: Swift Package Manager (Recommended)

### Local Package
1. In Xcode, go to **File > Add Packages...**
2. Click **Add Local...**
3. Select this directory
4. The package will automatically link to the included XCFramework
5. **No additional setup needed** - the XCFramework contains all static libraries

### Remote Package (if hosted)
1. In Xcode, go to **File > Add Packages...**
2. Enter the package URL
3. Select version and add to your project
4. **No additional setup needed** - the XCFramework contains all static libraries

### How It Works
- \`Package.swift\` uses \`binaryTarget\` to reference \`DianyaAPIFFI.xcframework\`
- The XCFramework contains static libraries (\`libdianyaapi_ffi.a\`) for all platforms:
  - iOS arm64
  - iOS Simulator arm64
  - macOS arm64 + x86_64 (universal binary)
- Swift Package Manager automatically links the correct library for your target platform
- Header files are included in the XCFramework and also copied to \`Sources/DianyaAPI/\`

## Option 2: Manual Integration

### Step 1: Add XCFramework (contains static libraries)
1. Drag \`DianyaAPIFFI.xcframework\` into your Xcode project
2. In **Target Settings > General > Frameworks, Libraries, and Embedded Content**
3. Set \`DianyaAPIFFI.xcframework\` to **Embed & Sign**
4. The XCFramework contains all required static libraries for iOS and macOS

### Step 2: Add Swift Sources
1. Copy \`Sources/DianyaAPI\` folder to your project
2. Ensure all Swift files are added to your target
3. The header file \`dianyaapi_ffi_original.h\` is included in Sources/DianyaAPI/
4. Import: \`import DianyaAPI\`

**Important Notes:**
- The XCFramework already contains all static libraries (\`libdianyaapi_ffi.a\`) for all platforms
- Each Framework in the XCFramework has a binary file (\`DianyaAPIFFI\`) which is the static library
- No additional \`.a\` or \`.dylib\` files need to be copied manually
- The header file \`dianyaapi_ffi_original.h\` is included in \`Sources/DianyaAPI/\` for Swift code access

## Library Files Location

The static libraries are embedded in the XCFramework:
- \`DianyaAPIFFI.xcframework/ios-arm64/DianyaAPIFFI.framework/DianyaAPIFFI\` (iOS static library)
- \`DianyaAPIFFI.xcframework/ios-arm64-simulator/DianyaAPIFFI.framework/DianyaAPIFFI\` (iOS Simulator static library)
- \`DianyaAPIFFI.xcframework/macos-arm64_x86_64/DianyaAPIFFI.framework/DianyaAPIFFI\` (macOS universal static library)

These are automatically linked when using Swift Package Manager or when adding the XCFramework to your project.

## Verification

After installation, you should be able to:

\`\`\`swift
import DianyaAPI

let api = DianyaAPI.TranscribeApi(token: "your_token")
\`\`\`

If this compiles without errors, the installation is successful.
EOF

# 6. Create a quick start guide
cat > "$DIST_DIR/QUICKSTART.md" <<EOF
# Quick Start Guide

## 1. Initialize the API

\`\`\`swift
import DianyaAPI

let token = "Bearer your_token_here"
let api = DianyaAPI.TranscribeApi(token: token)
\`\`\`

## 2. Upload Audio File

\`\`\`swift
do {
    let result = try await api.upload(
        filePath: "/path/to/audio.wav",
        model: .quality
    )
    
    switch result {
    case .normal(let taskId):
        print("Task ID: \\(taskId)")
    case .oneSentence(let status, let message, let data):
        print("Result: \\(data)")
    }
} catch {
    print("Error: \\(error)")
}
\`\`\`

## 3. Get Transcription Status

\`\`\`swift
do {
    let status = try await api.getStatus(taskId: "your_task_id")
    print("Status: \\(status.status)")
    
    for utterance in status.details {
        print("\\(utterance.text)")
    }
} catch {
    print("Error: \\(error)")
}
\`\`\`

## 4. Real-time Transcription (WebSocket)

\`\`\`swift
// Create session (static method)
let session = try await DianyaAPI.TranscribeStream.createSession(
    token: token,
    model: .speed
)

// Create stream instance
let stream = DianyaAPI.TranscribeStream(sessionInfo: session)

// Connect
try await stream.connect()

// Receive messages with Combine
stream.messagePublisher
    .sink { message in
        print("Received: \\(message)")
    }
    .store(in: &cancellables)

// Send audio
try await stream.sendAudio(audioData)
\`\`\`

For more details, see [README.md](README.md)
EOF

echo -e "${GREEN}=== Complete Distribution Package Created ===${NC}"
echo -e "Distribution location: ${GREEN}$DIST_DIR${NC}"
echo ""
echo "Contents:"
echo "  📦 DianyaAPIFFI.xcframework - C FFI library (contains static libraries for all platforms)"
echo "     - iOS arm64: libdianyaapi_ffi.a"
echo "     - iOS Simulator arm64: libdianyaapi_ffi.a"
echo "     - macOS arm64 + x86_64: libdianyaapi_ffi.a (universal)"
echo "  📝 Sources/ - Swift source code (includes header file)"
echo "  ⚙️  Package.swift - Swift Package configuration (auto-links XCFramework)"
echo "  📖 README.md - Full documentation"
echo "  📋 INSTALL.md - Installation instructions"
echo "  🚀 QUICKSTART.md - Quick start guide"
if [ -f "$DIST_DIR/LICENSE" ]; then
    echo "  📄 LICENSE - License file"
fi
echo ""
echo "Important Notes:"
echo "  ✅ XCFramework contains all required static libraries"
echo "  ✅ Header file is included in Sources/DianyaAPI/"
echo "  ✅ Package.swift automatically links the XCFramework via binaryTarget"
echo ""
echo "Usage:"
echo "  1. Use as Swift Package (recommended): Add this directory as local package"
echo "     - SPM will automatically link the XCFramework libraries"
echo "  2. Manual integration: Follow INSTALL.md for step-by-step instructions"
echo ""
echo "XCFramework location: ${GREEN}$XCFRAMEWORK_PATH${NC}"
echo "To use XCFramework only:"
echo "  1. Drag the XCFramework into your project"
echo "  2. Add to 'Frameworks, Libraries, and Embedded Content'"
echo "  3. Import: import DianyaAPIFFI"

