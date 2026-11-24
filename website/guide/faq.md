# Questions

## Does my Mac need a notch?

No. On Macs and displays without one, Nocchi draws a small virtual notch at the top center of the screen and works the same way.

## Where are my photos?

Finished prints are JPEGs in `~/Pictures/Nocchi/<year-month>/`. The records, negatives and decorations are in `~/Library/Application Support/Nocchi/`. Nothing leaves your Mac.

## Why does macOS say the app can't be checked?

The builds are ad-hoc signed and not notarized yet. Run `xattr -dr com.apple.quarantine /Applications/Nocchi.app`, or choose *Open Anyway* in *System Settings → Privacy & Security*. Check the zip against `SHA256SUMS.txt` from the same release first.

## How do I quit?

<kbd>⌘Q</kbd> when Nocchi is in front, or the aperture icon in the menu bar → 退出 Nocchi (*quit*). Every overlay (selfie, photo booth, flash) answers to <kbd>Esc</kbd> and <kbd>⌘Q</kbd> too.

## Can I use my own LUTs?

Yes: *Settings → 胶卷 → 导入 .cube 胶卷…* turns a `.cube` file into a custom roll. Nocchi's own stocks are recipes rather than LUT files, and each one can be exported as a `.cube`.

## Can I change a print after it is done?

Yes. Decorations are stored with the photo, so on the decorating desk you can change the template, the caption, the stickers or the drawing at any time; the print is composed again from the negative. Blotches from shaking too hard are the one thing that stays.

## Why is the interface in Chinese?

Nocchi is made in Chinese first. This documentation is in English and [中文](/zh/).

## Is there an iPhone version?

It is in progress: on iPhone the Dynamic Island is the print slot, and a Live Activity shows the print developing.

## Is it free?

Nocchi is free software under the GNU AGPL-3.0. The source is on [GitHub](https://github.com/Chaosnap/Nocchi).
