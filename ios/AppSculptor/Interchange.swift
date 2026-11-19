import SwiftUI
import Vision

// MARK: - JSON in and out

enum InterchangeError: LocalizedError {
    case noJSON, unreadable(String)
    var errorDescription: String? {
        switch self {
        case .noJSON: return "There's no AppSculptor JSON on the clipboard. Copy Claude's whole reply (or just the json block) and try again."
        case .unreadable(let why): return "That JSON couldn't be read: \(why)"
        }
    }
}

enum Interchange {
    /// Accepts a whole chat reply: finds the JSON object inside it.
    static func parse(_ text: String) throws -> Project {
        var s = text
        if let fence = s.range(of: "```json") ?? s.range(of: "```") {
            s = String(s[fence.upperBound...])
            if let end = s.range(of: "```") { s = String(s[..<end.lowerBound]) }
        }
        guard let a = s.firstIndex(of: "{"), let b = s.lastIndex(of: "}"), a < b else { throw InterchangeError.noJSON }
        let json = String(s[a...b])
        do {
            let data = Data(json.utf8)
            // A bare screen or a list of screens is accepted too.
            if let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any], obj["screens"] == nil, obj["elements"] != nil {
                var p = Project()
                p.screens = [try JSONDecoder().decode(Screen.self, from: data)]
                return p
            }
            return try JSONDecoder().decode(Project.self, from: data)
        } catch let e as DecodingError {
            throw InterchangeError.unreadable(String(describing: e).prefix(160).description)
        } catch {
            throw InterchangeError.unreadable(error.localizedDescription)
        }
    }

    /// Layout JSON for the app thread: no photos or screenshots, nothing local.
    static func json(_ p: Project) -> String {
        var c = p
        for i in c.screens.indices {
            c.screens[i].traceImage = nil
            for j in c.screens[i].elements.indices { c.screens[i].elements[j].imageData = nil }
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let d = try? enc.encode(c), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }

    static let importPrompt = """
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
    """
}

// MARK: - Brief for the app thread

@MainActor
enum Exporter {
    static func board(_ p: Project, only: Int? = nil) -> UIImage? {
        let view = BoardView(project: p, only: only)
        let renderer = ImageRenderer(content: view)
        let count = Double(only == nil ? p.screens.count : 1)
        let approxWidth = count * (p.device.width + 80) + 112
        renderer.scale = min(2, 9000 / approxWidth)
        return renderer.uiImage
    }

    static func brief(_ p: Project) -> String {
        let t = p.theme
        var o: [String] = [
            "# UI mockup: \(p.name)",
            "",
            "The attached image shows every screen. This brief lists each screen's elements from top to bottom, with position and size in points (origin top-left, screen \(Int(p.device.width)) × \(Int(p.device.height)) pt). Pink numbered markers in the image match the notes.",
            "",
            "- **Device:** \(p.device.name)",
            "- **Colors:** accent \(t.accent), text on accent \(t.onAccent), background \(t.background), surface \(t.surface), text \(t.text), secondary text \(t.secondaryText), borders \(t.border)",
            "- **Corner radius:** \(Int(t.cornerRadius)) pt · **Font:** \(t.fontFamily ?? "System") (\(t.fontDesign.label.lowercased()))",
            "- **Screens:** \(p.screens.map(\.name).joined(separator: " → "))",
            "",
        ]
        for (i, s) in p.screens.enumerated() {
            o += ["---", "", "## \(i + 1). \(s.name)", ""]
            if !s.notes.isEmpty { o += ["> " + s.notes.replacingOccurrences(of: "\n", with: "\n> "), ""] }
            if let h = s.height { o += ["Scrolls; total height \(Int(h)) pt.", ""] }
            if let bg = s.background { o += ["Background \(bg).", ""] }
            let nums = s.noteNumbers()
            for e in s.elements.filter({ !$0.hidden }).sorted(by: { ($0.y, $0.x) < ($1.y, $1.x) }) {
                o.append("- " + describe(e, t))
                if let n = nums[e.id] { o.append("  - **Note \(n):** " + e.note.replacingOccurrences(of: "\n", with: " ")) }
            }
            o.append("")
        }
        o.append("Treat positions and sizes as the intended layout, but build it with normal stacks and safe areas rather than hard-coded coordinates. Image boxes are placeholders.")
        return o.joined(separator: "\n")
    }

    static func handoff(_ p: Project) -> String {
        brief(p) + "\n\n## Exact layout (AppSculptor JSON)\n\nUse this for precise positions, colors and sizes. Every element listed above is in here.\n\n```json\n" + Interchange.json(p) + "\n```\n"
    }

    private static func q(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\n", with: " "))\"" }

