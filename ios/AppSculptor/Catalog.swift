import SwiftUI

// MARK: - Default elements

extension Element {
    static func make(_ k: ElementKind, width W: Double) -> Element {
        let cw = W - 32
        var e = Element(kind: k)
        e.x = 16; e.w = cw
        switch k {
        case .rectangle: e.h = 120
        case .ellipse: e.w = 80; e.h = 80; e.x = (W - 80) / 2
        case .text: e.text = "Text"; e.h = 24
        case .button: e.text = "Button"; e.h = 52; e.fontWeight = .semibold
        case .textField: e.placeholder = "Placeholder"; e.h = 50
        case .searchBar: e.placeholder = "Search"; e.h = 40
        case .image: e.text = "Image"; e.h = 200
        case .icon: e.symbol = "star.fill"; e.w = 32; e.h = 32; e.x = (W - 32) / 2
        case .toggle: e.text = "Notifications"; e.h = 44
        case .slider: e.h = 32
        case .segmented: e.items = ["Day", "Week", "Month"]; e.h = 34; e.fontSize = 13; e.fontWeight = .semibold
        case .checkbox: e.text = "Remember me"; e.h = 28
        case .radio: e.text = "Option"; e.h = 28
        case .progress: e.text = "Progress"; e.value = 0.6; e.h = 40; e.fontSize = 15
        case .stepper: e.text = "Quantity"; e.h = 36
        case .avatar: e.text = "Alex Morgan"; e.w = 64; e.h = 64; e.x = (W - 64) / 2
        case .badge: e.text = "3"; e.w = 22; e.h = 22; e.fontSize = 12; e.fontWeight = .bold; e.align = .center
        case .chip: e.text = "Chip"; e.w = 80; e.h = 34; e.fontSize = 14; e.fontWeight = .medium; e.isOn = false
        case .divider: e.h = 1
        case .navBar: e.text = "Title"; e.x = 0; e.w = W; e.h = 44; e.fontWeight = .semibold; e.symbol = "chevron.left"; e.isOn = false
        case .tabBar: e.items = ["Home", "Search", "Profile"]; e.x = 0; e.w = W; e.h = 83
        case .listRow: e.text = "Row title"; e.symbol = "star.fill"; e.h = 52
        case .map: e.h = 200
        case .chart: e.items = ["3", "5", "4", "7", "6", "8", "5"]; e.h = 160; e.selectedIndex = 5
        case .video: e.h = 210
        case .pageDots: e.h = 12; e.count = 3
        case .fab: e.symbol = "plus"; e.w = 56; e.h = 56; e.shadowRadius = 10; e.shadowY = 4; e.shadowOpacity = 0.25
        }
        return e
    }
}

// MARK: - Templates (one tap adds a group of elements)

struct Template: Identifiable {
    let title: String
    let symbol: String
    let build: (Double, Theme) -> [Element]
    var id: String { title }

    private static func el(_ k: ElementKind, _ W: Double, _ f: (inout Element) -> Void) -> Element {
        var e = Element.make(k, width: W); f(&e); return e
    }

    static let quick: [Template] = [
        Template(title: "Heading", symbol: "textformat.size.larger") { W, _ in
            [el(.text, W) { $0.text = "Heading"; $0.fontSize = 28; $0.fontWeight = .bold; $0.h = 36 }]
        },
        Template(title: "Body text", symbol: "text.alignleft") { W, _ in
            [el(.text, W) { $0.text = "Supporting text that explains what this screen is for."; $0.fontSize = 16; $0.h = 44 }]
        },
        Template(title: "Caption", symbol: "textformat.size.smaller") { W, t in
            [el(.text, W) { $0.text = "Caption"; $0.fontSize = 13; $0.textColor = t.secondaryText; $0.h = 18 }]
        },
        Template(title: "Outline button", symbol: "capsule") { W, t in
            [el(.button, W) { $0.text = "Secondary"; $0.fill = "none"; $0.stroke = t.accent; $0.strokeWidth = 1.5; $0.textColor = t.accent }]
        },
        Template(title: "Text link", symbol: "link") { W, t in
            [el(.button, W) { $0.text = "Learn more"; $0.fill = "none"; $0.textColor = t.accent; $0.h = 36 }]
        },
        Template(title: "Card", symbol: "rectangle.portrait") { W, t in
            [el(.rectangle, W) { $0.fill = t.background; $0.cornerRadius = 16; $0.shadowRadius = 14; $0.shadowY = 4; $0.shadowOpacity = 0.12; $0.h = 160; $0.name = "Card" }]
        },
    ]

