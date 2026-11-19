import SwiftUI

// MARK: - Element kinds

enum ElementKind: String, Codable, CaseIterable, Identifiable {
    case rectangle, ellipse, text, button, textField, searchBar, image, icon, toggle, slider, segmented,
         checkbox, radio, progress, stepper, avatar, badge, chip, divider, navBar, tabBar, listRow,
         map, chart, video, pageDots, fab

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rectangle: return "Box"
        case .ellipse: return "Circle"
        case .text: return "Text"
        case .button: return "Button"
        case .textField: return "Text field"
        case .searchBar: return "Search bar"
        case .image: return "Image"
        case .icon: return "Icon"
        case .toggle: return "Toggle"
        case .slider: return "Slider"
        case .segmented: return "Segmented"
        case .checkbox: return "Checkbox"
        case .radio: return "Radio"
        case .progress: return "Progress"
        case .stepper: return "Stepper"
        case .avatar: return "Avatar"
        case .badge: return "Badge"
        case .chip: return "Chip"
        case .divider: return "Divider"
        case .navBar: return "Nav bar"
        case .tabBar: return "Tab bar"
        case .listRow: return "List row"
        case .map: return "Map"
        case .chart: return "Chart"
        case .video: return "Video"
        case .pageDots: return "Page dots"
        case .fab: return "Floating button"
        }
    }

    var symbol: String {
        switch self {
        case .rectangle: return "square"
        case .ellipse: return "circle"
        case .text: return "textformat"
        case .button: return "capsule.fill"
        case .textField: return "character.cursor.ibeam"
        case .searchBar: return "magnifyingglass"
        case .image: return "photo"
        case .icon: return "star"
        case .toggle: return "switch.2"
        case .slider: return "slider.horizontal.3"
        case .segmented: return "rectangle.split.3x1"
        case .checkbox: return "checkmark.square"
        case .radio: return "smallcircle.filled.circle"
        case .progress: return "chart.bar.xaxis"
        case .stepper: return "plusminus"
        case .avatar: return "person.crop.circle"
        case .badge: return "app.badge"
        case .chip: return "tag"
        case .divider: return "minus"
        case .navBar: return "rectangle.topthird.inset.filled"
        case .tabBar: return "rectangle.bottomthird.inset.filled"
        case .listRow: return "list.bullet"
        case .map: return "map"
        case .chart: return "chart.bar"
        case .video: return "play.rectangle"
        case .pageDots: return "ellipsis"
        case .fab: return "plus.circle.fill"
        }
    }

    static let groups: [(String, [ElementKind])] = [
        ("Basics", [.text, .rectangle, .ellipse, .image, .icon, .divider]),
        ("Controls", [.button, .textField, .searchBar, .toggle, .slider, .segmented, .checkbox, .radio, .stepper, .chip, .progress]),
        ("Navigation", [.navBar, .tabBar, .fab, .pageDots]),
        ("Content", [.listRow, .avatar, .badge, .map, .chart, .video]),
    ]

    /// Lenient parsing so JSON written by hand (or by Claude) still imports.
    static func from(_ raw: String) -> ElementKind {
        let k = raw.lowercased().filter { $0.isLetter }
        if let m = allCases.first(where: { $0.rawValue.lowercased() == k }) { return m }
        let aliases: [String: ElementKind] = [
            "rect": .rectangle, "box": .rectangle, "card": .rectangle, "container": .rectangle, "view": .rectangle, "shape": .rectangle,
            "circle": .ellipse, "oval": .ellipse, "label": .text, "heading": .text, "title": .text, "paragraph": .text,
            "input": .textField, "textinput": .textField, "textarea": .textField, "search": .searchBar, "photo": .image,
            "picture": .image, "symbol": .icon, "switch": .toggle, "segmentedcontrol": .segmented, "tabs": .segmented,
            "progressbar": .progress, "tag": .chip, "pill": .chip, "separator": .divider, "line": .divider,
            "navigationbar": .navBar, "header": .navBar, "toolbar": .navBar, "bottomnav": .tabBar, "row": .listRow,
            "cell": .listRow, "listitem": .listRow, "graph": .chart, "player": .video, "pagecontrol": .pageDots,
            "floatingactionbutton": .fab,
        ]
        return aliases[k] ?? .rectangle
    }
}

