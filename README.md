<p align="center">
  <img src="Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="100" alt="MotionRemote icon">
</p>

# MotionRemote

Use an iPhone as a motion controller for Dolphin on Mac or iPad. An experimental game, MotionSaber, uses the phone as a sword.

> [!WARNING]
> **Turn off AirDrop and Handoff on the Mac and on the iPhone while playing.**
>
> Both features use AWDL, an extra Wi-Fi link that makes the Wi-Fi radio briefly leave your network about once per second. Controller packets are then held back and arrive in a burst, which shows up as a regular stutter in the game. Measured on the development setup: with AirDrop and Handoff on, 9–20 pauses longer than 80 ms per 10 seconds (up to 400 ms) and up to 10% lost packets; with both off, no lost packets and no pause longer than 60 ms.
>
> - **Mac:** Control Centre → AirDrop → **No One** (or Off), and System Settings → General → AirDrop & Handoff → turn off **Allow Handoff between this Mac and your iCloud devices**.
> - **iPhone:** Settings → General → AirDrop → **Receiving Off**, and Settings → General → AirPlay & Continuity → turn off **Handoff**.
>
> Switch them back on after playing if you need them.

[Download v1.15](https://github.com/leo100410/MotionRemote/releases/tag/v1.15) · [Installation](docs/INSTALLATION.md) · [iPad](docs/IPADOS.md) · [MotionSaber](docs/MOTIONSABER.md) · [Build from source](docs/BUILDING.md) · [How it works](docs/ARCHITECTURE.md)

## What is included

| Download | What it is |
| --- | --- |
| **MotionRemote 1.15** (iPhone) | The controller app: Wii Remote buttons, volume-button trigger, motion, camera tracking and screen calibration |
| **Dolphin MotionRemote 1.13** (Mac) | Dolphin 2609b with a connection window, game rumble, screen-calibrated pointing and diagnostics |
| **DolphiniOS MotionRemote 1.7** (iPad) | The same controller support for DolphiniOS, with built-in JIT activation |
| **MotionSaber 1.3** (Mac) | **Highly experimental.** A small rhythm game where the iPhone is the sword |
| **MotionRemote Monitor 1.0** (Mac) | Live 3D view and graphs of the phone's motion and packet timing |

> [!CAUTION]
> **MotionSaber is highly experimental.** Hit detection and tracking in the game do not work well yet. Do not use MotionSaber as a reference for how well MotionRemote, the phone's tracking or the connection work; judge those in Dolphin and with the diagnostics logs.

## What works

- On-screen D-pad, A, B, Home, +, −, 1 and 2, with simultaneous presses. Volume Up is a sport-specific A/B trigger; Volume Down always holds B.
- **Connections window in Dolphin** (Options → MotionRemote Connections…): finds phones over Wi-Fi and Bluetooth, one row per player, applies the controller profile automatically.
- **Several phones at once.** Each connected phone gets its own Wii Remote, even if all phones are left on player 1.
- **Screen calibration ("virtual sensor bar").** Touch the left and right edge of the screen with the phone once; the phone remembers where the screen is in the room. Pointing at the screen centre is then always straight ahead, with no recentering.
- **With or without LiDAR.** Camera tracking uses ARKit. On phones with LiDAR (such as the iPhone 15 Pro) it starts faster; devices without LiDAR track the same way after a few seconds of slow movement. If the camera cannot track (dark room, blank ceiling), the controller falls back to the motion sensors automatically.
- Game rumble, button haptics, a live overlay with rumble levels and the phone's spatial path.
- Diagnostics logs on the phone, in Dolphin and in MotionSaber that explain tracking and connection problems (for example Wi-Fi pauses caused by AirDrop/Handoff).
- Local motion recordings with 3D orientation playback.

Wii Sports Golf, Bowling and Tennis have been played on the development setup. Tennis swing timing can still feel off; this is being investigated. Other games may need different mappings.

## Get started on Mac

1. Turn off AirDrop and Handoff (see above).
2. Sign and install the iPhone IPA with your own signing method, open MotionRemote and tap **Connect**.
3. Open **Dolphin MotionRemote 1.13**. Close other Dolphin copies first.
4. Choose **Options → MotionRemote Connections…**, pick your phone in the row for player 1 and press **Connect**. The Wii Remote profile is applied automatically.
5. Optional: on the phone, tap the gyroscope button and calibrate the screen (see [Installation](docs/INSTALLATION.md#4-calibrate-the-screen)).

The [installation guide](docs/INSTALLATION.md) covers signing, Bluetooth, several phones, calibration and troubleshooting. Download release files together with the matching source packages and checksums.

## Requirements

| Component | Requirement |
| --- | --- |
| iPhone app | iOS 17.2 or later; camera, motion and local network permission |
| Camera tracking and screen calibration | ARKit world tracking, an uncovered rear camera and a well-lit room. LiDAR helps tracking start faster but is not required |
| Mac apps | Apple Silicon, macOS 27 or later for Dolphin; macOS 14 or later for MotionSaber and Monitor |
| iPad emulator | iPadOS 15 or later; built-in JIT needs 17.4 or later |
| Network | Both devices on the same local network (UDP 26760), or Bluetooth for Dolphin |

The tested setup is an iPhone 15 Pro, an M5 MacBook Air and an iPad 10. Two phones were used together during development; four phones have not been tested. Other devices have not been verified.

## Things to know

- **Wi-Fi is recommended.** Bluetooth works for Dolphin but typically has more latency. Turn off AirDrop and Handoff for a smooth Wi-Fi link.
- Camera tracking needs light and visible detail. Holding the phone like a sword or a Wii Remote often points the camera at the ceiling or floor; a blank ceiling can make tracking drop. The controller then falls back to the motion sensors and the log says why.
- The phone stores one calibrated screen. Calibrating another screen (for example the iPad) replaces it. Recalibrate after moving the Mac.
- Keep a secure grip when swinging the phone, especially close to a screen.
- The DSU connection is meant for a trusted local network. It validates packets but has no encryption or authentication. Do not expose port 26760 to the internet.
- No camera images or audio are sent to the Mac or iPad. Recordings and logs stay on the device.

## Credits and licenses

The project began as a modification of [AimMac](https://github.com/Coolerwave/AimMac). The Mac emulator is based on [Dolphin 2609b](https://github.com/dolphin-emu/dolphin/tree/2609b) and the iPad emulator on [DolphiniOS v5.0.0b6](https://github.com/OatmealDome/dolphin-ios/tree/v5.0.0b6).

The iPhone app, MotionSaber and MotionRemote Monitor are MIT-licensed with upstream notices retained. Dolphin and DolphiniOS changes are GPL-2.0-or-later; the built-in StikJIT framework is MPL-2.0. See [LICENSE](LICENSE) and [third-party notices](docs/THIRD-PARTY.md). This project is not affiliated with Nintendo, Apple or the Dolphin Emulator Project. No games, firmware, signing certificates or provisioning profiles are included.
