# Installation

Use the iPhone app and custom Dolphin build from the same release. The current pair is MotionRemote 1.8.

## 1. Install the iPhone app

The distributed IPA is **unsigned**. It cannot be installed by opening it directly on an iPhone.

Import `MotionRemote-1.8.ipa` into your existing signing tool, sign it with a valid certificate and provisioning profile for your device, then install it. If you use eSign, import the IPA, select your signing certificate, sign, then install. You supply the signing credentials; none are included here.

Alternatively, [build the app in Xcode](BUILDING.md), choose your development team and run it on your paired iPhone. Wireless deployment works only after Xcode pairing is configured. Enable Developer Mode if Xcode asks for it.

Launch MotionRemote and allow Camera, Motion and Local Network access. The camera is required for the volume-button interaction and optional spatial tracking. Switching away from the app stops the controller.

## 2. Install Dolphin MotionRemote

Extract `Dolphin-MotionRemote-1.8-macOS-arm64.zip` and move the app to your Applications folder. This build requires Apple Silicon and macOS 27 or later. It is ad-hoc signed, not notarized; use macOS's normal **Privacy & Security → Open Anyway** control if blocked and you trust the download. Do not disable system security globally.

Close other Dolphin copies before opening it. The custom build uses Dolphin's existing user folder, so settings, game paths and controller mappings are shared. Back up that folder before changing a working setup:

```text
~/Library/Application Support/Dolphin
```

## 3. Add the controller profiles

Copy the four `.ini` files from this repository's `Dolphin` directory into:

```text
~/Library/Application Support/Dolphin/Config/Profiles/Wiimote/
```

Create the directory if it does not exist. Keep a backup if profiles with those names are already present.

## 4. Connect over Wi-Fi

1. Connect the Mac and iPhone to the same local network. Guest-network isolation can prevent devices from reaching each other.
2. In MotionRemote settings, choose **Player 1**, then tap **Connect**. Note the phone address displayed at the bottom.
3. In Dolphin, open **Controllers → Alternate Input Sources → DSU Client**. Enable the client and add a server:

   | Field | Player 1 value |
   | --- | --- |
   | Name | `MotionRemote` |
   | Address | The iPhone address shown in the app |
   | Port | `26760` |

4. Set Wii Remote 1 to **Emulated Wii Remote** and open **Configure**.
5. Select the **MotionRemote** profile and click **Load**. The device should be `DSUClient/0/MotionRemote`.
6. Keep the configuration window open or start a game so Dolphin polls controller input. The phone should show **Connected to Dolphin**.

Use the phone's actual address, not `127.0.0.1`. The controller server runs on the phone.

## 5. Calibrate pointing

Tap the gyroscope button in the phone app. This enables camera tracking and opens calibration.

1. Keep the rear camera uncovered. Briefly scan a well-lit part of the room so ARKit can establish tracking.
2. Hold the phone comfortably and reasonably still for the measurement. A table is not required. If you were actively rotating it, tap **Measure again**.
3. Wait until the app reports normal camera tracking. Point the phone toward the centre of the screen in your playing grip, then choose **Set screen centre**.

The crosshair button recentres the pointer without repeating the sensor measurement. Recenter after starting a new camera session. The camera setting is session-based; check it after restarting the app.

The pointer keeps its physical angle beyond the screen edges: if you rotate beyond an edge, you must undo that extra rotation before the pointer comes back. This is the intended **Preserve Angle** behaviour.

## Playing Wii Sports

Select the matching sport in the phone app. These presets select the Volume Up trigger mapping; they do not change the game's physics.

| Preset | Volume Up |
| --- | --- |
| Golf | A |
| Bowling | B |
| Tennis | A |

Hold and release Volume Up as you would the mapped Wii button. In Golf, follow the game's A-button prompts to enter the actual shot rather than a practice swing. All main Wii buttons are also available on screen. Settings allow A/B trigger overrides.

## Game rumble and the overlay

Enable **game haptics** in the phone settings. Load a profile whose **Rumble → Motor** field is `Motor`. Game rumble requires this custom Dolphin build; button feedback also works independently of game rumble.

Use **Options → MotionRemote overlay → Show haptics and 3D path** to show the overlay. Choose the player whose spatial path you want to see. Enable camera tracking on that phone for the path. Rumble bars show the game's output, not just button taps.

## More than one phone

Give each phone a different player number, then add a DSU server for each address:

| Player | Server name | Device | Profile |
| --- | --- | --- | --- |
| 1 | `MotionRemote` | `DSUClient/0/MotionRemote` | MotionRemote |
| 2 | `MotionRemote P2` | `DSUClient/1/MotionRemote P2` | MotionRemote P2 |
| 3 | `MotionRemote P3` | `DSUClient/2/MotionRemote P3` | MotionRemote P3 |
| 4 | `MotionRemote P4` | `DSUClient/3/MotionRemote P4` | MotionRemote P4 |

Configure the corresponding emulated Wii Remote for each player. Each phone has its own identity, button state, camera reference and rumble destination. Live multi-phone play has not been exhaustively tested.

## Troubleshooting

**Waiting for Dolphin:** Open the emulated Wii Remote configuration or start a game. Check the phone address, port, matching server name, local-network permission and that only one Dolphin copy is running.

**Buttons work, but game rumble does not:** Use Dolphin MotionRemote, load the matching profile and check `Rumble/Motor = Motor`. A game only vibrates when it actually sends rumble commands.

**The pointer drifts or jumps:** Check tracking quality, light and camera visibility. Recenter in your normal grip. If the camera session restarted, set the centre again. Turn off camera tracking to compare against gyro-only pointing.

**Volume Up does not register:** Keep MotionRemote in the foreground and allow camera access. Volume-button behaviour with ARKit has not been verified on every iPhone/iOS combination; use the on-screen A/B buttons if needed.

**Signing or installation fails:** The IPA needs your own valid signing setup. Check certificate expiry, device registration, entitlements and bundle identifier requirements in your signing tool. This project does not supply signing services.
