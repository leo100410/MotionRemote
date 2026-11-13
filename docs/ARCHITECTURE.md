# Architecture

The iPhone is the controller server; Dolphin is the client. There is no separate Mac bridge and no cloud relay.

```text
Touch buttons / Volume Up / Core Motion
                  |
          iPhone UDP server :26760
                  |
           Dolphin DSU client
                  |
         Emulated Wii Remote

ARKit pose --------> screen-calibrated / camera pointing + spatial overlay
Core Haptics <----- game rumble from the custom DSU client
```

Dolphin can reach the phone over Wi-Fi (UDP) or Bluetooth LE. Over Bluetooth the same DSU datagrams travel through a small tunnel: the phone is the BLE peripheral, Dolphin the central, and a loopback UDP port on the Mac or iPad (26800 + player index) hands them to the normal DSU client. Wi-Fi is recommended; AirDrop and Handoff cause periodic Wi-Fi pauses and should be off while playing.

## Input and pointing

Core Motion is sampled at a requested 100 Hz. Standard DSU packets carry the full button state, acceleration in g, angular rate in degrees per second and a timestamp. The profile maps these inputs to Dolphin's emulated Wii Remote.

**Screen calibration.** The phone measures two points with ARKit: the top camera corner touching the left and the right screen edge. From these it builds a screen frame (origin between the marks, x along the screen, y up from gravity, z towards the player), stores it as an anchor in a saved ARKit world map and restores it when the room is recognised on the next start. Every camera frame the phone sends its pose in this screen frame. Dolphin uses it as an absolute pointer: pointing at the screen centre is straight ahead, which is mathematically the same as a perfect recenter in the relative camera mode (`Tests/test-screen-pointer.py`).

**Relative camera mode.** Without calibration, camera-assisted pointing uses an ARKit orientation relative to the pose captured when the user recentres. Dolphin converts that quaternion into the same axes as its existing gyro integration and corrects orientation with a 100 ms interpolation time constant. Only normal-quality, fresh poses are accepted. Tracking loss leaves gyro steering active; a new session invalidates the camera reference.

Gyro offset measurement and screen centring are separate. A one-second sample window accepts moderate hand tremor, while bias is updated only when the readings are quiet enough to avoid learning hand motion as a sensor fault.

The camera correction affects pointing, not the acceleration and angular-rate packets used by a game's swing logic. Preserve Angle retains physical rotation beyond the pointer limits.

**Late and bursty packets.** Dolphin no longer keeps only the newest packet: every new sample adds its rotation (rate × phone time difference) to a balance that is paid out over the following Wii Remote polls. Packets that arrive late or in a burst therefore do not shift the pointer, and duplicates are dropped by the packet counter.

## Extensions

The MotionRemote builds add these messages to the DSU transport:

| Type | Direction | Purpose |
| --- | --- | --- |
| `0x100003` | Dolphin/MotionSaber → phone | Rumble strength, player slot and sequence; byte 22 selects a one-shot haptic effect for MotionSaber |
| `0x100004` | Phone → Dolphin | Tracking quality, session epoch, sequence, timestamp, position and quaternion |
| `0x100006` | Phone → Mac apps | Core Motion attitude quaternion (Monitor, MotionSaber motion-only mode) |
| `0x100007` | Phone → Dolphin/MotionSaber | Pose in the calibrated screen frame, tracking quality and reason, calibration and LiDAR flags, screen width |

Messages use the DSU header and CRC. Rumble is routed to the registered client identity and player slot. Duplicated or reordered commands are ignored, and a watchdog stops stale rumble. These checks do not authenticate network peers.

Each phone persists its controller identity and serves one slot. Dolphin assigns each connected phone its own Wii Remote player and keys rumble, pose and overlay state by that player, so several phones can stay on the same slot. The overlay's selected player does not choose which controller receives input or rumble.

## Overlay and recordings

The live overlay is drawn inside Dolphin using ImGui. Its spatial path uses camera positions in metres and retains a three-second window. Tracking gaps break the line instead of inventing a connecting segment. Rumble charts display output sent by the game.

On-device recordings save orientation, acceleration, angular velocity and buttons for up to two minutes. Their SceneKit playback is an orientation visualizer, not a reconstruction of travel through the room. Camera images are neither recorded nor transmitted.

## Diagnostics

The phone, Dolphin and MotionSaber write plain-text logs, one line per event, with repeats of the same event counted rather than written. The phone stamps every controller packet with its sensor time. By comparing that time with the arrival time, Dolphin and MotionSaber classify each gap as held back by Wi-Fi, lost on the way or a pause on the phone, and flag gaps that follow the regular rhythm of AirDrop/Handoff radio scanning.
