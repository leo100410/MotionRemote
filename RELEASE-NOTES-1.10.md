Short presses of either volume button now have a minimum transmitted duration of 50 ms. This prevents a press and release from disappearing between Dolphin input polls. Holds longer than that still release immediately when you let go.

Volume Down remains B; Volume Up keeps its configured A/B mapping. Delayed releases are isolated per button and invalidated by cancellation, stop or a new press.

### Downloads

- **MotionRemote-1.10.ipa** — unsigned iPhone app; sign using your usual signing method.
- **MotionRemote-1.10-project.tar.gz** — updated source and documentation.
- **SHA256SUMS-1.10.txt** — file checksums.

Continue using Dolphin MotionRemote 1.8. No Mac update or profile changes are needed.

Release build and automated tap/hold/cancellation tests pass. Very short physical taps still need verification on the target iPhone; minimum pulse duration cannot guarantee delivery across packet loss or an inactive controller.
