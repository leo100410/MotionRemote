# MotionSaber (experimental)

> [!NOTE]
> MotionSaber is an experimental demo. Its hit detection is still being tuned, so it is not a reliable measure of how well tracking or the connection work. Dolphin and the diagnostics logs give a better picture.

A small rhythm game for the Mac in which the iPhone is the sword. Blocks fly towards you in time with the music; cut each one in the direction of its arrow. Blocks with a dot can be cut in any direction.

> [!WARNING]
> Turn off AirDrop and Handoff on the Mac and the iPhone while playing, otherwise the sword stutters about once per second. See the [README](../README.md).

## Play

1. Start MotionRemote 1.20 on the iPhone and tap **Connect**.
2. Open MotionSaber, pick the phone (or enter its IPv4 address) and press **Connect**.
3. Press **Start**, the Space bar or **A** on the phone. **Home** or **+** pauses.

The phone vibrates on every cut: short and sharp for a clean cut, longer and dull for the wrong direction, a light tap for a missed block.

## Tracking modes

| Mode | When | What moves the sword |
| --- | --- | --- |
| Camera tracking | Camera tracking is on and the screen is calibrated | Direction and hand position |
| Motion only | No camera tracking, no calibration, or the camera lost tracking | Direction only; point at the screen centre and press the crosshair (or R) to recenter |

The game switches between the modes automatically and shows the current one in the top right corner. Camera tracking does not need LiDAR. See [screen calibration](INSTALLATION.md#4-calibrate-the-screen).

A block counts as cut when the sword visibly sweeps across it fast enough. Stabbing straight at a block does not cut it.

## Logs

Every session writes a log to `~/Library/Logs/MotionSaber`. It explains connection gaps (held back by Wi-Fi, lost on the way or the phone pausing), tracking changes reported by the phone, switches between camera tracking and motion only, and, for every missed block, how close the sword came and how fast it moved.

## Build

```sh
zsh Saber/build.sh
```

The app is created at `Saber/build/MotionSaber.app`. It compiles the shared packet code from `Sources` and `Monitor/Sources`.
