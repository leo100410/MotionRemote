#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
APP="build/MotionSaber.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swiftc -O -Xfrontend -disable-sandbox -parse-as-library -target arm64-apple-macosx14.0 Sources/*.swift ../Monitor/Sources/MonitorWire.swift ../Sources/DSU.swift ../Sources/SpatialPose.swift ../Sources/EventLog.swift -o "$APP/Contents/MacOS/MotionSaber" -framework AppKit -framework SwiftUI -framework Network -framework SceneKit -framework AVFoundation -framework QuartzCore
cp Info.plist "$APP/Contents/Info.plist"
cp ../Assets.xcassets/AppIcon.appiconset/AppIcon.png "$APP/Contents/Resources/AppIcon.png"
codesign --force --deep --sign - "$APP"
codesign --verify --deep "$APP"
