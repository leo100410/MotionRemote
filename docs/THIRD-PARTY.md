# Third-party software

## AimMac

MotionRemote began as a modification of [Coolerwave/AimMac](https://github.com/Coolerwave/AimMac). The original MIT notice is included in `LICENSES/AimMac-MIT.txt`.

## Dolphin

The custom emulator is based on [Dolphin 2609b](https://github.com/dolphin-emu/dolphin/tree/2609b), licensed under GPL-2.0-or-later. `LICENSES/Dolphin-COPYING.txt` contains its license. The complete MotionRemote changes to upstream source are in `DolphinBuild/motionremote-1.13.patch`; the upstream project includes additional dependency notices under `LICENSES` and `Externals`.

When distributing the custom emulator binary, distribute its matching source and build instructions as well. A matching source archive is prepared alongside the local release files. Preserve all applicable dependency notices.

## Qt and other native libraries

The prepared Mac app bundles Qt 6.8.3 libraries and other dependencies selected by the Dolphin build. Qt's open-source modules have their own LGPL/GPL terms and third-party notices. The Dolphin patch does not change Qt source.

Qt 6.8.3 source modules are available from the [official Qt source archive](https://download.qt.io/archive/qt/6.8/6.8.3/submodules/), including qtbase, qttools and qtsvg. Consult the license files shipped with those modules. Shared libraries in the app bundle can be replaced with compatible rebuilt versions; the resulting app must be signed again locally. This is an ad-hoc signed app, not a locked-down or notarized distribution.

`DolphinBuild/submodules.json` records the exact upstream submodule source archives used during development. The corresponding source trees are retained in the prepared Dolphin source archive. External package tooling and binary SDK downloads are not part of this repository.

Apple frameworks are supplied by iOS/macOS and are not redistributed here. No Nintendo game content, system files or trademarks are licensed by this project.

## DolphiniOS and built-in StikJIT

The separate iPad release is based on [DolphiniOS v5.0.0b6](https://github.com/OatmealDome/dolphin-ios/tree/v5.0.0b6), under GPL-2.0-or-later. Its corresponding source archive includes the patched emulator, dependency source trees, project files and build instructions. `DolphiniOS/motionremote-ipados-1.7.patch` makes the changes reviewable in this repository. Original notices and dependency licenses remain in the source archive.

[StikJIT 2.0.1](https://github.com/StikDebug/StikJIT/releases/tag/2.0.1) is MPL-2.0 licensed. The unmodified iOS framework is embedded for the helper process only. Its license is included in the IPA, under `DolphiniOS/BuildSupport/JITHelper/StikJIT-LICENSE`, and in the full source archive. The exact upstream StikJIT source release is retained as `BuildSupport/StikJIT-2.0.1-source.tar.gz` within the corresponding source archive.

LocalDevVPN is a separate user-installed app, not bundled here. Apple platform SDKs are required to build but are not redistributed. No pairing files, private signing certificates, provisioning profiles, games or system firmware are included.
