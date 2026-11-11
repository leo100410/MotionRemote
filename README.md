<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="100" alt="MotionRemote icon">
</p>

# MotionRemote

Use an iPhone as a motion controller for Dolphin on Mac or iPad.

MotionRemote sends buttons, acceleration and rotation over your local network. It includes a Wii Remote-style layout, a volume-button trigger, camera-assisted pointing and a custom Dolphin build with game rumble and a live motion overlay.

[Download v1.10](https://github.com/leo100410/MotionRemote/releases/tag/v1.10) · [Installation](docs/INSTALLATION.md) · [Build from source](docs/BUILDING.md) · [How it works](docs/ARCHITECTURE.md)

## What works

- On-screen D-pad, A, B, Home, +, −, 1 and 2, with simultaneous button presses.
- Volume Up as a hold-and-release trigger: A for Golf and Tennis, B for Bowling, or a manual override. Volume Down always holds B.
- Four player slots, with a separate phone and Dolphin profile for each player.
- Button haptics and game-triggered rumble through the custom Dolphin build.
- Camera-assisted pointing, guided calibration and quick recentering.
- An optional overlay with player rumble levels and the last three seconds of the phone's spatial path.
- Local motion recordings with a timeline and 3D orientation playback.

Wii Sports Golf, Bowling and Tennis have been tried on the development setup. Other games may need different mappings; this is not a drop-in replacement for every Wii accessory.

## Play on iPad

[DolphiniOS MotionRemote 1.2](https://github.com/leo100410/MotionRemote/releases/tag/ipados-v1.2) runs the emulator on the iPad and uses the same iPhone controller app. It includes built-in JIT activation through LocalDevVPN, game rumble and the motion overlay. Keep its helper extension when signing.

See the [iPad installation guide](docs/IPADOS.md) for pairing-file import, JIT setup and controller assignment, or [DolphiniOS build notes](DolphiniOS/README.md) for the matching source. Existing Mac downloads remain available.

## Get started on Mac

1. Install and sign the iPhone IPA using your own signing method.
2. Open **Dolphin MotionRemote 1.8** on the Mac. Close other Dolphin copies first.
3. Connect both devices to the same network and tap **Connect** on the phone.
4. Add the phone's address and port **26760** in Dolphin's **Alternate Input Sources → DSU Client**.
5. Set Wii Remote 1 to **Emulated Wii Remote**, then load the **MotionRemote** profile.

The [installation guide](docs/INSTALLATION.md) covers signing, profiles, calibration and multiplayer. Release files should be downloaded together with the matching source package and checksums.

## Requirements

| Component | Requirement |
| --- | --- |
| iPhone app | iOS 17.2 or later; motion sensors and camera permission |
| Camera-assisted pointing | ARKit world tracking support, an uncovered rear camera and a well-lit room |
| Packaged Mac build | Apple Silicon, macOS 27 or later |
| Network | Both devices can reach each other over the local network; UDP 26760 |

The tested setup is an iPhone 15 Pro and an M5 MacBook Air. Support on other devices has not been verified. A stock Dolphin build can receive the standard DSU controls; game rumble, the overlay and camera correction need the MotionRemote build.

## Things to know

Camera tracking can lose accuracy during fast swings, in poor light or when the camera is covered. The controller falls back to gyro input during tracking loss. A new camera session needs recentering. Keep a secure grip when swinging the phone.

The camera runs locally for the volume trigger and optional spatial tracking. No camera images or audio are sent to Dolphin. Recordings stay on the phone. Recorded playback shows orientation and acceleration; the live overlay shows the camera-tracked spatial path.

The DSU connection is intended for a trusted local network. It has packet validation, but no encryption or authentication. Do not expose the port to the internet.

## Credits and licenses

The project began as a modification of [AimMac](https://github.com/Coolerwave/AimMac). Its Mac integration is based on [Dolphin 2609b](https://github.com/dolphin-emu/dolphin/tree/2609b).

The iPhone app is MIT-licensed with upstream notices retained. Dolphin changes are GPL-2.0-or-later. See [LICENSE](LICENSE) and [third-party notices](docs/THIRD-PARTY.md). This project is not affiliated with Nintendo, Apple or the Dolphin Emulator Project. No games, firmware, signing certificates or provisioning profiles are included.
