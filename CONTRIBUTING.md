# Contributing to Nocchi

Thank you for helping make Nocchi better. Before you start, please read:

- the [README](README.md): what Nocchi is and how to try it;
- the [progress board](docs/PROGRESS.md): where things stand and what comes next (in Chinese);
- the [design spec](docs/DESIGN.md): the visual language and the interfaces between modules (in Chinese). The direction is **retro, not hand-drawn**;
- the [Code of Conduct](CODE_OF_CONDUCT.md).

## Built on GitHub Actions only

Nocchi is **never built or tested on a local machine**: no `xcodebuild`, `swift build`, `swift test` or `xcodegen`, and no simulators. Compiling, unit tests and packaging all happen in [`.github/workflows/ci.yml`](.github/workflows/ci.yml); see [docs/CI.md](docs/CI.md).

1. Fork the repository and create a branch in your fork (for example `feat/sticker-pack` or `fix/notch-size`).
2. Change the code and the docs, push to your fork, and make sure CI is green.
3. Open a pull request against `main` and fill in the template. A maintainer merges it once CI is green.

The repository owner works directly on `main`. Releases are made by the owner pushing a `vX.Y.Z` tag after CI is green.

## Keep the docs current with every change

- `docs/PROGRESS.md`: status, recent updates, next steps, known issues;
- `CHANGELOG.md`: changes users will notice (under "未发布", unreleased);
- any affected design or architecture document: `docs/ARCHITECTURE.md`, `docs/DECISIONS.md`, `docs/DESIGN.md`, `docs/FILM_STOCKS.md`, `docs/ASSETS.md`, `docs/CI.md`.

The development documents are written in Chinese; please keep them that way.

## Code conventions

- Swift 5 language mode, macOS 14+ / iOS 17+.
- Testable logic belongs in `Packages/NocchiKit`, with unit tests; keep the app layers thin.
- The app's interface text is Simplified Chinese.
- Interfaces between modules are listed in `docs/DESIGN.md` §15; update it when you change one.
- Commit messages follow the existing style: `feat(mac): …`, `fix(kit): …`, `design(icon): …`, `docs: …`, `chore(ci): …`.

## Art and copyright

- All artwork must be **original**: no real camera or film brand names, logos or signature looks. Film looks are generated from parametric recipes; no third-party LUTs are bundled.
- Third-party reference images stay in the local `Ref_Image/` folder and are **never committed**.
- Check the license of any third-party code before using it: it must be compatible with the GNU AGPL-3.0.
- When you bring in third-party content (code, text or images), note its source and original license in the file or in the docs.

## License

Nocchi is licensed under the [GNU AGPL-3.0](LICENSE). By submitting a contribution (code, documentation or artwork), you confirm that:

1. it is your own work, or you have the right to submit it; and
2. you license it under the GNU AGPL-3.0, the same license as the rest of the project.

## Reporting problems

- Bugs and feature ideas: use the [issue templates](https://github.com/Chaosnap/Nocchi/issues/new/choose).
- Security problems: **do not open a public issue**; report them privately as described in [SECURITY.md](SECURITY.md).