    static let sections: [Template] = [
        Template(title: "Login form", symbol: "person.badge.key") { W, t in
            let cw = W - 32
            return [
                el(.text, W) { $0.text = "Welcome back"; $0.fontSize = 30; $0.fontWeight = .bold; $0.h = 38 },
                el(.text, W) { $0.text = "Sign in to continue."; $0.textColor = t.secondaryText; $0.y = 44; $0.h = 22 },
                el(.textField, W) { $0.placeholder = "Email"; $0.symbol = "envelope"; $0.y = 90; $0.h = 52 },
                el(.textField, W) { $0.placeholder = "Password"; $0.symbol = "lock"; $0.y = 154; $0.h = 52 },
                el(.button, W) { $0.text = "Forgot password?"; $0.fill = "none"; $0.textColor = t.accent; $0.fontSize = 15; $0.y = 212; $0.h = 28; $0.w = 160; $0.x = 16 + cw - 160; $0.align = .trailing },
                el(.button, W) { $0.text = "Sign in"; $0.y = 256; $0.h = 54 },
                el(.text, W) { $0.text = "Don't have an account? Sign up"; $0.align = .center; $0.fontSize = 15; $0.textColor = t.secondaryText; $0.y = 326; $0.h = 22 },
            ]
        },
        Template(title: "Settings list", symbol: "gearshape") { W, t in
            let rows: [(String, String, String)] = [("Notifications", "bell.fill", ""), ("Appearance", "paintbrush.fill", "Light"), ("Privacy", "lock.fill", ""), ("Help & feedback", "questionmark.circle.fill", "")]
            var out = [el(.rectangle, W) { $0.fill = t.surface; $0.cornerRadius = 14; $0.h = Double(rows.count) * 52; $0.name = "Settings group" }]
            for (i, r) in rows.enumerated() {
                out.append(el(.listRow, W) { $0.text = r.0; $0.symbol = r.1; $0.placeholder = r.2; $0.y = Double(i) * 52 })
                if i < rows.count - 1 { out.append(el(.divider, W) { $0.x = 16 + 58; $0.w = W - 32 - 58; $0.h = 0.5; $0.y = Double(i + 1) * 52 }) }
            }
            return out
        },
        Template(title: "Profile header", symbol: "person.crop.circle") { W, t in
            [
                el(.avatar, W) { $0.w = 96; $0.h = 96; $0.x = (W - 96) / 2; $0.text = "Sam Rivera" },
                el(.text, W) { $0.text = "Sam Rivera"; $0.fontSize = 22; $0.fontWeight = .bold; $0.align = .center; $0.y = 108; $0.h = 28 },
                el(.text, W) { $0.text = "Member since March 2026"; $0.fontSize = 15; $0.textColor = t.secondaryText; $0.align = .center; $0.y = 138; $0.h = 20 },
                el(.button, W) { $0.text = "Edit profile"; $0.fill = "none"; $0.stroke = t.accent; $0.strokeWidth = 1.5; $0.textColor = t.accent; $0.fontSize = 15; $0.w = 140; $0.x = (W - 140) / 2; $0.y = 172; $0.h = 36 },
            ]
        },
        Template(title: "Stat tiles", symbol: "square.grid.2x2") { W, t in
            let tw = (W - 32 - 12) / 2
            var out: [Element] = []
            for (i, s) in [("1,284", "Followers"), ("312", "Following")].enumerated() {
                let x = 16 + Double(i) * (tw + 12)
                out.append(el(.rectangle, W) { $0.x = x; $0.w = tw; $0.h = 88; $0.fill = t.surface; $0.cornerRadius = 16 })
                out.append(el(.text, W) { $0.text = s.0; $0.fontSize = 26; $0.fontWeight = .bold; $0.x = x + 14; $0.w = tw - 28; $0.y = 14; $0.h = 32 })
                out.append(el(.text, W) { $0.text = s.1; $0.fontSize = 13; $0.textColor = t.secondaryText; $0.x = x + 14; $0.w = tw - 28; $0.y = 52; $0.h = 18 })
            }
            return out
        },
        Template(title: "Product card", symbol: "bag") { W, t in
            [
                el(.rectangle, W) { $0.fill = t.background; $0.cornerRadius = 18; $0.shadowRadius = 14; $0.shadowY = 4; $0.shadowOpacity = 0.12; $0.h = 300; $0.name = "Product card" },
                el(.image, W) { $0.text = "Product photo"; $0.x = 28; $0.w = W - 56; $0.y = 12; $0.h = 170; $0.cornerRadius = 12 },
                el(.text, W) { $0.text = "Everyday Sneaker"; $0.fontSize = 18; $0.fontWeight = .semibold; $0.x = 28; $0.w = W - 56; $0.y = 194; $0.h = 24 },
                el(.text, W) { $0.text = "$89.00"; $0.fontSize = 16; $0.fontWeight = .bold; $0.textColor = t.accent; $0.x = 28; $0.w = 120; $0.y = 222; $0.h = 22 },
                el(.button, W) { $0.text = "Add to cart"; $0.symbol = "bag.fill"; $0.fontSize = 15; $0.x = 28; $0.w = W - 56; $0.y = 252; $0.h = 36 },
            ]
        },
        Template(title: "Onboarding", symbol: "sparkles") { W, t in
            [
                el(.image, W) { $0.text = "Illustration"; $0.symbol = "sparkles"; $0.h = 280; $0.cornerRadius = 24 },
                el(.text, W) { $0.text = "Build habits that stick"; $0.fontSize = 28; $0.fontWeight = .bold; $0.align = .center; $0.y = 304; $0.h = 36 },
                el(.text, W) { $0.text = "Small daily steps, tracked in one place."; $0.textColor = t.secondaryText; $0.align = .center; $0.y = 346; $0.h = 44 },
                el(.pageDots, W) { $0.y = 406 },
                el(.button, W) { $0.text = "Get started"; $0.y = 438; $0.h = 54 },
            ]
        },
        Template(title: "Chat bubbles", symbol: "bubble.left.and.bubble.right") { W, t in
            [
                el(.text, W) { $0.text = "Hey! Are we still on for tomorrow?"; $0.fill = t.surface; $0.cornerRadius = 18; $0.fontSize = 16; $0.w = 250; $0.h = 60; $0.name = "Incoming"; $0.lineSpacing = 2 },
                el(.text, W) { $0.text = "Yes — 10am at the café."; $0.fill = t.accent; $0.textColor = t.onAccent; $0.cornerRadius = 18; $0.fontSize = 16; $0.w = 210; $0.x = W - 16 - 210; $0.y = 72; $0.h = 40; $0.align = .center; $0.name = "Outgoing" },
                el(.text, W) { $0.text = "Perfect, see you there 👋"; $0.fill = t.surface; $0.cornerRadius = 18; $0.fontSize = 16; $0.w = 220; $0.y = 124; $0.h = 40; $0.align = .center; $0.name = "Incoming" },
            ]
        },
        Template(title: "Search + filters", symbol: "line.3.horizontal.decrease.circle") { W, _ in
            var out = [el(.searchBar, W) { $0.placeholder = "Search" }]
            var x = 16.0
            for (i, s) in ["All", "Popular", "Nearby", "New"].enumerated() {
                let w = Double(s.count) * 9 + 30
                out.append(el(.chip, W) { $0.text = s; $0.isOn = i == 0; $0.x = x; $0.w = w; $0.y = 52 })
                x += w + 8
            }
            return out
        },
        Template(title: "Media row", symbol: "rectangle.stack") { W, t in
            var out: [Element] = [el(.text, W) { $0.text = "Recently played"; $0.fontSize = 20; $0.fontWeight = .bold; $0.h = 26 }]
            let tw = (W - 32 - 24) / 3
            for i in 0..<3 {
                let x = 16 + Double(i) * (tw + 12)
                out.append(el(.image, W) { $0.text = ""; $0.symbol = "music.note"; $0.x = x; $0.w = tw; $0.h = tw; $0.y = 36 })
                out.append(el(.text, W) { $0.text = ["Morning Mix", "Focus", "Chill"][i]; $0.fontSize = 14; $0.fontWeight = .medium; $0.x = x; $0.w = tw; $0.y = 42 + tw; $0.h = 18 })
            }
            return out
        },
    ]
}

