> [!WARNING]
> **Turn off AirDrop and Handoff on the Mac and the iPhone while playing.** They make Wi-Fi pause about once per second, which shows up as a regular stutter. See the [README](https://github.com/leo100410/MotionRemote#readme) for the measurements and where to switch them off.

This release updates only the **iPhone app**. Dolphin for Mac (1.13), DolphiniOS for iPad (1.7), MotionSaber (1.3) and MotionRemote Monitor (1.0) are unchanged: download them from [release v1.15](https://github.com/leo100410/MotionRemote/releases/tag/v1.15).

## What's new in MotionRemote 1.17

- **Redesigned controller screen.** Follows light and dark mode, gives instant spring feedback on every button (a colour change only with Reduce Motion), and keeps status and actions in translucent bars above and below the remote. The sport picker is a standard segmented control; Center and Calibrate are labelled.
- **Clearer calibration sheet** with separate Screen and Motion sensors sections.
- **Fix:** if the phone keeps looking for a saved room it does not recognise, **Forget Saved Room** now works and restarts camera tracking, so you can mark the screen edges again right away.

## Files

| File | For |
| --- | --- |
| `MotionRemote-1.17.ipa` | iPhone app (unsigned; sign it with your own tool) |
| `MotionRemote-1.17-project.tar.gz` | This repository at the release |
| `SHA256SUMS-1.17.txt` | Checksums |

The new design and the fix have been checked in the simulator and by build tests; camera calibration itself needs a real device.
