> [!WARNING]
> **Turn off AirDrop and Handoff on the Mac and the iPhone while playing.** They make Wi-Fi pause about once per second, which causes a regular stutter. See the [README](https://github.com/leo100410/MotionRemote#readme) for where to switch them off.

## What's new

- **Tennis forehand and backhand fixed.** Earlier versions sent the sideways motion mirrored, so Wii Sports Tennis swapped forehand and backhand and a ball on the left needed a right-to-left swing. The axes now match Dolphin's own Wii Remote swing model.
- **Grip setting with automatic detection.** Hold the phone like a Wii Remote (display up) or like a racket handle (display facing left or right). With **Settings → Grip → Detect automatically** (on by default) the app picks the grip while you hold the phone still and level for a moment, never during a swing. You can also choose the grip yourself; no recalibration is needed.
- **Dolphin 1.18:** smoother rotation when the phone and Dolphin run at different rates, and a motion trace of the last ten sessions in Dolphin's Logs folder (press the phone's Center button to mark a moment).
- **MotionSaber 1.4 and Monitor 1.1** read the corrected axis. Update them together with the iPhone app.

## Files

| File | For | Version |
| --- | --- | --- |
| `MotionRemote-1.27.ipa` | iPhone app (unsigned; sign it with your own tool) | 1.27 |
| `Dolphin-MotionRemote-1.18-macOS-arm64.zip` | Dolphin for Mac (Apple Silicon, macOS 27+) | 1.18 |
| `MotionSaber-1.4-macOS-arm64.zip` | Experimental rhythm game (macOS 14+) | 1.4 |
| `MotionRemote-Monitor-1.1-macOS-arm64.zip` | Motion monitor (macOS 14+) | 1.1 |
| `Dolphin-MotionRemote-1.18-source.tar.gz` | Complete source of the Mac Dolphin build (GPL-2.0-or-later) | 1.18 |
| `MotionRemote-1.27-project.tar.gz` | This repository at the release | 1.27 |
| `SHA256SUMS-1.27.txt` | Checksums | |

The iPad emulator (DolphiniOS MotionRemote 1.7) is unchanged and available in [release v1.15](https://github.com/leo100410/MotionRemote/releases/tag/v1.15). The Mac apps are ad-hoc signed and not notarized; use System Settings → Privacy & Security → Open Anyway if you trust the download.
