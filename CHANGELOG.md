# Changelog

## 1.17 (iPhone)

- Redesigned controller screen: adapts to light and dark mode, instant spring feedback on every button (none with Reduce Motion), translucent top and bottom bars, a standard sport picker and labelled Center and Calibrate buttons.
- The calibration sheet is a clear form with Screen and Motion sensors sections.
- Fix: **Forget Saved Room** works while the phone is still looking for a saved room it does not recognise, and restarts camera tracking so the screen edges can be marked again.
- Dolphin, DolphiniOS, MotionSaber and Monitor are unchanged; use the files from release 1.15.

## 1.15 (iPhone) · Dolphin 1.13 (Mac) · DolphiniOS 1.7 (iPad) · MotionSaber 1.3 · Monitor 1.0

- **Turn off AirDrop and Handoff while playing.** Measurements showed that their periodic Wi-Fi pauses caused the remaining stutter.
- Screen calibration on the phone ("virtual sensor bar") with a saved room; Dolphin uses it as an absolute pointer without recentering.
- Connections window in Dolphin with one row per player, Wi-Fi and Bluetooth discovery, automatic profiles and a link test.
- Several phones at once: each connected phone gets its own Wii Remote even when all phones use the same player setting. Fixed phones replacing each other, stalls of all players when one phone missed a status reply, and duplicate DSU entries for the same phone.
- Bluetooth LE transport (tunnelled DSU) with a lower connection interval and immediate sending; Wi-Fi remains the recommended link.
- Late or bursty packets no longer shift the pointer (rotation is accumulated per sample).
- Diagnostics logs on the phone, in Dolphin and in MotionSaber that explain tracking and connection problems.
- New Mac apps: MotionSaber, a rhythm game with the phone as a sword, and MotionRemote Monitor with a live 3D view and graphs.
- One-shot haptic effects for MotionSaber cuts.

## 1.10

- Keep short volume-button taps visible for at least 50 ms across Dolphin input polls.
- Keep release timing immediate for longer holds.
- Cancel pending releases on stop, mapping/camera changes and capture cancellation.

## 1.9

- Map Volume Down to B in every sport.
- Keep Volume Up, Volume Down and on-screen button holds independent.
- Release both volume inputs when changing camera mode.
- Compatible with the existing Dolphin MotionRemote 1.8 build.

## 1.8

- Correct camera pointer axes to match the existing gyro input chain.
- Allow calibration while holding the phone; reject sustained movement without learning tremor as gyro bias.
- Add regression checks for each pointing axis and calibration motion windows.

## 1.7

- Add camera-assisted pointing and guided screen-centre calibration.
- Make the phone smaller and translucent in the three-second spatial overlay.

## Earlier development

- Add Wii Remote controls, per-sport trigger mapping and local motion recordings.
- Add four-player routing, game rumble and an optional Dolphin overlay.
- Preserve the physical pointing angle beyond screen edges.
