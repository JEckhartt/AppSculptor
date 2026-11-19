# AppSculptor

Design your app's screens visually, then hand them to the Claude thread that's building the app, so you don't have to describe layouts in words.

There are two versions:

| | What it is | Where |
|---|---|---|
| **iOS app** | Full editor: free positioning, every style option, screenshot import, two-way sync with your app's Claude thread | `ios/` — sideload the IPA |
| **Web app** | Lighter mockup builder that runs in any browser | `index.html` |

## iOS app

### Install (sideload)

1. Download **AppSculptor.ipa** from the [`latest-ipa` release](../../releases/tag/latest-ipa). Every push to `ios/` rebuilds it.
2. Install with **Sideloadly** (Mac/Windows) or **AltStore**, signing with your Apple ID.
   With a free Apple ID the app expires after 7 days. Re-sideload, or let AltStore refresh it.

### The round trip with your app's thread

1. **Import:** in AppSculptor tap **Import → Copy prompt for your app's thread**. Paste it into the Claude thread that's building your app. Claude reads your code and replies with every screen as JSON ([format](SCHEMA.md)). Copy the reply and tap **Paste Claude's reply**.
2. **Edit:** move, resize and restyle anything. Add a **Note for Claude** to any element for behavior the picture can't show.
3. **Send back:** tap **Send to Claude**. Share the image into the thread, then tap **Copy brief + layout** and paste. The thread gets a picture, a written spec, and exact layout data.

You can also import **screenshots** of any app. On-device text and shape detection turns them into editable layers, with the original kept as a tracing layer behind them.

### What you can change

- **27 element types:** text, boxes, circles, images and photos, SF Symbol icons, buttons, text and search fields, toggles, sliders, segmented controls, checkboxes, radios, steppers, chips, badges, progress bars, avatars, nav bars, tab bars, list rows, maps, charts, video, page dots, floating buttons.
- **On every element:** position, size, rotation, opacity, fill, gradient, border color and width, corner radius, shadow blur/offset/strength/color, text size/weight/design/font family/italic/alignment/color/letter spacing/line spacing, highlight color, any SF Symbol (search or type a name), photos, lock, hide, layer order, and changing an element's type.
- **App-wide:** palette presets plus 7 theme colors, default corner radius, font design and family, device size (iPhone, iPad).
- **Editing:** drag with snap guides, 8 resize handles, pinch zoom, undo/redo, layers list with drag reorder, 10 multi-element section templates, multiple screens, and scrolling screens that grow as you add content.

### Building it yourself

GitHub Actions (`.github/workflows/ios.yml`) builds it on a macOS runner with XcodeGen. On a Mac you can run `brew install xcodegen && cd ios && xcodegen generate && open AppSculptor.xcodeproj`. Requires iOS 17 or later.

## Web app

Open `index.html`. Stack components onto phone, tablet or web screens, then use **Export for Claude** to save a PNG and copy a Markdown brief.
