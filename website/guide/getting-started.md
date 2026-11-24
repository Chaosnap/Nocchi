# Install

Nocchi runs on **macOS 14 Sonoma or later**, on Apple silicon and Intel Macs. Every build is made by GitHub Actions and published on the [Releases](https://github.com/Chaosnap/Nocchi/releases/latest) page together with `SHA256SUMS.txt`.

| System | File |
| --- | --- |
| macOS 14 or later (universal) | `Nocchi-macOS-<version>.zip` |
| iPhone | In progress: the Dynamic Island will be the print slot |

Check the download before you open it:

```bash
shasum -a 256 Nocchi-macOS-*.zip
```

Unzip it and move **Nocchi.app** to your Applications folder.

## The builds are not notarized yet

Notarization needs a paid Apple developer certificate, which the project does not have yet. Builds are ad-hoc signed, so macOS asks once. Either run this in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/Nocchi.app
```

or open Nocchi once, then choose *System Settings → Privacy & Security → Open Anyway*.

## Switch to English

Nocchi starts in Simplified Chinese. To use it in English, press <kbd>⌘,</kbd>, open the **通用** (General) tab, and under **语言** (Language) set **界面语言** (Interface language) to **English**. Click **Relaunch Now** and Nocchi opens again in English. This guide uses the English labels.

## First steps

1. Nocchi lives in the menu bar (the aperture icon), in the Dock, and in the notch. You can hide the Dock icon in *Settings → General*.
2. **Move the pointer onto the notch.** The camera panel opens: **Screen Shutter**, **Selfie**, **Photo Booth**, **Print Photos**, the loaded film, the camera and the paper.
3. Press <kbd>⌃⌥⌘S</kbd> and drag over part of the screen. The picture comes out of the notch as a print.
4. Wait about fifteen seconds while it develops, or drag the print and shake it.
5. Double-click the print to decorate it. Press <kbd>⌘0</kbd> to open the album.

::: tip No notch?
On Macs and displays without a notch, Nocchi draws a small virtual notch at the top center of the screen, and everything works the same way.
:::

## Permissions

macOS asks for each permission the first time a feature needs it, before Nocchi shows anything on screen, so the system dialog can never be hidden behind an overlay.

| Permission | Asked when |
| --- | --- |
| Camera | You open the selfie viewfinder or the photo booth, or preview a camera in Settings |
| Screen Recording | You use the screen shutter |
| Desktop, Documents, Downloads | You turn on *Take over system screenshots* |

Nothing is uploaded; see [Privacy and security](./privacy).
