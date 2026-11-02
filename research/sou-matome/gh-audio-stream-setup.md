# GitHub audio streaming for authorized MP3 files

The iOS app fetches `content-packs/sou-matome-audio-streams.json` by HTTPS
using `raw.githubusercontent.com`, then streams each listed track using
`AVPlayer`. The app does not contain the 116 recordings, and this repository
does not publish them. Ensure that the rights holder explicitly permits
redistribution before hosting original audiobook/CD recordings publicly.

Manifest format:

```json
{
  "schemaVersion": 1,
  "tracks": [
    {
      "cd": "CD1",
      "track": 1,
      "url": "https://raw.githubusercontent.com/OWNER/REPOSITORY/BRANCH/audio/CD1/01.mp3"
    }
  ]
}
```

The allowed track ranges are CD1: 01–64 and CD2: 01–52. Each URL must
use HTTPS on raw.githubusercontent.com and end in .mp3. A private GitHub
repository needs an authenticated delivery layer; a raw.githubusercontent.com
URL by itself does not make private files streamable without credentials.

The 'CD trực tuyến' button can load a custom manifest URL if the rights
holder provides one; all metadata are validated and a missing track is not
reported as downloaded.

For extracted Sou Matome text, the personally supplied JSON is imported
in-app into its private source-candidate library. Unchecked source
translations and missing Hán–Việt readings must not be silently marked
as approved lesson/quiz answers.
