# Installation

MotionRemote 1.17 for iPhone ([release v1.17](https://github.com/leo100410/MotionRemote/releases/tag/v1.17)); Dolphin MotionRemote 1.13 for Mac, DolphiniOS MotionRemote 1.7 for iPad, MotionSaber 1.3 and MotionRemote Monitor 1.0 ([release v1.15](https://github.com/leo100410/MotionRemote/releases/tag/v1.15)).

> [!WARNING]
> **Turn off AirDrop and Handoff on the Mac and the iPhone while playing.** They make Wi-Fi pause about once per second, which causes a regular stutter. See the [README](../README.md) for the measurements and where to switch them off.

## 1. Install the iPhone app

The distributed IPA is **unsigned**. It cannot be installed by opening it directly on an iPhone.

Import `MotionRemote-1.17.ipa` into your signing tool, sign it with a valid certificate and provisioning profile for your device, then install it. You supply the signing credentials; none are included here. Alternatively, [build the app in Xcode](BUILDING.md) and run it with your own development team.

Launch MotionRemote and allow Camera, Motion, Local Network and (for Bluetooth) Bluetooth access. Switching away from the app stops the controller.

## 2. Install the Mac apps

Extract `Dolphin-MotionRemote-1.13-macOS-arm64.zip` and move the app to your Applications folder. It needs Apple Silicon and macOS 27 or later. The apps are ad-hoc signed, not notarized; if macOS blocks one and you trust the download, use **System Settings → Privacy & Security → Open Anyway**. Do not disable system security globally.

The custom Dolphin uses Dolphin's normal user folder, so settings, game paths and mappings are shared with other Dolphin copies. Back it up before changing a working setup:

```text
~/Library/Application Support/Dolphin
```

`MotionSaber-1.3-macOS-arm64.zip` and `MotionRemote-Monitor-1.0-macOS-arm64.zip` contain the game and the motion monitor (macOS 14 or later).

## 3. Connect the phone to Dolphin

1. Put the Mac and the iPhone on the same network. Guest networks with client isolation do not work.
2. On the phone, tap **Connect**.
3. In Dolphin, choose **Options → MotionRemote Connections…**. The window has one row per player. Pick your phone in the row for player 1 and press **Connect**.
4. Start a game. The phone shows **Connected to Dolphin**.

Each phone appears as a Wi-Fi entry and, if Bluetooth is allowed, as a Bluetooth entry. **Use Wi-Fi**: in practice it has lower latency than Bluetooth. Bluetooth may show a pairing prompt on both devices.

Connecting applies the matching Wii Remote profile and sets the Wii Remote to emulated mode. Your previous controller setup is saved once as `MotionRemote-WiimoteN-backup.ini` in Dolphin's Config folder. **Test** measures round-trip time, jitter and packet loss of a connection; **Disconnect** releases the player.

The profiles in this repository's `Dolphin` folder are only needed for a manual DSU setup (Controllers → Alternate Input Sources → DSU Client, the phone's address and port 26760).

### Several phones

Start MotionRemote on every phone and connect each one in its own row. The phones do not need different player settings: Dolphin gives every connected phone its own Wii Remote. Choosing a player that another phone holds moves that player to the new phone.

## 4. Calibrate the screen

Screen calibration tells the phone where your screen is in the room. Pointing at the screen centre is then always straight ahead, in Dolphin and in MotionSaber, without recentering. The phone remembers the room and restores the calibration on the next start.

1. On the phone, tap the gyroscope button. This turns on camera tracking and opens the calibration sheet.
2. Move the phone slowly for a moment until tracking is normal (the buttons become active). Without LiDAR this can take a few seconds longer.
3. Hold the **top corner of the phone where the camera is** against the **left edge of the Mac screen**, at about half height. The rear camera must stay uncovered and see the room (pointing down at the desk or to the side is fine). Tap **Mark left edge**. The phone vibrates briefly.
4. Do the same on the **right edge** and tap **Mark right edge**.

If the phone keeps looking for a saved room that it does not recognise (for example after moving the Mac), tap **Forget Saved Room** and calibrate again.

How you turn the phone does not matter, as long as the same corner touches the edge both times. Do not hold the camera against the screen like taking a photo: the phone measures the corner, and a covered camera loses tracking. If you mark the edges in the wrong order, the phone corrects it automatically.

To check: hold the phone flat and point its top edge at the screen centre. In MotionSaber the sword should point straight down the track. Recalibrate after moving the Mac or when the logs report that the measured width does not match the display.

Without calibration, Dolphin uses the previous method: point at the screen centre and press the crosshair to recenter.

## Playing Wii Sports

Select the matching sport in the phone app. The presets only choose what Volume Up does:

| Preset | Volume Up |
| --- | --- |
| Golf | A |
| Bowling | B |
| Tennis | A |

Volume Down always holds B. Short volume taps are held for at least 50 ms so Dolphin sees them. Both volume buttons and the on-screen buttons can be held independently.

Swings in Wii Sports use the acceleration sent by the phone, not the pointer. Tennis swing timing can still feel off; this is being investigated.

## Game rumble and the overlay

Game rumble needs **Game rumble** enabled in the phone settings and works only with the custom Dolphin build. **Show haptics and 3D path overlay** in the Connections window shows rumble levels, the phone's spatial path and whether the pointer currently uses the screen calibration.

## Logs

- **Dolphin:** `MotionRemote.log` in Dolphin's Logs folder (`~/Library/Application Support/Dolphin/Logs`). It records packet gaps and whether Wi-Fi held packets back, dropped them or the phone paused, a 10-second summary per player with a hint when gaps follow the AirDrop/Handoff rhythm, tracking problems reported by the phone and pointer source changes. The previous session is kept as `MotionRemote-previous.log`.
- **iPhone:** Settings → Diagnostics → **Share current log**, or the Files app under On My iPhone → MotionRemote → Logs.
- **MotionSaber:** `~/Library/Logs/MotionSaber`. The path is shown at the bottom of the game window.

## Troubleshooting

**Regular stutter every second:** turn off AirDrop and Handoff on both devices. The Dolphin and MotionSaber logs report "held by Wi-Fi" gaps and a regular rhythm when this is the cause.

**No phone in the Connections window:** keep MotionRemote open with **Connect** pressed, allow Local Network access on both devices and press **Scan again**. Enter the phone's IPv4 address under Connect IP if discovery is blocked.

**Buttons work, but no rumble:** use Dolphin MotionRemote, enable game rumble on the phone and check that the Wii Remote profile's `Rumble/Motor` is `Motor`. A game vibrates only when it sends rumble.

**Pointer or sword direction is off:** recalibrate the screen. Check light and that the camera is uncovered; the phone log names the tracking problem (for example too little detail or too fast movement).

**Signing or installation fails:** the IPA needs your own valid signing setup. Check certificate expiry, device registration, entitlements and bundle identifier requirements in your signing tool.
