# AppSculptor JSON (format `appsculptor/2`)

This is the layout format the iOS app imports and exports. The app's **Copy prompt for your app's thread** button copies the text below. Paste it into the Claude thread that's building your app, and it replies with your screens in this format.

---

I'm redesigning this app's UI in a mockup editor called AppSculptor. Please describe the app's current screens as AppSculptor JSON so I can import and edit them.

Reply with one ```json code block containing a single object in this shape:

{
  "format": "appsculptor/2",
  "name": "App name",
  "device": {"name": "iPhone 16", "width": 393, "height": 852},
  "theme": {"accent": "#RRGGBB", "onAccent": "#FFFFFF", "background": "#FFFFFF", "surface": "#F2F3F5", "text": "#111418", "secondaryText": "#6B7280", "border": "#DEE1E6", "cornerRadius": 12, "fontDesign": "default"},
  "screens": [
    {"name": "Home", "notes": "What this screen does", "showStatusBar": true,
     "elements": [{"kind": "navBar", "x": 0, "y": 54, "w": 393, "h": 44, "text": "Home"}]}
  ]
}

Rules:
- x, y, w, h are points measured from the top-left of a 393 × 852 screen. The status bar takes the top 54 pt. A tab bar sits at y 769 with h 83.
- If a screen scrolls, set the screen's "height" to the full content height.
- List elements back to front: backgrounds and cards first, then what sits on them.
- Colors are hex strings. "none" means transparent. Icons are SF Symbol names.
- Element kinds and the fields they use:
  text: text · button: text, symbol · textField / searchBar: placeholder, text · image: text (what it shows), symbol · icon: symbol · toggle: text, isOn · slider: value (0–1) · segmented: items, selectedIndex · checkbox / radio: text, isOn · progress: text, value · stepper: text · avatar: text (person's name) · badge: text · chip: text, isOn (selected), symbol · divider · navBar: text (title), symbol (left icon), placeholder (back-button text), items (right-side SF Symbols), isOn (large title) · tabBar: items ("Label|sf.symbol"), selectedIndex · listRow: text, subtitle, placeholder (value on the right), symbol, isOn (chevron) · map · chart: items (numbers) · video · pageDots: count, selectedIndex · fab: symbol · rectangle / ellipse: shapes, cards and backgrounds.
- Optional styling on any element: fill, gradientTo, stroke, strokeWidth, cornerRadius, shadowRadius, shadowY, shadowOpacity, opacity, rotation, tint, textColor, fontSize, fontWeight (ultraLight…black), fontDesign, italic, align (leading / center / trailing), letterSpacing, note.
- Use the real text, icons, colors and layout from the code. Include every screen, and add a "note" to any element whose behavior isn't obvious from looking at it.
