# Changelog

The full changelog, in Chinese, is [CHANGELOG.md](https://github.com/Chaosnap/Nocchi/blob/main/CHANGELOG.md). Downloads are on [Releases](https://github.com/Chaosnap/Nocchi/releases).

## 5.0.0 · 2026-11-25

**Light that holds still.**

- **The Lighting card opens and closes smoothly**: the brass badge and the card sit on their own layer, so opening or closing the card no longer recomputes the whole board.
- **Static light and dust**: the light and the dust on the board are drawn once as still images and redrawn only when you change the light. The dust no longer drifts.
- **Applied when you let go**: while you turn the lamp or drag a slider, the little board on the card follows along, and the corkboard takes the new light once you stop. Day or night, the light source, fasteners and Reset apply right away. The prints' shadows still follow the light.

## 4.5.0 · 2026-11-24

**A beam of light.**

- **Light from the top-right corner**: instead of a patch of window light, the corkboard is lit by a beam that slants down from the top-right corner, brightest a little way from the lamp and fading with distance. Drag on the little board on the *Lighting* card to turn it. Day is warm sunlight, night is a desk lamp or moonlight, and the prints' shadows fall away from the lamp.
- **A smooth corkboard with the light on**: the light is computed once at low resolution and laid on with plain transparency (no full-board blur or screen blending), the dust is a Core Animation particle emitter that runs on the graphics server, and turning the light no longer recomputes every print on the board. Nothing else about the board changed.

## 4.0.0 · 2026-11-24

**Stickers and text that follow your hand.**

- **Smooth moving, resizing and rotating on the decorating desk**: dragging a sticker or a text box, or turning its handle, used to rewrite the whole photo on every movement, so the desk recomputed everything and text was laid out and rendered again each time. Now only that sticker or text box moves, using the image already drawn; the photo is updated once when you let go (still one undo step) and the art is redrawn at its new size.
- **Steadier rotation**: the handle keeps turning past 180° without a jump, and holding ⇧ snaps to 15° steps.
- **No window bars on the corkboard**: sunlight and moonlight fall as a soft patch, without the cross of glazing bars.

## 3.1.0 · 2026-11-24

**Day and night.**

- **A corkboard with real light**: on the *Lighting* card, **Day** lets the sun slant in through a window and lay a warm patch of panes across the board; **Night** dims the room to a **Desk lamp**, a warm pool that falls off with distance, or cool **Moonlight** through the window. The light falls on the prints as well as the cork, and their shadows follow it. The lighting engine is ported from Typewriter Nocturne (MIT).
- **Move the light**: drag the brass knob on the card's little board to put the sun, the lamp or the moon where you want; **Reach** sets how high the lamp hangs or how large the window is.
- **Dust in the beam**: the **Dust** slider sets how many motes drift and glint in the light.
- **The wall calendar**: prints are held by a strip of washi tape, and several on one day make a little fanned stack with a red count stamp, which spreads when you hover.

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