enum WeightName: String, Codable, CaseIterable, Identifiable {
    case ultraLight, thin, light, regular, medium, semibold, bold, heavy, black
    var id: String { rawValue }
    var label: String { rawValue == "ultraLight" ? "Ultra light" : rawValue.capitalized }
    var weight: Font.Weight {
        switch self {
        case .ultraLight: return .ultraLight
        case .thin: return .thin
        case .light: return .light
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        case .heavy: return .heavy
        case .black: return .black
        }
    }
    static func parse(_ s: String) -> WeightName? {
        let l = s.lowercased().replacingOccurrences(of: " ", with: "")
        if let w = allCases.first(where: { $0.rawValue.lowercased() == l }) { return w }
        switch l {
        case "100": return .ultraLight
        case "200": return .thin
        case "300": return .light
        case "400", "normal": return .regular
        case "500": return .medium
        case "600", "demibold": return .semibold
        case "700": return .bold
        case "800", "extrabold": return .heavy
        case "900": return .black
        default: return nil
        }
    }
}

enum DesignName: String, Codable, CaseIterable, Identifiable {
    case standard = "default", rounded, serif, monospaced
    var id: String { rawValue }
    var label: String { self == .standard ? "Default" : rawValue.capitalized }
    var design: Font.Design {
        switch self {
        case .standard: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }
}

enum AlignName: String, Codable, CaseIterable, Identifiable {
    case leading, center, trailing
    var id: String { rawValue }
    var text: TextAlignment { self == .leading ? .leading : self == .center ? .center : .trailing }
    var horizontal: HorizontalAlignment { self == .leading ? .leading : self == .center ? .center : .trailing }
    var symbol: String { self == .leading ? "text.alignleft" : self == .center ? "text.aligncenter" : "text.alignright" }
    static func parse(_ s: String) -> AlignName? {
        switch s.lowercased() {
        case "leading", "left", "start": return .leading
        case "center", "centre", "middle": return .center
        case "trailing", "right", "end": return .trailing
        default: return nil
        }
    }
}

// MARK: - Lenient decoding helpers

extension KeyedDecodingContainer {
    func val<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        if let v = try? decodeIfPresent(T.self, forKey: key) { return v }
        return fallback
    }
    func opt<T: Decodable>(_ key: Key) -> T? {
        if let v = try? decodeIfPresent(T.self, forKey: key) { return v }
        return nil
    }
    func str(_ key: Key) -> String? {
        if let s = try? decodeIfPresent(String.self, forKey: key) { return s }
        return nil
    }
}

// MARK: - Element

struct Element: Identifiable, Codable, Equatable {
    var id: String = UUID().uuidString
    var kind: ElementKind
    var name: String = ""
    var x: Double = 0
    var y: Double = 0
    var w: Double = 100
    var h: Double = 44
    var rotation: Double = 0
    var opacity: Double = 1
    var hidden: Bool = false
    var locked: Bool = false
    // Fill, border, shadow
    var fill: String? = nil
    var gradientTo: String? = nil
    var stroke: String? = nil
    var strokeWidth: Double? = nil
    var cornerRadius: Double? = nil
    var shadowRadius: Double = 0
    var shadowY: Double = 0
    var shadowOpacity: Double = 0.15
    var shadowColor: String? = nil
    var tint: String? = nil
    // Text
    var text: String = ""
    var subtitle: String = ""
    var placeholder: String = ""
    var fontSize: Double = 17
    var fontWeight: WeightName = .regular
    var fontDesign: DesignName? = nil
    var fontFamily: String? = nil
    var italic: Bool = false
    var letterSpacing: Double = 0
    var lineSpacing: Double = 0
    var textColor: String? = nil
    var align: AlignName = .leading
    // Content
    var symbol: String? = nil
    var items: [String] = []
    var selectedIndex: Int = 0
    var value: Double = 0.5
    var isOn: Bool = true
    var count: Int = 3
    var imageData: Data? = nil
    var note: String = ""

    init(kind: ElementKind) { self.kind = kind }

    var frame: CGRect { CGRect(x: x, y: y, width: w, height: h) }

    var displayName: String {
        if !name.isEmpty { return name }
        if !text.isEmpty { return text.replacingOccurrences(of: "\n", with: " ") }
        if !placeholder.isEmpty { return placeholder }
        if let s = symbol, kind == .icon || kind == .fab { return s }
        return kind.label
    }

