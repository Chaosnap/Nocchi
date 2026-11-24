# Changelog

The full changelog, in Chinese, is [CHANGELOG.md](https://github.com/Chaosnap/Nocchi/blob/main/CHANGELOG.md). Downloads are on [Releases](https://github.com/Chaosnap/Nocchi/releases).

## 3.0.0 · 2026-11-24

**Steadier and smoother.**

- **Fixed: the selfie could crash Nocchi**, most often with the photo booth loaded. The viewfinder attached its live picture to the camera at the same moment the camera was starting, and the two changed the camera session at once. Attaching and detaching previews, mirroring, starting, stopping and switching cameras now all take turns on one queue. If the camera is taken by another app or unplugged just as you shoot, you get "didn't catch that, try again" instead of a crash.
- **The first visit to the photo booth no longer stutters**: a few seconds after launch, Nocchi prepares the booth in the background (the curtain's shaders and velvet texture, the machine's large images, the samples in the showcase, the curtain and coin sounds) and keeps it ready. It looks exactly the same.

## 2.1.0 · 2026-11-24

**English, and a finer card box.**

- **English interface**: *Settings → 通用 (General) → 语言 (Language)* switches between Simplified Chinese (the default) and English, and Nocchi offers to relaunch in the new language. Menus, the notch, the album, the decorating desk, the photo booth (with English lettering on the machine itself), settings, film, paper, templates and sticker names are all translated, with proper plurals.
- **Switch cameras**: a camera tile next to the film tile switches between the instant camera and the photo booth, and the loaded camera decides what you get. With the photo booth loaded, selfies, the screen shutter and printed photos all become four-frame strips.
- **The card box files by date**: the brass gear next to **＋** files it by caption initial or by year, month or day, and the divider tabs follow.
- **About to be drawn**: hover a divider and it rises out of its slot.
- **Finer cards and tabs**: rounded index-card stock in real pastels, packed denser and messier, a paper clip, and white plastic tabs.
- **The card is the print**: a card drawn from the box is now the print itself, as large as the card, with a white plastic tab behind its top edge, instead of a small print inside an index card that repeated its caption and date.
- **Choose where prints live**: *Settings → General → Storage* moves your prints to another folder or disk without overwriting anything.
- **Fixes**: cards drawn from the box sometimes stayed blank; windows opened from the notch now appear in the space you are using (and over full-screen apps) instead of pulling you to another one; the album's view icons no longer have clipped shadows; the album's search field is readable in dark mode.

## 2.0.0 · 2026-11-24

**Polishing the photo lab.**

- **The photo booth, modelled in Blender as one machine**: a bulb marquee arch with gold lettering on red enamel, a walnut body with fluted pilasters, a chrome-rimmed window, a gilt **Nocchi** maker's plate, a cream enamel console with chrome levers and a glowing start button. The sample hangs in the window while you choose; the camera shows there while you shoot.
- **A theatre curtain**: dark red velvet with real folds and a festoon valance with gold fringe and tassels that sway.
- **The Valentine frame, rebuilt in Blender**: rose card, die-cut paper lace with tiny cut-out hearts, lace rings and gold foil around the heart windows, satin bows.
- **Text boxes and fonts**: put text anywhere on a photo, in any installed font.
- **My stickers**: import your own images as stickers and manage them.
- **A softer corkboard** with an adjustable desk lamp and prints that drop, bounce and swing on their pins.
- **The card box**: cards slide out of their own slot along the divider, then land in a loose pile you can rearrange.
- **Prints come out with real physics**: fed by the rollers a step at a time, they swing and fall.
- **Fixes**: photos were developed too dark and too saturated (an additive effect doubled their opacity); legible text on the decorating desk in dark mode; soft, continuous shadows everywhere; no scrollbars anywhere.

## 1.0.0 · 2026-11-24

**The retro photo lab.** The notch takes the shape of the Dynamic Island and holds a film cabinet; 26 retuned film stocks, six papers, sixteen templates and 60+ printed stickers; a decorating desk for drawing, stickers, templates, captions and posters; an album with four views (corkboard, card box, film light table, wall calendar) and search; a photo booth that lets you choose a frame first.

- **Templates and stickers**: deckle edges, a date stamp, film frames, postage stamps, 70s stripes, an old album page, a photo-studio card and six booth themes; vinyl badges, rubber stamps, ephemera, washi tape, embossed labels and die-cut emoji, all drawn by Nocchi.
- **Captions like a journal**: a caption with a place and #tags on the border, in handwriting, typewriter or letterpress type.
- **Film**: every stock retuned on a new engine (curves, eight hue bands, skin protection, a soft highlight shoulder), with eleven new ones.
- **The notch**: Dynamic-Island-sized hints, a film cabinet with rendered canisters, a paper switcher, and a greeting when Nocchi starts.
- **Cameras**: built-in, external, virtual and Continuity Camera, with a live preview.
- **Print anything**: from Files (<kbd>⌘O</kbd>) or Photos (<kbd>⇧⌘O</kbd>).
- **The album**: a walnut-framed corkboard, a Blender-rendered card box, a film light table with a loupe, a retro wall calendar, and search.
- **The photo booth**: choose a frame, the layout and black and white or color before you drop the coin.
- **Settings**: default templates, the booth's default frame, the caption type, and opening the decorating desk after a print develops.
- **License**: from this release on, Nocchi is free software under the GNU AGPL-3.0.

## 0.1.1 · 2026-11-23

- The photo booth and the selfie can no longer trap you: permission first, overlays below the menu bar, a visible way out, <kbd>Esc</kbd> and <kbd>⌘Q</kbd>, timeouts.
- Finer paper: fibre and grain, a recessed picture window, a glossy coating that catches the light, three layers of shadow.
- A 3D velvet curtain for the photo booth, the notch shelf, and printing images dropped on the notch.

## 0.1.0 · 2026-11-23

The first release for macOS: the notch as a print slot, the screen shutter, the selfie, the photo booth, prints that develop and blotch when shaken too hard, the pile of prints, writing on the border, the corkboard album, 15 film stocks and `.cube` import.
