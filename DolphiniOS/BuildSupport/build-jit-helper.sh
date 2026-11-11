#!/bin/bash
set -euo pipefail
root="$(cd "$SRCROOT/../../.." && pwd)"
helper="$root/BuildSupport/JITHelper"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcodebuild \
  -project "$helper/MotionRemoteJITHelper.xcodeproj" -scheme MotionRemoteJITHelper \
  -configuration Release -sdk iphoneos -derivedDataPath "$helper/DerivedData" \
  CODE_SIGNING_ALLOWED=NO 'OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sandbox' \
  MARKETING_VERSION="$MARKETING_VERSION" CURRENT_PROJECT_VERSION="$CURRENT_PROJECT_VERSION" \
  build > "$helper/build.log" 2>&1 || { tail -80 "$helper/build.log"; exit 1; }
mkdir -p "$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/PlugIns" "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH"
/usr/bin/ditto "$helper/DerivedData/Build/Products/Release-iphoneos/MotionRemoteJITHelper.appex" \
  "$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/PlugIns/MotionRemoteJITHelper.appex"
/usr/bin/ditto "$helper/Vendor/StikJIT.xcframework/ios-arm64/StikJIT.framework" \
  "$TARGET_BUILD_DIR/$FRAMEWORKS_FOLDER_PATH/StikJIT.framework"
cp "$helper/StikJIT-LICENSE" "$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/StikJIT-LICENSE.txt"