// MARK: - Tab item parsing

enum SymbolGuess {
    static let words: [(String, String)] = [
        ("home", "house.fill"), ("search", "magnifyingglass"), ("explore", "safari"), ("discover", "safari"),
        ("profile", "person.crop.circle"), ("account", "person.crop.circle"), ("me", "person.crop.circle"), ("you", "person.crop.circle"),
        ("setting", "gearshape"), ("notif", "bell"), ("alert", "bell"), ("activity", "bell"),
        ("fav", "heart"), ("like", "heart"), ("saved", "bookmark"), ("bookmark", "bookmark"),
        ("chat", "bubble.left.and.bubble.right"), ("message", "bubble.left.and.bubble.right"), ("inbox", "tray"),
        ("cart", "cart"), ("shop", "bag"), ("store", "bag"), ("order", "shippingbox"),
        ("today", "calendar"), ("calendar", "calendar"), ("schedule", "calendar"), ("plan", "calendar"),
        ("stat", "chart.bar"), ("insight", "chart.bar"), ("progress", "chart.bar"), ("report", "chart.bar"),
        ("library", "books.vertical"), ("music", "music.note"), ("photo", "photo.on.rectangle"), ("map", "map"),
        ("wallet", "creditcard"), ("pay", "creditcard"), ("add", "plus.circle"), ("new", "plus.circle"), ("create", "plus.circle"),
        ("feed", "list.bullet"), ("habit", "checkmark.circle"), ("task", "checklist"), ("workout", "figure.run"),
        ("video", "play.rectangle"), ("watch", "play.rectangle"), ("people", "person.2"), ("friend", "person.2"),
    ]
    static func guess(_ label: String) -> String {
        let l = label.lowercased()
        return words.first(where: { l.contains($0.0) })?.1 ?? "circle"
    }
    /// "Home" or "Home|house.fill"
    static func tab(_ raw: String) -> (label: String, symbol: String) {
        let parts = raw.split(separator: "|", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
        let label = parts.first ?? ""
        let sym = parts.count > 1 && !parts[1].isEmpty ? parts[1] : guess(label)
        return (label, sym)
    }
}

// MARK: - Curated SF Symbols (any valid name can also be typed)

enum Symbols {
    static let all: [String] = [
        "house", "house.fill", "magnifyingglass", "person", "person.fill", "person.crop.circle", "person.2", "person.2.fill",
        "gearshape", "gearshape.fill", "bell", "bell.fill", "heart", "heart.fill", "star", "star.fill", "bookmark", "bookmark.fill",
        "plus", "plus.circle", "plus.circle.fill", "minus", "xmark", "xmark.circle.fill", "checkmark", "checkmark.circle", "checkmark.circle.fill",
        "chevron.left", "chevron.right", "chevron.up", "chevron.down", "arrow.left", "arrow.right", "arrow.up", "arrow.down",
        "arrow.up.right", "arrow.clockwise", "arrow.counterclockwise", "arrow.triangle.2.circlepath", "line.3.horizontal",
        "line.3.horizontal.decrease", "ellipsis", "ellipsis.circle", "square.and.arrow.up", "square.and.pencil", "pencil",
        "trash", "trash.fill", "doc", "doc.text", "folder", "folder.fill", "tray", "paperplane", "paperplane.fill",
        "envelope", "envelope.fill", "phone", "phone.fill", "video", "video.fill", "message", "message.fill",
        "bubble.left", "bubble.left.and.bubble.right", "bubble.left.fill", "quote.bubble", "calendar", "clock", "clock.fill",
        "alarm", "timer", "stopwatch", "hourglass", "location", "location.fill", "mappin", "mappin.circle.fill", "map", "map.fill",
        "safari", "globe", "link", "lock", "lock.fill", "lock.open", "key", "key.fill", "shield", "shield.fill", "eye", "eye.slash",
        "camera", "camera.fill", "photo", "photo.fill", "photo.on.rectangle", "mic", "mic.fill", "speaker.wave.2", "speaker.slash",
        "music.note", "music.note.list", "headphones", "play", "play.fill", "play.circle.fill", "pause", "pause.fill",
        "backward.fill", "forward.fill", "shuffle", "repeat", "cart", "cart.fill", "bag", "bag.fill", "creditcard", "creditcard.fill",
        "dollarsign.circle", "giftcard", "tag", "tag.fill", "shippingbox", "chart.bar", "chart.bar.fill", "chart.pie",
        "chart.line.uptrend.xyaxis", "waveform.path.ecg", "heart.text.square", "figure.run", "figure.walk", "dumbbell",
        "flame", "flame.fill", "bolt", "bolt.fill", "leaf", "leaf.fill", "drop", "drop.fill", "sun.max", "sun.max.fill",
        "moon", "moon.fill", "cloud", "cloud.fill", "cloud.rain", "snowflake", "wind", "thermometer", "umbrella",
        "car", "car.fill", "bus", "tram", "airplane", "bicycle", "figure.outdoor.cycle", "fork.knife", "cup.and.saucer",
        "wineglass", "birthday.cake", "gift", "book", "book.fill", "books.vertical", "graduationcap", "pencil.and.ruler",
        "lightbulb", "lightbulb.fill", "brain.head.profile", "sparkles", "wand.and.stars", "paintbrush", "paintbrush.fill",
        "paintpalette", "scissors", "hammer", "wrench.and.screwdriver", "square.grid.2x2", "square.grid.3x3", "list.bullet",
        "list.number", "checklist", "rectangle.stack", "square.stack", "slider.horizontal.3", "switch.2", "dial.low",
        "info.circle", "questionmark.circle", "exclamationmark.triangle", "exclamationmark.circle", "nosign",
        "hand.thumbsup", "hand.thumbsup.fill", "hand.wave", "face.smiling", "crown", "trophy", "medal", "rosette",
        "qrcode", "barcode", "wifi", "antenna.radiowaves.left.and.right", "battery.100", "iphone", "ipad", "laptopcomputer",
        "desktopcomputer", "applewatch", "airpods", "tv", "gamecontroller", "printer", "keyboard", "network",
        "icloud", "icloud.and.arrow.up", "arrow.down.circle", "square.and.arrow.down", "externaldrive", "server.rack",
        "person.crop.circle.badge.plus", "person.badge.key", "rectangle.portrait.and.arrow.right", "power",
        "pawprint", "pawprint.fill", "tortoise", "hare", "fish", "bird", "ant", "ladybug", "tree", "mountain.2",
        "building.2", "house.lodge", "bed.double", "sofa", "shower", "washer", "cart.badge.plus", "storefront",
        "banknote", "bitcoinsign.circle", "percent", "number", "textformat", "bold", "italic", "underline",
        "text.alignleft", "text.aligncenter", "text.alignright", "photo.artframe", "film", "theatermasks",
        "ticket", "megaphone", "newspaper", "flag", "flag.fill", "bell.badge", "app.badge", "circle", "circle.fill",
        "square", "square.fill", "triangle", "diamond", "hexagon", "capsule", "seal",
    ]
}

// MARK: - Sample project

enum SampleProject {
    static func make() -> Project {
        var p = Project()
        p.name = "Habitly (example)"
        let W = p.device.width
        let t = p.theme

        func el(_ k: ElementKind, _ f: (inout Element) -> Void) -> Element { var e = Element.make(k, width: W); f(&e); return e }

        var today = Screen()
        today.name = "Today"
        today.notes = "Home screen: today's habits and progress toward the weekly goal."
        today.elements = [
            el(.navBar) { $0.text = "Today"; $0.isOn = true; $0.h = 96; $0.y = 54; $0.symbol = "line.3.horizontal"; $0.items = ["plus"] },
            el(.segmented) { $0.y = 162 },
            el(.rectangle) { $0.y = 212; $0.w = (W - 44) / 2; $0.h = 88; $0.fill = t.surface; $0.cornerRadius = 16 },
            el(.text) { $0.text = "6 / 8"; $0.fontSize = 26; $0.fontWeight = .bold; $0.x = 30; $0.y = 226; $0.w = 140; $0.h = 32 },
            el(.text) { $0.text = "Habits done"; $0.fontSize = 13; $0.textColor = t.secondaryText; $0.x = 30; $0.y = 264; $0.w = 140; $0.h = 18 },
            el(.rectangle) { $0.x = 16 + (W - 44) / 2 + 12; $0.y = 212; $0.w = (W - 44) / 2; $0.h = 88; $0.fill = t.surface; $0.cornerRadius = 16 },
            el(.text) { $0.text = "12 days"; $0.fontSize = 26; $0.fontWeight = .bold; $0.x = 16 + (W - 44) / 2 + 26; $0.y = 226; $0.w = 140; $0.h = 32 },
            el(.text) { $0.text = "Current streak"; $0.fontSize = 13; $0.textColor = t.secondaryText; $0.x = 16 + (W - 44) / 2 + 26; $0.y = 264; $0.w = 140; $0.h = 18 },
            el(.progress) { $0.text = "Weekly goal"; $0.value = 0.72; $0.y = 316 },
            el(.text) { $0.text = "TODAY'S HABITS"; $0.fontSize = 12; $0.fontWeight = .semibold; $0.letterSpacing = 0.6; $0.textColor = t.secondaryText; $0.y = 378; $0.h = 18 },
            el(.rectangle) { $0.y = 402; $0.h = 4 * 60; $0.fill = t.surface; $0.cornerRadius = 16; $0.name = "Habit list" },
        ]
        let habits = [("Drink water", "8 glasses", true), ("Morning run", "3 km", true), ("Read", "20 pages", false), ("Meditate", "10 minutes", false)]
        for (i, hb) in habits.enumerated() {
            today.elements.append(el(.checkbox) { $0.text = ""; $0.isOn = hb.2; $0.x = 30; $0.w = 24; $0.y = 402 + Double(i) * 60 + 19; $0.h = 22
                if i == 0 { $0.note = "Tapping the circle checks the habit off and updates the 6 / 8 counter above." } })
            today.elements.append(el(.listRow) { $0.text = hb.0; $0.subtitle = hb.1; $0.symbol = nil; $0.x = 46; $0.w = W - 62; $0.y = 402 + Double(i) * 60; $0.h = 60 })
        }
        today.elements.append(el(.tabBar) { $0.items = ["Today|calendar", "Stats|chart.bar", "Profile|person.crop.circle"]; $0.y = 852 - 83 })

        var profile = Screen()
        profile.name = "Profile"
        profile.elements = [
            el(.navBar) { $0.text = "Profile"; $0.symbol = nil; $0.items = ["gearshape"]; $0.y = 54 },
        ]
        for var e in Template.sections[2].build(W, t) { e.y += 120; profile.elements.append(e) }
        for var e in Template.sections[1].build(W, t) { e.y += 352; profile.elements.append(e) }
        profile.elements.append(el(.tabBar) { $0.items = ["Today|calendar", "Stats|chart.bar", "Profile|person.crop.circle"]; $0.selectedIndex = 2; $0.y = 852 - 83 })

        p.screens = [today, profile]
        return p
    }
}
