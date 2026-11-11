Use an iPad as the Wii console and an iPhone running MotionRemote as the controller.

This is a separate DolphiniOS release. The existing iPhone 1.10 and Mac Dolphin downloads remain available.

## Included

- MotionRemote configuration for up to four Wii Remote slots.
- DSU buttons, acceleration and gyroscope input over Wi-Fi on UDP 26760.
- Camera-assisted pointing, Wii game rumble and the optional three-second spatial overlay.
- Built-in StikJIT 2.0.1 helper, pairing-file import, DDI preparation and error reporting.
- Version 1.2 fixes button and motion bindings that earlier iPad builds accidentally saved as boolean values.

## Install

1. Download the IPA, sign it for your iPad and **keep the MotionRemoteJITHelper extension**. Development signing must retain `get-task-allow`.
2. Connect LocalDevVPN. In DolphiniOS open **Settings → JIT**, import this iPad's current pairing file and choose **Enable JIT**. Keep the app open during the initial DDI download.
3. Open MotionRemote on the iPhone and select its player slot. On the iPad go to **Settings → Controllers → MotionRemote**, enter the iPhone's IPv4 address and the matching player, then apply.
4. Start the game. At the Wii Sports title screen, press A+B together on the phone.

**Updating from iPad 1.0/1.1:** stop the game and repeat Apply in the MotionRemote settings once to replace the old broken bindings. Install over the existing app with the same signing account to retain data.

The in-game Touch Controller menu only selects on-screen controls; the DSU controller is assigned in Settings → Controllers.

[Full installation guide](https://github.com/leo100410/MotionRemote/blob/main/docs/IPADOS.md) · [Source and build instructions](https://github.com/leo100410/MotionRemote/tree/main/DolphiniOS)

The base app targets iOS/iPadOS 15+. Built-in JIT needs 17.4+, LocalDevVPN and a valid pairing file; LiveContainer is unsupported. Its helper shares the app installation but can require an additional App ID for signing. JIT has been confirmed by the owner on an iPad 10 with iPadOS 27.0.1. The 1.2 input fix is regression-tested but still needs confirmation on that device.

The IPA is ad-hoc signed and must be re-signed before installation. Matching source and SHA-256 checksums are included. DolphiniOS/Dolphin: GPL-2.0-or-later; StikJIT: MPL-2.0. No games, pairing records or signing credentials are included.