    enum CodingKeys: String, CodingKey {
        case id, kind, name, x, y, w, h, rotation, opacity, hidden, locked, fill, gradientTo, stroke, strokeWidth,
             cornerRadius, shadowRadius, shadowY, shadowOpacity, shadowColor, tint, text, subtitle, placeholder,
             fontSize, fontWeight, fontDesign, fontFamily, italic, letterSpacing, lineSpacing, textColor, align,
             symbol, items, selectedIndex, value, isOn, count, imageData, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = ElementKind.from(c.str(.kind) ?? "rectangle")
        id = c.val(.id, UUID().uuidString)
        name = c.val(.name, "")
        x = c.val(.x, 0); y = c.val(.y, 0); w = c.val(.w, 100); h = c.val(.h, 44)
        rotation = c.val(.rotation, 0); opacity = c.val(.opacity, 1)
        hidden = c.val(.hidden, false); locked = c.val(.locked, false)
        fill = c.opt(.fill); gradientTo = c.opt(.gradientTo); stroke = c.opt(.stroke)
        strokeWidth = c.opt(.strokeWidth); cornerRadius = c.opt(.cornerRadius)
        shadowRadius = c.val(.shadowRadius, 0); shadowY = c.val(.shadowY, 0)
        shadowOpacity = c.val(.shadowOpacity, 0.15); shadowColor = c.opt(.shadowColor); tint = c.opt(.tint)
        text = c.val(.text, ""); subtitle = c.val(.subtitle, ""); placeholder = c.val(.placeholder, "")
        fontSize = c.val(.fontSize, 17)
        fontWeight = c.str(.fontWeight).flatMap(WeightName.parse) ?? .regular
        fontDesign = c.str(.fontDesign).flatMap { DesignName(rawValue: $0.lowercased()) }
        fontFamily = c.opt(.fontFamily)
        italic = c.val(.italic, false)
        letterSpacing = c.val(.letterSpacing, 0); lineSpacing = c.val(.lineSpacing, 0)
        textColor = c.opt(.textColor)
        align = c.str(.align).flatMap(AlignName.parse) ?? .leading
        symbol = c.opt(.symbol)
        if let arr: [String] = c.opt(.items) { items = arr }
        else if let s = c.str(.items) { items = s.split(whereSeparator: { $0 == "\n" || $0 == "," }).map { $0.trimmingCharacters(in: .whitespaces) } }
        selectedIndex = c.val(.selectedIndex, 0); value = c.val(.value, 0.5)
        isOn = c.val(.isOn, true); count = c.val(.count, 3)
        imageData = c.opt(.imageData)
        note = c.val(.note, "")
    }

    /// Only writes values that differ from the defaults, so exported JSON stays readable.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        let d = Element(kind: kind)
        try c.encode(id, forKey: .id)
        try c.encode(kind.rawValue, forKey: .kind)
        try c.encode(x, forKey: .x); try c.encode(y, forKey: .y)
        try c.encode(w, forKey: .w); try c.encode(h, forKey: .h)
        func put<T: Encodable & Equatable>(_ v: T, _ dv: T, _ k: CodingKeys) throws {
            if v != dv { try c.encode(v, forKey: k) }
        }
        try put(name, d.name, .name)
        try put(rotation, d.rotation, .rotation); try put(opacity, d.opacity, .opacity)
        try put(hidden, d.hidden, .hidden); try put(locked, d.locked, .locked)
        try put(fill, d.fill, .fill); try put(gradientTo, d.gradientTo, .gradientTo)
        try put(stroke, d.stroke, .stroke); try put(strokeWidth, d.strokeWidth, .strokeWidth)
        try put(cornerRadius, d.cornerRadius, .cornerRadius)
        try put(shadowRadius, d.shadowRadius, .shadowRadius); try put(shadowY, d.shadowY, .shadowY)
        if shadowRadius > 0 { try c.encode(shadowOpacity, forKey: .shadowOpacity) }
        try put(shadowColor, d.shadowColor, .shadowColor); try put(tint, d.tint, .tint)
        try put(text, d.text, .text); try put(subtitle, d.subtitle, .subtitle); try put(placeholder, d.placeholder, .placeholder)
        try put(fontSize, d.fontSize, .fontSize); try put(fontWeight, d.fontWeight, .fontWeight)
        try put(fontDesign, d.fontDesign, .fontDesign); try put(fontFamily, d.fontFamily, .fontFamily)
        try put(italic, d.italic, .italic); try put(letterSpacing, d.letterSpacing, .letterSpacing)
        try put(lineSpacing, d.lineSpacing, .lineSpacing); try put(textColor, d.textColor, .textColor)
        try put(align, d.align, .align); try put(symbol, d.symbol, .symbol); try put(items, d.items, .items)
        try put(selectedIndex, d.selectedIndex, .selectedIndex); try put(value, d.value, .value)
        try put(isOn, d.isOn, .isOn); try put(count, d.count, .count)
        try put(imageData, d.imageData, .imageData); try put(note, d.note, .note)
    }
}

