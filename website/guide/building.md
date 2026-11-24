# Built in the cloud

Nocchi is never built or tested on anyone's own computer. Everything is compiled, tested, packaged and released by GitHub Actions, so every download comes from a public, repeatable build.

| Workflow | When | What it does |
| --- | --- | --- |
| [CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml) | Every push | Runs the `NocchiKit` unit tests, generates the Xcode project with XcodeGen, builds the macOS app (Release, ad-hoc signed) and attaches it as an artifact |
| [Release](https://github.com/Chaosnap/Nocchi/actions/workflows/release.yml) | A `vX.Y.Z` tag | Tests, renders the icons from the SVG source, builds with the version from the tag, and publishes `Nocchi-macOS-<version>.zip` and `SHA256SUMS.txt` with notes from the changelog |
| [Screenshots](https://github.com/Chaosnap/Nocchi/actions/workflows/screenshots.yml) | App changes | Builds the app and runs its screenshot mode: original sample photos are developed with the real film stocks and templates, and the app captures its own windows and panels. The pictures are committed to `website/public/screenshots` |
| [Pages](https://github.com/Chaosnap/Nocchi/actions/workflows/pages.yml) | Site or screenshot changes | Builds this site with VitePress and publishes it to GitHub Pages |

## Getting a build

- **Releases**: [the latest release](https://github.com/Chaosnap/Nocchi/releases/latest).
- **The latest commit**: open a green run of [CI](https://github.com/Chaosnap/Nocchi/actions/workflows/ci.yml) and download the `Nocchi-macOS` artifact (you need to be signed in to GitHub).

## The pieces

| Path | What |
| --- | --- |
| `Packages/NocchiKit` | The darkroom core shared by both apps: film recipes and 3D LUTs, the Core Image pipeline, development and shake detection, paper composition, templates, stickers, the photo library, procedural sound |
| `macOS/` | The Mac app; the notch is the print slot |
| `iOS/` | The iPhone app and its Live Activity (in progress) |
| `Shared/Art.xcassets` | Original artwork: camera bodies, textures, Blender renders |
| `design/` | The icon's SVG source, Blender scripts, the screenshot sample photos |
| `website/` | This site |

The development documents ([progress](https://github.com/Chaosnap/Nocchi/blob/main/docs/PROGRESS.md), design, architecture, decisions) are written in Chinese.
