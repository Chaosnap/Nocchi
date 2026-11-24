# Privacy and security

Nocchi is a camera that lives in your notch, and it **runs entirely on your Mac**:

- it never goes online, and does not upload or sync any photo or data;
- there is no account, no analytics, no ads and no crash reporting;
- it collects no personal information.

## Permissions

| Permission | When | What for |
| --- | --- | --- |
| Camera | The selfie viewfinder, the photo booth, or a camera preview in Settings | Taking the picture. The camera runs only while one of these is open; in the photo booth it starts when you press 开始 (start) |
| Screen Recording | The screen shutter | The system's region screenshot, which is then printed |
| Desktop / Documents / Downloads | Only with *take over system screenshots* on | Reading the screenshot you just took |
| Photos | *Print from Photos* | The system photo picker; Nocchi only gets the photos you pick |

## Where your photos live

| Location | What |
| --- | --- |
| `~/Pictures/Nocchi/<year-month>/` | Finished prints with their borders (JPEG) |
| `~/Library/Application Support/Nocchi/` | Photo records (captions, stickers, drawings, places, tags), negatives, imported LUTs |
| The app's preferences | Settings such as the camera body, film, paper, templates and camera |

To delete everything, quit Nocchi and delete those two folders. Moving a print to the Trash puts the finished print in the Trash (so you can get it back) and deletes its record and negatives.

## Overlays never trap you

Permissions are asked before any overlay appears, overlays stay below the menu bar, every overlay has a visible way out and answers to <kbd>Esc</kbd> and <kbd>⌘Q</kbd>, and anything waiting on the camera times out.

## Reporting a vulnerability

Please report security problems privately through GitHub: *Security → Report a vulnerability* in the [repository](https://github.com/Chaosnap/Nocchi/security/advisories/new). See the [security policy](https://github.com/Chaosnap/Nocchi/blob/main/SECURITY.md).
