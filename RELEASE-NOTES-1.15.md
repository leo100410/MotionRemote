> [!WARNING]
> **Turn off AirDrop and Handoff on the Mac and the iPhone (and the iPad) while playing.**
>
> AirDrop and Handoff use AWDL, an extra Wi-Fi link that makes the Wi-Fi radio briefly leave your network about once per second. Controller packets are held back and then arrive in a burst, which you see as a regular stutter. Measured on the development setup: with AirDrop and Handoff on, 9–20 pauses longer than 80 ms per 10 seconds (up to 400 ms) and up to 10% lost packets; with both off, no lost packets and no pause longer than 60 ms.
>
> - **Mac:** Control Centre → AirDrop → **No One** (or Off), and System Settings → General → AirDrop & Handoff → turn off **Allow Handoff between this Mac and your iCloud devices**.
> - **iPhone / iPad:** Settings → General → AirDrop → **Receiving Off**, and Settings → General → AirPlay & Continuity → turn off **Handoff**.

## What's new

- **Screen calibration ("virtual sensor bar").** Touch the left and right screen edge with the phone's camera corner once. The phone remembers where the screen is in the room; pointing at the screen centre is then always straight ahead in Dolphin, without recentering.
- **Connections window in Dolphin** (Options → MotionRemote Connections…): one row per player, Wi-Fi and Bluetooth discovery, automatic Wii Remote profile, link test.
- **Several phones at once.** Each connected phone gets its own Wii Remote, even if all phones are left on player 1. Phones no longer replace each other, and one phone's hiccup no longer stalls every player.
- **Bluetooth** as an alternative link. Wi-Fi is recommended: in practice it has lower latency.
- **Smoother pointer:** late or bursty packets no longer shift it.
- **Diagnostics logs** on the phone (Settings → Diagnostics), in Dolphin (`MotionRemote.log` in Dolphin's Logs folder) and in MotionSaber. They show, for example, whether a pause came from Wi-Fi holding packets back, packets lost on the way or the phone itself.
- **MotionSaber 1.3 (experimental):** a rhythm game for the Mac with the iPhone as a sword, haptic feedback on every cut, and an automatic motion-only mode for devices or rooms where camera tracking is not available.
- **MotionRemote Monitor 1.0:** live 3D view of the phone and graphs of acceleration, rotation, orientation and packet timing.

## Files

| File | For |
| --- | --- |
| `MotionRemote-1.15.ipa` | iPhone app (unsigned; sign it with your own tool) |
| `Dolphin-MotionRemote-1.13-macOS-arm64.zip` | Dolphin for Mac (Apple Silicon, macOS 27+) |
| `DolphiniOS-MotionRemote-1.7.ipa` | Dolphin for iPad (sign with development signing; keep the JIT helper extension) |
| `MotionSaber-1.3-macOS-arm64.zip` | The rhythm game, experimental (macOS 14+) |
| `MotionRemote-Monitor-1.0-macOS-arm64.zip` | Motion monitor (macOS 14+) |
| `Dolphin-MotionRemote-1.13-source.tar.gz` | Complete source of the Mac Dolphin build (GPL-2.0-or-later) |
| `DolphiniOS-MotionRemote-1.7-source.tar.gz` | Complete source of the iPad build, including the StikJIT 2.0.1 source (GPL / MPL-2.0) |
| `MotionRemote-1.15-project.tar.gz` | This repository at the release, including the iPhone app, MotionSaber and Monitor sources |
| `SHA256SUMS-1.15.txt` | Checksums |

The Mac apps are ad-hoc signed and not notarized. Use System Settings → Privacy & Security → Open Anyway if you trust the download. See [Installation](https://github.com/leo100410/MotionRemote/blob/main/docs/INSTALLATION.md) for setup and screen calibration.

## Known limits

- Wii Sports Tennis swing timing can still feel off (early or late swings, a backhand wind-up counted as a swing). This is being investigated.
- The iPad build 1.7 and use with four phones have not been tested on devices yet. The tested setup is an iPhone 15 Pro, an M5 MacBook Air and an iPad 10.
- The phone stores one calibrated screen; calibrating another screen replaces it.