    static func describe(_ e: Element, _ t: Theme) -> String {
        var parts: [String] = []
        switch e.kind {
        case .text: parts.append(q(e.text))
        case .button: parts.append(q(e.text)); if let s = e.symbol { parts.append("icon \(s)") }
        case .textField, .searchBar:
            if !e.placeholder.isEmpty { parts.append("placeholder \(q(e.placeholder))") }
            if !e.text.isEmpty { parts.append("value \(q(e.text))") }
            if let s = e.symbol { parts.append("icon \(s)") }
        case .image: if !e.text.isEmpty { parts.append("shows \(e.text)") }; if e.imageData != nil { parts.append("uses a real photo") }
        case .icon, .fab: parts.append(e.symbol ?? "")
        case .toggle: parts.append("\(q(e.text)) \(e.isOn ? "on" : "off")")
        case .slider: parts.append("at \(Int(e.value * 100))%")
        case .segmented: parts.append(e.items.enumerated().map { $0.offset == e.selectedIndex ? "\($0.element) (selected)" : $0.element }.joined(separator: " · "))
        case .checkbox, .radio: parts.append("\(q(e.text)) \(e.isOn ? "checked" : "unchecked")")
        case .progress: parts.append("\(q(e.text)) at \(Int(e.value * 100))%")
        case .stepper: parts.append(q(e.text))
        case .avatar: parts.append(e.text.isEmpty ? "avatar" : "for \(e.text)")
        case .badge: parts.append(q(e.text))
        case .chip: parts.append("\(q(e.text))\(e.isOn ? " (selected)" : "")")
        case .navBar:
            parts.append("title \(q(e.text))\(e.isOn ? " (large)" : "")")
            if let s = e.symbol { parts.append("left \(s)") }
            if !e.placeholder.isEmpty { parts.append("back text \(q(e.placeholder))") }
            if !e.items.isEmpty { parts.append("right \(e.items.joined(separator: ", "))") }
        case .tabBar:
            parts.append(e.items.enumerated().map { i, raw in
                let t = SymbolGuess.tab(raw)
                return "\(t.label) [\(t.symbol)]\(i == e.selectedIndex ? " (selected)" : "")"
            }.joined(separator: " · "))
        case .listRow:
            parts.append(q(e.text))
            if !e.subtitle.isEmpty { parts.append("subtitle \(q(e.subtitle))") }
            if !e.placeholder.isEmpty { parts.append("value \(q(e.placeholder))") }
            if let s = e.symbol { parts.append("icon \(s)") }
            if e.isOn { parts.append("chevron") }
        case .chart: parts.append("bars " + e.items.joined(separator: ", "))
        case .pageDots: parts.append("\(e.count) pages, page \(e.selectedIndex + 1) active")
        case .rectangle, .ellipse, .divider, .map, .video: break
        }
        var style: [String] = []
        if let f = e.fill { style.append(f == "none" ? "no fill" : "fill \(f)") }
        if let g = e.gradientTo { style.append("gradient to \(g)") }
        if let s = e.stroke, (e.strokeWidth ?? 0) > 0 { style.append("border \(s) \(e.strokeWidth ?? 1)pt") }
        if let r = e.cornerRadius { style.append("radius \(Int(r))") }
        if e.shadowRadius > 0 { style.append("shadow") }
        if let c = e.textColor { style.append("text color \(c)") }
        if let c = e.tint { style.append("highlight \(c)") }
        if FieldSpec.of(e.kind).textStyle, e.kind != .icon { style.append("\(Int(e.fontSize))pt \(e.fontWeight.rawValue)") }
        if let fam = e.fontFamily { style.append(fam) }
        if e.align != .leading { style.append(e.align.rawValue) }
        if e.rotation != 0 { style.append("rotated \(Int(e.rotation))°") }
        if e.opacity < 1 { style.append("opacity \(String(format: "%.2f", e.opacity))") }
        let name = e.name.isEmpty ? "" : " “\(e.name)”"
        let content = parts.filter { !$0.isEmpty }.joined(separator: ", ")
        let geometry = "at \(Int(e.x)),\(Int(e.y)) size \(Int(e.w))×\(Int(e.h))"
        return "**\(e.kind.label)**\(name)" + (content.isEmpty ? "" : " — \(content)") + " · \(geometry)" + (style.isEmpty ? "" : " · " + style.joined(separator: ", "))
    }
}

// MARK: - Export board image

struct BoardView: View {
    let project: Project
    var only: Int? = nil

