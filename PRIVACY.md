# Privacy

Nocchi is a camera that lives in your notch. It **runs entirely on your Mac**:

- it does not go online, and does not upload or sync any photo or data;
- there is no account, no analytics, no ads and no crash reporting;
- it collects no personal information.

## Permissions it uses

| Permission | When | What for |
| --- | --- | --- |
| Camera | When you open the selfie viewfinder or the photo booth, or preview a camera in Settings | Taking the picture. The camera runs only while one of these is open and stops when it closes; in the photo booth it starts when you press 开始 (Start) |
| Screen recording | When you use the screen shutter | Running the system's region screenshot and printing what you captured |
| Desktop / Documents / Downloads folders | Only after you turn on "take over system screenshots" in Settings | Reading the screenshot you just took and printing it |
| Photos | When you choose "print from Photos" | The system photo picker: Nocchi only gets the photos you pick, with no access to the rest of your library |

## Where your data lives

| Location | What |
| --- | --- |
| `~/Pictures/Nocchi/<year-month>/` | Finished prints with their white borders (JPEG) |
| `~/Library/Application Support/Nocchi/` | Photo records (captions, stickers, drawings, places, tags and so on), negatives, imported LUTs |
| The app's preferences (UserDefaults) | Settings such as the camera body, film, paper, templates and camera choice |

To delete everything, quit Nocchi and delete the two folders above. When you move a print to the Trash, the finished print goes to the Trash (so you can restore it) and its record and negatives are deleted.

## Contact

Questions about privacy can go to [Issues](https://github.com/Chaosnap/Nocchi/issues); security problems should be reported privately as described in [SECURITY.md](SECURITY.md).