// MARK: - Theme, device, screen, project

struct Theme: Codable, Equatable {
    var accent = "#3457D5"
    var onAccent = "#FFFFFF"
    var background = "#FFFFFF"
    var surface = "#F2F3F5"
    var text = "#111418"
    var secondaryText = "#6B7280"
    var border = "#DEE1E6"
    var cornerRadius: Double = 12
    var fontDesign: DesignName = .standard
    var fontFamily: String? = nil

    init() {}

    enum CodingKeys: String, CodingKey { case accent, onAccent, background, surface, text, secondaryText, border, cornerRadius, fontDesign, fontFamily }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Theme()
        accent = c.val(.accent, d.accent); onAccent = c.val(.onAccent, d.onAccent)
        background = c.val(.background, d.background); surface = c.val(.surface, d.surface)
        text = c.val(.text, d.text); secondaryText = c.val(.secondaryText, d.secondaryText)
        border = c.val(.border, d.border); cornerRadius = c.val(.cornerRadius, d.cornerRadius)
        fontDesign = c.str(.fontDesign).flatMap { DesignName(rawValue: $0.lowercased()) } ?? .standard
        fontFamily = c.opt(.fontFamily)
    }

    struct Preset: Identifiable { let name: String; let theme: Theme; var id: String { name } }

    static func make(_ accent: String, _ onAccent: String, _ bg: String, _ surface: String, _ text: String, _ sec: String, _ border: String) -> Theme {
        var t = Theme()
        t.accent = accent; t.onAccent = onAccent; t.background = bg; t.surface = surface
        t.text = text; t.secondaryText = sec; t.border = border
        return t
    }

    static let presets: [Preset] = [
        Preset(name: "Light", theme: make("#3457D5", "#FFFFFF", "#FFFFFF", "#F2F3F5", "#111418", "#6B7280", "#DEE1E6")),
        Preset(name: "Dark", theme: make("#7D95F2", "#0E1220", "#0E1014", "#1C1F25", "#F2F4F7", "#9BA2AE", "#2C3038")),
        Preset(name: "Midnight", theme: make("#A78BFA", "#14102A", "#0B0B14", "#17172A", "#EDEBFF", "#8E8CB0", "#26243F")),
        Preset(name: "Forest", theme: make("#1F8A5B", "#FFFFFF", "#F6F8F5", "#E7EEE8", "#13261C", "#5D7366", "#D3DED5")),
        Preset(name: "Sunset", theme: make("#E8590C", "#FFFFFF", "#FFF9F5", "#FDEDE3", "#2B1A12", "#8A6B5C", "#F2D9CA")),
        Preset(name: "Ocean", theme: make("#0A84FF", "#FFFFFF", "#F4F8FB", "#E4EDF5", "#0D1B2A", "#5C6F82", "#D3DEE8")),
        Preset(name: "Mono", theme: make("#111111", "#FFFFFF", "#FFFFFF", "#F2F2F2", "#111111", "#6E6E6E", "#E0E0E0")),
        Preset(name: "Candy", theme: make("#E64980", "#FFFFFF", "#FFF7FA", "#FCE8F0", "#2A1320", "#8C5B73", "#F3D3E1")),
    ]
}

struct DeviceSize: Codable, Equatable, Hashable {
    var name = "iPhone 16"
    var width: Double = 393
    var height: Double = 852

    init(name: String = "iPhone 16", width: Double = 393, height: Double = 852) {
        self.name = name; self.width = width; self.height = height
    }

    enum CodingKeys: String, CodingKey { case name, width, height }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.val(.name, "Custom"); width = c.val(.width, 393); height = c.val(.height, 852)
    }

    var isTablet: Bool { width >= 600 }
    var hasIsland: Bool { !isTablet && height >= 800 }

    static let presets: [DeviceSize] = [
        DeviceSize(name: "iPhone 16", width: 393, height: 852),
        DeviceSize(name: "iPhone 16 Pro Max", width: 440, height: 956),
        DeviceSize(name: "iPhone 16e / SE (large)", width: 390, height: 844),
        DeviceSize(name: "iPhone SE", width: 375, height: 667),
        DeviceSize(name: "iPad 11-inch", width: 834, height: 1194),
        DeviceSize(name: "iPad 13-inch", width: 1032, height: 1376),
    ]
}