    var body: some View {
        let indices = only.map { [$0] } ?? Array(project.screens.indices)
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 6) {
                Text(project.name).font(.system(size: 34, weight: .bold))
                Text("\(project.device.name) · accent \(project.theme.accent) · radius \(Int(project.theme.cornerRadius)) · \(project.screens.count) screen\(project.screens.count == 1 ? "" : "s") · made with AppSculptor")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(hex: "#5F6775"))
            }
            HStack(alignment: .top, spacing: 56) {
                ForEach(indices, id: \.self) { i in
                    BoardColumn(project: project, screen: project.screens[i], number: i + 1)
                }
            }
        }
        .padding(56)
        .background(Color(hex: "#F2F3F6"))
        .foregroundStyle(Color(hex: "#111418"))
        .environment(\.colorScheme, .light)
    }
}

struct BoardColumn: View {
    let project: Project
    let screen: Screen
    let number: Int

    var body: some View {
        let width = project.device.width + (project.device.isTablet ? 32 : 24)
        let nums = screen.noteNumbers()
        let noted = screen.elements.filter { nums[$0.id] != nil }.sorted { (nums[$0.id] ?? 0) < (nums[$1.id] ?? 0) }
        VStack(alignment: .leading, spacing: 14) {
            Text("\(number). \(screen.name)").font(.system(size: 22, weight: .bold))
            if !screen.notes.isEmpty {
                Text(screen.notes).font(.system(size: 15)).foregroundStyle(Color(hex: "#5F6775"))
                    .fixedSize(horizontal: false, vertical: true)
            }
            DeviceFrame(device: project.device) {
                ScreenCanvas(screen: screen, project: project, showTrace: false, showNotes: true)
            }
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
            if !noted.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("NOTES").font(.system(size: 12, weight: .bold)).foregroundStyle(Color(hex: "#8A919C"))
                    ForEach(noted) { e in
                        HStack(alignment: .top, spacing: 10) {
                            NoteBadge(number: nums[e.id] ?? 0)
                            Text(e.note).font(.system(size: 15)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

// MARK: - Screenshots → editable layers (on-device Vision)

struct DetectedText { let text: String; let rect: CGRect; let fg: String; let bg: String }
struct DetectedBox { let rect: CGRect; let fill: String }
struct Detected { var texts: [DetectedText] = []; var boxes: [DetectedBox] = []; var background = "#FFFFFF" }

enum ScreenshotReader {
    static func screen(from image: UIImage, name: String, device: DeviceSize, readText: Bool, readShapes: Bool, keepTrace: Bool) async -> Screen {
        let cg = image.uprightCGImage()
        let found = await Task.detached(priority: .userInitiated) { () -> Detected in
            guard let cg else { return Detected() }
            return detect(cg, text: readText, shapes: readShapes)
        }.value

        let W = device.width
        let iw = Double(image.size.width), ih = Double(image.size.height)
        let H = iw > 0 ? (W * ih / iw).rounded() : device.height
        var s = Screen()
        s.name = name
        s.height = abs(H - device.height) < 4 ? nil : H
        s.background = found.background
        s.showHomeIndicator = false
        s.showStatusBar = false
        let statusCut = 54.0 / H

        for b in found.boxes.sorted(by: { $0.rect.width * $0.rect.height > $1.rect.width * $1.rect.height }) {
            var e = Element(kind: .rectangle)
            e.x = (Double(b.rect.minX) * W).rounded(); e.y = (Double(b.rect.minY) * H).rounded()
            e.w = (Double(b.rect.width) * W).rounded(); e.h = (Double(b.rect.height) * H).rounded()
            e.fill = b.fill; e.cornerRadius = 12; e.name = "Detected box"
            s.elements.append(e)
        }
        for t in found.texts {
            if Double(t.rect.maxY) < statusCut { s.showStatusBar = true; continue }
            var e = Element(kind: .text)
            let hPts = Double(t.rect.height) * H
            e.text = t.text
            e.x = (Double(t.rect.minX) * W - 3).rounded(); e.y = (Double(t.rect.minY) * H - 2).rounded()
            e.w = (Double(t.rect.width) * W + 10).rounded(); e.h = (hPts + 4).rounded()
            e.fontSize = max(8, min(72, (hPts * 0.78).rounded()))
            e.fontWeight = e.fontSize >= 22 ? .bold : (e.fontSize >= 17 ? .medium : .regular)
            e.textColor = t.fg
            s.elements.append(e)
        }
        if keepTrace {
            s.traceImage = image.downscaled(maxSide: 1600).jpegData(compressionQuality: 0.7)
            s.traceOpacity = (readText || readShapes) ? 0.25 : 1
            s.showTrace = true
        }
        return s
    }

    static func detect(_ cg: CGImage, text: Bool, shapes: Bool) -> Detected {
        var out = Detected()
        let sampler = PixelSampler(cg)
        if let sm = sampler {
            out.background = PixelSampler.hex(sm.average([(0.03, 0.35), (0.97, 0.45), (0.03, 0.65), (0.97, 0.8), (0.5, 0.98)]))
        }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let textReq = VNRecognizeTextRequest()
        textReq.recognitionLevel = .accurate
        textReq.usesLanguageCorrection = true
        let boxReq = VNDetectRectanglesRequest()
        boxReq.maximumObservations = 40
        boxReq.minimumSize = 0.05
        boxReq.minimumAspectRatio = 0.05
        boxReq.maximumAspectRatio = 1
        boxReq.quadratureTolerance = 12
        boxReq.minimumConfidence = 0.6
        var reqs: [VNRequest] = []
        if text { reqs.append(textReq) }
        if shapes { reqs.append(boxReq) }
        try? handler.perform(reqs)

        if text {
            for o in textReq.results ?? [] {
                guard let cand = o.topCandidates(1).first else { continue }
                let r = flip(o.boundingBox)
                var fg = "#111418", bg = "#FFFFFF"
                if let sm = sampler {
                    let b = sm.ring(r)
                    bg = PixelSampler.hex(b)
                    fg = PixelSampler.hex(sm.mostDifferent(in: r, from: b))
                }
                out.texts.append(DetectedText(text: cand.string, rect: r, fg: fg, bg: bg))
            }
        }
        if shapes {
            for o in boxReq.results ?? [] {
                let r = flip(o.boundingBox)
                if r.width * r.height > 0.85 { continue }
                let fill = sampler.map { PixelSampler.hex($0.inset(r)) } ?? "#F2F3F5"
                out.boxes.append(DetectedBox(rect: r, fill: fill))
            }
        }
        return out
    }

    /// Vision's origin is bottom-left; ours is top-left.
    static func flip(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: 1 - r.maxY, width: r.width, height: r.height) }
}

struct PixelSampler {
    let w: Int
    let h: Int
    let px: [UInt8]

    init?(_ cg: CGImage) {
        let scale = min(1.0, 480.0 / Double(max(cg.width, 1)))
        let w = max(1, Int(Double(cg.width) * scale))
        let h = max(1, Int(Double(cg.height) * scale))
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        let ok = buf.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard ok else { return nil }
        self.w = w; self.h = h; self.px = buf
    }

    func rgb(_ nx: Double, _ ny: Double) -> SIMD3<Double> {
        let x = min(w - 1, max(0, Int(nx * Double(w))))
        let y = min(h - 1, max(0, Int(ny * Double(h))))
        let i = (y * w + x) * 4
        return SIMD3(Double(px[i]), Double(px[i + 1]), Double(px[i + 2]))
    }

    func average(_ pts: [(Double, Double)]) -> SIMD3<Double> {
        guard !pts.isEmpty else { return SIMD3(255, 255, 255) }
        var sum = SIMD3<Double>(0, 0, 0)
        for p in pts { sum += rgb(p.0, p.1) }
        return sum / Double(pts.count)
    }

    func ring(_ r: CGRect) -> SIMD3<Double> {
        let m = 0.006
        let x0 = Double(r.minX) - m, x1 = Double(r.maxX) + m, y0 = Double(r.minY) - m, y1 = Double(r.maxY) + m
        let mx = Double(r.midX), my = Double(r.midY)
        return average([(x0, y0), (x1, y0), (x0, y1), (x1, y1), (mx, y0), (mx, y1), (x0, my), (x1, my)])
    }

    func inset(_ r: CGRect) -> SIMD3<Double> {
        let x0 = Double(r.minX) + Double(r.width) * 0.06, x1 = Double(r.maxX) - Double(r.width) * 0.06
        let y0 = Double(r.minY) + Double(r.height) * 0.08, y1 = Double(r.maxY) - Double(r.height) * 0.08
        return average([(x0, y0), (x1, y0), (x0, y1), (x1, y1)])
    }

    func mostDifferent(in r: CGRect, from bg: SIMD3<Double>) -> SIMD3<Double> {
        var best = bg
        var bestD = -1.0
        for i in 0..<14 {
            for j in 0..<5 {
                let p = rgb(Double(r.minX) + Double(r.width) * (Double(i) + 0.5) / 14,
                            Double(r.minY) + Double(r.height) * (Double(j) + 0.5) / 5)
                let d = p - bg
                let dist = (d * d).sum()
                if dist > bestD { bestD = dist; best = p }
            }
        }
        return best
    }

    static func hex(_ c: SIMD3<Double>) -> String {
        func b(_ v: Double) -> Int { Int(min(255, max(0, v.rounded()))) }
        return String(format: "#%02X%02X%02X", b(c.x), b(c.y), b(c.z))
    }
}

extension UIImage {
    func uprightCGImage() -> CGImage? {
        if imageOrientation == .up, let cg = cgImage { return cg }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in draw(at: .zero) }.cgImage
    }
}
