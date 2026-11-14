> [!WARNING]
> **Turn off AirDrop and Handoff on the Mac and the iPhone while playing.**
>
> Both use AWDL, an extra Wi-Fi link that makes the Wi-Fi radio briefly leave your network about once per second. Controller packets are held back and arrive in a burst, which shows up as a regular stutter. Measured on the development setup: with AirDrop and Handoff on, 9–20 pauses longer than 80 ms per 10 seconds (up to 400 ms) and up to 10% lost packets; with both off, no lost packets and no pause longer than 60 ms.
>
> - **Mac:** Control Centre → AirDrop → **No One** (or Off), and System Settings → General → AirDrop & Handoff → turn off **Allow Handoff between this Mac and your iCloud devices**.
> - **iPhone:** Settings → General → AirDrop → **Receiving Off**, and Settings → General → AirPlay & Continuity → turn off **Handoff**.

## What's new

- **Full-size buttons again.** The D-pad and A button have their size from before the redesign; 1.17 wrongly used the compact sizes meant for small phones.
- **Redesigned controller screen** (from 1.17): light and dark mode, instant spring feedback on every button, translucent status and action bars, labelled Center and Calibrate buttons.
- **Forget Saved Room** (from 1.17) works while the phone is still looking for a room it does not recognise, and restarts tracking so you can calibrate again.
- Everything from 1.15: screen calibration, the Connections window, several phones at once, Bluetooth, diagnostics logs, MotionSaber and MotionRemote Monitor.

## Files

| File | For | Version |
| --- | --- | --- |
| `MotionRemote-1.20.ipa` | iPhone app (unsigned; sign it with your own tool) | 1.20 |
| `Dolphin-MotionRemote-1.13-macOS-arm64.zip` | Dolphin for Mac (Apple Silicon, macOS 27+) | 1.13, unchanged |
| `MotionSaber-1.3-macOS-arm64.zip` | Experimental rhythm game (macOS 14+) | 1.3, unchanged |
| `MotionRemote-Monitor-1.0-macOS-arm64.zip` | Motion monitor (macOS 14+) | 1.0, unchanged |
| `Dolphin-MotionRemote-1.13-source.tar.gz` | Complete source of the Mac Dolphin build (GPL-2.0-or-later) | 1.13 |
| `MotionRemote-1.20-project.tar.gz` | This repository at the release | 1.20 |
| `SHA256SUMS-1.20.txt` | Checksums | |

The iPad emulator (DolphiniOS MotionRemote 1.7) is unchanged and available in [release v1.15](https://github.com/leo100410/MotionRemote/releases/tag/v1.15). The Mac apps are ad-hoc signed and not notarized; use System Settings → Privacy & Security → Open Anyway if you trust the download.
