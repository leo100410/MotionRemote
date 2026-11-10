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

ARKit pose --------> camera correction + spatial overlay
Core Haptics <----- game rumble from the custom DSU client
```

## Input and pointing

Core Motion is sampled at a requested 100 Hz. Standard DSU packets carry the full button state, acceleration in g, angular rate in degrees per second and a timestamp. The profile maps these inputs to Dolphin's emulated Wii Remote.

Camera-assisted pointing uses an ARKit orientation relative to the pose captured when the user recentres. Dolphin converts that quaternion into the same axes as its existing gyro integration and corrects orientation with a 100 ms interpolation time constant. Only normal-quality, fresh poses are accepted. Tracking loss leaves gyro steering active; a new session invalidates the camera reference.

Gyro offset measurement and screen centring are separate. A one-second sample window accepts moderate hand tremor, while bias is updated only when the readings are quiet enough to avoid learning hand motion as a sensor fault.

The camera correction affects pointing, not the acceleration and angular-rate packets used by a game's swing logic. Preserve Angle retains physical rotation beyond the pointer limits.

## Extensions

The custom build adds two messages to the DSU transport:

| Type | Direction | Purpose |
| --- | --- | --- |
| `0x100003` | Dolphin → phone | Rumble strength, player slot and sequence |
| `0x100004` | Phone → Dolphin | Tracking quality, session epoch, sequence, timestamp, position and quaternion |

Messages use the DSU header and CRC. Rumble is routed to the registered client identity and player slot. Duplicated or reordered commands are ignored, and a watchdog stops stale rumble. These checks do not authenticate network peers.

Each phone persists its controller identity and uses one of four player slots. The overlay's selected player does not choose which controller receives input or rumble.

## Overlay and recordings

The live overlay is drawn inside Dolphin using ImGui. Its spatial path uses camera positions in metres and retains a three-second window. Tracking gaps break the line instead of inventing a connecting segment. Rumble charts display output sent by the game.

On-device recordings save orientation, acceleration, angular velocity and buttons for up to two minutes. Their SceneKit playback is an orientation visualizer, not a reconstruction of travel through the room. Camera images are neither recorded nor transmitted.
