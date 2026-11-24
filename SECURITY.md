# Security Policy

## Supported versions

Only the **latest release** on [Releases](https://github.com/Chaosnap/Nocchi/releases) receives security fixes.

## Reporting a vulnerability

Please **do not** disclose security problems in public issues, discussions or pull requests.

Use GitHub's private vulnerability reporting: open **Security → Report a vulnerability** in this repository ([direct link](https://github.com/Chaosnap/Nocchi/security/advisories/new)) and include:

- the affected Nocchi version and macOS / iOS version;
- steps to reproduce, or a proof of concept;
- the possible impact.

We aim to reply within 7 days, fix confirmed problems as soon as we can, and credit you once the fix is released (if you would like that).

## Scope

Nocchi runs entirely on your device; it does not go online or upload photos (see [PRIVACY.md](PRIVACY.md)). Reports about the following are especially welcome:

- handling of external files: images dropped on the notch or imported, `.cube` LUTs, photo library records;
- permissions: camera, screen recording, folder access, the Photos picker;
- overlays (selfie viewfinder, photo booth curtain, white-screen flash) that make it impossible to quit Nocchi or to use the system.

CI builds are ad-hoc signed and not notarized. That is known and is not a vulnerability.
