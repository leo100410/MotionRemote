# DolphiniOS MotionRemote

Use an iPad as the Wii console and an iPhone running MotionRemote as its controller.

[Download iPad release 1.7](https://github.com/leo100410/MotionRemote/releases/tag/v1.15) · [Installation and JIT setup](../docs/IPADOS.md)

The emulator is based on [DolphiniOS v5.0.0b6](https://github.com/OatmealDome/dolphin-ios/tree/v5.0.0b6). It adds MotionRemote's DSU buttons and motion, a connections menu for Wi-Fi and Bluetooth, game rumble, screen-calibrated and camera-assisted pointing, diagnostics logging and the optional three-second spatial overlay. A built-in StikJIT helper enables JIT through LocalDevVPN without a separate StikDebug installation.

## Release files

- `DolphiniOS-MotionRemote-1.7.ipa`: sign and install on the iPad. Keep its JIT helper extension.
- `DolphiniOS-MotionRemote-1.7-source.tar.gz`: matching emulator source, vendored dependencies, build additions, licenses and the StikJIT release source.
- `SHA256SUMS-1.15.txt`: checksums for all release files.

The IPA contains an ad-hoc signature for packaging checks. It needs development signing for your device with `get-task-allow`. No certificates, provisioning profiles, pairing records or games are provided. A free signing account's normal refresh and App ID limits still apply.

The base app targets iOS/iPadOS 15 or later. Built-in JIT needs 17.4 or later, LocalDevVPN and a current pairing file. It does not support LiveContainer. JIT activation has been confirmed by the owner on an iPad 10 running iPadOS 27.0.1. Release 1.7 has passed the regression tests but has not yet been tested on the device.

## Build from source

The repository patch is provided for review. Use the full source archive to build: it includes the local Swift packages and vendored dependencies expected by the project.

Requirements: an Apple Silicon Mac, Xcode 27.2, CMake 4.1.2 and XcodeGen if regenerating the helper project. XcodeGen is not needed when using the included generated helper project. StikJIT 2.0.1 is supplied for physical iOS ARM64 devices; a simulator build is not part of this release.

From the extracted archive:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export MOTIONREMOTE_CMAKE="$(command -v cmake)"

xcodebuild \
  -project Source/iOS/App/DolphiniOS.xcodeproj \
  -scheme 'DiOS (NJB)' \
  -configuration 'Release (Non-Jailbroken)' \
  -sdk iphoneos \
  -derivedDataPath BuildSupport/DerivedData \
  -IDEPackageSupportDisableManifestSandbox=YES \
  CODE_SIGNING_ALLOWED=NO ENABLE_USER_SCRIPT_SANDBOXING=NO \
  'OTHER_SWIFT_FLAGS=$(inherited) -Xfrontend -disable-sandbox' \
  build

python3 BuildSupport/package-1.7.py
python3 BuildSupport/Tests/test-ios-motionremote-profile.py
```

Set `MOTIONREMOTE_CMAKE` to the CMake executable if it is not on PATH. The app's build phase builds and embeds the helper automatically. Packaging refuses to overwrite an existing `BuildSupport/package-1.7` staging directory. The resulting IPA still needs signing for the target iPad.

`motionremote-ipados-1.7.patch` contains changes to the upstream source. Apply it with `patch -p1 -E` so files removed by the patch (the Firebase package pins) are deleted. Copy this directory's `BuildSupport` additions into the emulator's `BuildSupport` directory when applying the patch manually; obtain the exact packages and framework recorded in the matching full source archive.

DolphiniOS and Dolphin changes are GPL-2.0-or-later. StikJIT is MPL-2.0. Dependency licenses are preserved in the source archive. See [third-party notices](../docs/THIRD-PARTY.md).
