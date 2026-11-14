# DolphiniOS MotionRemote 1.7

Custom iPad/iPhone build based on DolphiniOS v5.0.0b6. The app is named **DolphiniOS MotionRemote** and uses bundle identifier `com.leolange.motionremote.DolphiniOS-njb`.

## Install and connect

1. Sign `DolphiniOS-MotionRemote-1.7.ipa` for your iPad using your existing signing method and install it. The included ad-hoc signature carries the upstream public JIT entitlements for inspection by your signer. The app still needs a valid device signature. Use development signing with `get-task-allow` enabled. Keep the bundled **MotionRemoteJITHelper** extension when the signer asks. It belongs to the same application and does not require a separate active-app slot, but its signing can require an additional App ID from the weekly quota. Install over the existing custom app using the same signing account to retain its data; do not uninstall it first.
2. Connect **LocalDevVPN**, then open **DolphiniOS MotionRemote → Settings → JIT**. Choose **Import Pairing File**, select a valid pairing plist for this iPad, and tap **Enable JIT**. Allow Local Network access. Leave the app open while the first Developer Disk Image downloads and mounts. Wait for **JIT enabled. You can start a game.** The existing StikDebug app is not required for this built-in method.
3. On the iPhone, open **MotionRemote** and tap **Connect**. Turn off AirDrop and Handoff on the iPhone and the iPad while playing (Settings → General → AirDrop → Receiving Off; Settings → General → AirPlay & Continuity → Handoff off); they cause a regular Wi-Fi stutter.
4. Keep both devices on the same Wi-Fi network. On the iPad open **Settings → Controllers → Connections**, or **MotionRemote Connections** in the in-game controller menu.
5. Tap the phone's Wi-Fi entry (or Bluetooth entry) and choose **Connect**. Dolphin gives every connected phone its own Wii Remote, even if all phones are left on player 1. **Connect by IP address…** is available when discovery is blocked.
6. Open a Wii game. The iPhone should report **Connected to Dolphin**. With the screen calibrated on the phone (calibrate against the iPad's screen edges), the pointer needs no recentering; otherwise use the iPhone's crosshair.

The selected Wii Remote is set to emulated mode and receives the MotionRemote profile automatically. Other configured DSU server entries are preserved. The first previous controller configuration is saved under the app's Config directory as `MotionRemote-WiimoteN-backup.ini`.

Use MotionRemote iPhone 1.20. Enable game rumble in the phone settings for Wii rumble. Camera stabilization, screen calibration and the spatial overlay require the iPhone's camera-tracking option. The phone stores one calibrated screen; calibrating the iPad replaces a Mac calibration. Dolphin writes `MotionRemote.log` to its Logs folder with connection and tracking diagnostics.

## Build and checks

The device build completed with Xcode 27.2 and the iOS 27.2 SDK, targeting iOS/iPadOS 15 or later. Both iPhone and iPad device families are included. Device binaries and embedded libraries are ARM64 iOS builds.

The native cursor, camera-axis, angle-overflow, rumble packet and profile checks passed against this port's source. The owner confirmed built-in JIT activation, the iPhone network connection and reaching the Wii Sports title screen on an iPad 10 with iPadOS 27.0.1 with earlier builds. Release 1.7 has not yet been tested on the device. This package contains no game files.

Source, downloaded pinned dependency archives and build logs are kept in this directory. The official project's notices and licenses remain in the source. This unofficial build uses the existing raster app icon. Upstream Firebase analytics were inactive for unofficial builds and its unused SDK linking was removed. The bundled localization files were used without regenerating translations.

## Built-in JIT details and troubleshooting

The helper uses the official **StikJIT 2.0.1** iOS ARM64 framework and its fixed legacy script, matching DolphiniOS's existing `BRK #0x69` executable-memory allocator. JIT is marked ready only after the host has observed the debugger, prepared its executable memory and received a successful helper result. A debugger-status buffer-size bug in the upstream app was also corrected and regression-tested.

The helper's identifier is read from its installed bundle, so a sideloader may rename the host and extension together. Only the helper links StikJIT; its framework is embedded in the host's Frameworks directory for the signing tool. Pairing data is passed directly to the helper, written to a protected temporary file and deleted after the operation. The host keeps its imported file at `Documents/StikJIT/pairingFile.plist`, excluded from backups. Pairing data is never logged. A malformed replacement does not overwrite the existing imported file.

- **Helper missing / could not start:** reinstall while keeping the app extension. An IPA stripped of its helper cannot enable JIT internally.
- **Missing get-task-allow:** use development signing; the final signature must allow debugging.
- **Pairing or connection error:** keep LocalDevVPN connected, allow Local Network access and use this iPad's current pairing file. The actual StikJIT error appears in JIT Setup; importing a file does not guarantee that iPadOS still accepts it.
- **DDI preparation error after an OS update:** use **Reset Developer Disk Image**, then enable JIT again. This preserves games, saves and the pairing file.
- **External debugger:** choose **Use External Debugger** to keep the previous StikDebug/AltServer/JitStreamer flow. Restart the app before switching away from a built-in session. Importing a pairing file or pressing Enable JIT selects the built-in method again. The built-in path does not also launch AltServer/JitStreamer.
- JIT activation is required again after the app process ends. Built-in JIT requires iOS/iPadOS 17.4 or later, a physical device, and no LiveContainer.

Tests cover pairing-file validation/replacement, helper message encoding and the real debugger-status method. The IPA's signatures, extension identifier/version, framework dependency paths, ARM64 iOS platform metadata and archive integrity were checked. The owner confirmed JIT activation and reaching the Wii Sports title screen on the iPad with earlier builds.

StikJIT is licensed under MPL-2.0. Its license is included in the IPA as `StikJIT-LICENSE.txt`; the unmodified release source is retained as `BuildSupport/StikJIT-2.0.1-source.tar.gz`. Official source and releases: https://github.com/StikDebug/StikJIT/releases/tag/2.0.1 . The extension-launch mechanism uses the classic NSExtension process model also documented by Madeira: https://github.com/willfaust/Madeira/blob/main/docs/JIT.md . No additional SDK installation was needed on this Mac.

## Updating from 1.0 or 1.1: reapply the controller mapping

Release 1.2 fixes an INI overload error in the iPad setup: C++ string literals used for buttons, motion axes, extension and rumble were being converted to boolean `True` values instead of the intended control names. The device qualifier and network connection were valid, so the iPhone could show Connected while Dolphin received no mapped buttons or motion.

After installing 1.2 over the existing app, **stop the running game**, open **Settings → Controllers → MotionRemote**, confirm the iPhone IPv4 address and matching player, and press **Apply** (or **Apply with 3D overlay**) once. This replaces the previously broken mappings. Start the game again and press A+B on the phone at the Wii Sports title screen.

The in-game **Touch Controller** menu only selects the iPad's on-screen controls; a MotionRemote DSU device is not expected in that menu. Its assignment is under **Settings → Controllers → Wii Remote N → Configure**, with default device `DSUClient/N/MotionRemote` (or `MotionRemote P2` etc., using zero-based N).

The regression check compiles the actual iOS profile setup statements against Dolphin's real INI header. It reproduced the broken values before the correction, and verifies every mapping against the working desktop profile plus distinct identifiers for all four players after the correction.
