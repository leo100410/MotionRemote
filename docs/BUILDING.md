# Build from source

## iPhone

You need Xcode with an iOS SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen). Open a terminal at the repository root:

```sh
xcodegen generate
open MotionRemote.xcodeproj
```

Choose the MotionRemote target, set your development team in **Signing & Capabilities**, select your paired iPhone and run. Change the bundle identifier if your signing team requires a different one. Do not commit signing credentials or local Xcode user settings.

For an unsigned device build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MotionRemote.xcodeproj -scheme MotionRemote \
  -configuration Release -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO build
```

The application is at `build/Build/Products/Release-iphoneos/MotionRemote.app`. Package it inside a `Payload` folder to make an IPA, then sign it with your own signing tool. A device build with signing disabled is not directly installable.

## Dolphin

The patch targets **Dolphin 2609b**. Use that exact upstream version; applying it to a newer revision is not supported.

```sh
mkdir -p DolphinBuild
git clone --branch 2609b https://github.com/dolphin-emu/dolphin.git DolphinBuild/dolphin-2609b
git -C DolphinBuild/dolphin-2609b apply ../motionremote-1.8.patch
git -C DolphinBuild/dolphin-2609b submodule update --init --recursive
```

Follow [Dolphin's macOS build instructions](https://github.com/dolphin-emu/dolphin/blob/2609b/Readme.md) for dependencies. The distributed build used CMake 4.1.2, Qt 6.8.3 and the Xcode 27.2 toolchain on Apple Silicon. Set `CMAKE_PREFIX_PATH` to your Qt installation. Local dependency discovery can select additional system libraries; this command is a build recipe, not a bit-for-bit reproducibility claim.

```sh
cmake -S DolphinBuild/dolphin-2609b -B DolphinBuild/build \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES=arm64 \
  -DCMAKE_PREFIX_PATH="$QT_PREFIX" -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DENABLE_QT=ON -DENABLE_NOGUI=OFF -DENABLE_TESTS=OFF \
  -DENABLE_VULKAN=OFF -DUSE_MGBA=OFF -DUSE_RETRO_ACHIEVEMENTS=OFF \
  -DUSE_DISCORD_PRESENCE=OFF -DENABLE_AUTOUPDATE=OFF \
  -DENABLE_ANALYTICS=OFF -DENCODE_FRAMEDUMPS=OFF \
  -DMACOS_CODE_SIGNING=OFF -DPOSTPROCESS_BUNDLE=OFF
cmake --build DolphinBuild/build --target dolphin-emu --parallel 6
```

The app is produced under `DolphinBuild/build/Binaries/DolphinQt.app`. Packaging requires Qt's `macdeployqt`, copying dependent libraries and signing the completed bundle. Preserve Dolphin and dependency licenses when distributing a build. Do not replace an installed Dolphin app while experimenting.

## Checks

With the patched Dolphin source at the path above:

```sh
python3 Tests/test-pointer-edge.py
python3 Tests/test-camera-pointer.py
python3 Tests/test-hand-calibration.py
python3 Tests/test-profile-migration.py
python3 Tests/test-dolphin-rumble.py
xcrun swiftc Sources/SpatialPose.swift Sources/DSU.swift Tests/main.swift -o /tmp/motionremote-tests
/tmp/motionremote-tests
xcrun swiftc Sources/SpatialPose.swift Sources/DSU.swift Tests/Spatial/main.swift -o /tmp/motionremote-spatial-tests
/tmp/motionremote-spatial-tests
```

The rumble test writes a fixture used by the Swift DSU checks, so run it first. `test-spatial-state.cpp` additionally needs the built ImGui library and the pose-struct fixture generated from the native DSU source. Recording tests are under `Tests/Recording` and `Tests/RecordingStorage`.

Mathematical and protocol checks do not replace hardware testing. Check pointing directions, mixed rotations, tracking loss, held/released Volume Up and game rumble on the target iPhone.