struct Screen: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var name = "Screen"
    var notes = ""
    var background: String? = nil
    var height: Double? = nil
    var showStatusBar = true
    var statusBarLight = false
    var showHomeIndicator = true
    var elements: [Element] = []
    var traceImage: Data? = nil
    var traceOpacity: Double = 0.35
    var showTrace = true

    init() {}

    enum CodingKeys: String, CodingKey { case id, name, notes, background, height, showStatusBar, statusBarLight, showHomeIndicator, elements, traceImage, traceOpacity, showTrace }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UUID().uuidString); name = c.val(.name, "Screen"); notes = c.val(.notes, "")
        background = c.opt(.background); height = c.opt(.height)
        showStatusBar = c.val(.showStatusBar, true); statusBarLight = c.val(.statusBarLight, false)
        showHomeIndicator = c.val(.showHomeIndicator, true)
        elements = c.val(.elements, [])
        traceImage = c.opt(.traceImage); traceOpacity = c.val(.traceOpacity, 0.35); showTrace = c.val(.showTrace, true)
    }

    /// Notes are numbered top-to-bottom, left-to-right.
    func noteNumbers() -> [String: Int] {
        var out: [String: Int] = [:]
        var n = 0
        for e in elements.sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) where !e.hidden && !e.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            n += 1
            out[e.id] = n
        }
        return out
    }
}

struct Project: Identifiable, Codable, Equatable {
    var id = UUID().uuidString
    var format = "appsculptor/2"
    var name = "Untitled app"
    var device = DeviceSize()
    var theme = Theme()
    var screens: [Screen] = [Screen()]
    var updatedAt: Double = Date().timeIntervalSince1970

    init() {}

    enum CodingKeys: String, CodingKey { case id, format, name, device, theme, screens, updatedAt }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(.id, UUID().uuidString)
        name = c.val(.name, "Imported app")
        device = c.val(.device, DeviceSize())
        theme = c.val(.theme, Theme())
        screens = c.val(.screens, [])
        if screens.isEmpty { screens = [Screen()] }
        updatedAt = c.val(.updatedAt, Date().timeIntervalSince1970)
    }

    /// Fresh IDs everywhere, so an import never collides with an existing project.
    func withFreshIDs() -> Project {
        var p = self
        p.id = UUID().uuidString
        for i in p.screens.indices {
            p.screens[i].id = UUID().uuidString
            for j in p.screens[i].elements.indices { p.screens[i].elements[j].id = UUID().uuidString }
        }
        return p
    }
}

// MARK: - Colors

extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let named: [String: String] = ["white": "ffffff", "black": "000000", "red": "ff3b30", "green": "34c759", "blue": "007aff",
                                       "gray": "8e8e93", "grey": "8e8e93", "orange": "ff9500", "yellow": "ffcc00", "purple": "af52de", "pink": "ff2d55"]
        if s.isEmpty || s == "none" || s == "clear" || s == "transparent" { self = .clear; return }
        var h = s.hasPrefix("#") ? String(s.dropFirst()) : s
        if let n = named[h] { h = n }
        if h.count == 3 || h.count == 4 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6 || h.count == 8, let v = UInt64(h, radix: 16) else { self = .gray; return }
        let r, g, b, a: Double
        if h.count == 8 {
            r = Double((v >> 24) & 0xff) / 255; g = Double((v >> 16) & 0xff) / 255
            b = Double((v >> 8) & 0xff) / 255; a = Double(v & 0xff) / 255
        } else {
            r = Double((v >> 16) & 0xff) / 255; g = Double((v >> 8) & 0xff) / 255
            b = Double(v & 0xff) / 255; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        func c(_ x: CGFloat) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }
        if a < 0.995 { return String(format: "#%02X%02X%02X%02X", c(r), c(g), c(b), c(a)) }
        return String(format: "#%02X%02X%02X", c(r), c(g), c(b))
    }
}

func initials(_ s: String) -> String {
    let parts = s.split(separator: " ").prefix(2)
    let letters = parts.compactMap { $0.first.map(String.init) }.joined()
    return letters.isEmpty ? "?" : letters.uppercased()
}
