import SwiftUI

// MARK: - Shared style modifiers

struct Box: ViewModifier {
    let e: Element
    var fill: String? = nil
    var stroke: String? = nil
    var strokeWidth: Double = 0
    var radius: Double = 0

    func body(content: Content) -> some View {
        let r = max(0, e.cornerRadius ?? radius)
        let shape = RoundedRectangle(cornerRadius: r, style: .continuous)
        let sw = e.strokeWidth ?? strokeWidth
        let sc = e.stroke ?? stroke
        return content
            .background {
                if let f = Box.fillStyle(e, fill) { shape.fill(f) }
            }
            .overlay {
                if let sc, sw > 0 { shape.strokeBorder(Color(hex: sc), lineWidth: sw) }
            }
            .modifier(ShadowMod(e: e))
    }

    static func fillStyle(_ e: Element, _ def: String?) -> AnyShapeStyle? {
        guard let base = e.fill ?? def else { return nil }
        if let g = e.gradientTo, !g.isEmpty, g != "none" {
            return AnyShapeStyle(LinearGradient(colors: [Color(hex: base), Color(hex: g)], startPoint: .top, endPoint: .bottom))
        }
        return AnyShapeStyle(Color(hex: base))
    }
}

struct ShadowMod: ViewModifier {
    let e: Element
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: e.shadowColor ?? "#000000").opacity(e.shadowRadius > 0 ? e.shadowOpacity : 0),
                       radius: e.shadowRadius, x: 0, y: e.shadowY)
    }
}

extension Element {
    static func font(_ e: Element, _ t: Theme, size: Double? = nil, weight: WeightName? = nil) -> Font {
        let s = size ?? e.fontSize
        var f: Font
        if let fam = e.fontFamily ?? t.fontFamily, !fam.isEmpty {
            f = .custom(fam, fixedSize: s)
        } else {
            f = .system(size: s, design: (e.fontDesign ?? t.fontDesign).design)
        }
        f = f.weight((weight ?? e.fontWeight).weight)
        if e.italic { f = f.italic() }
        return f
    }
}

// MARK: - One element

struct ElementView: View {
    let e: Element
    let theme: Theme

    var body: some View {
        content.frame(width: max(e.w, 1), height: max(e.h, 1))
    }

    private func c(_ hex: String?, _ fallback: String) -> Color { Color(hex: hex ?? fallback) }
    private var textColor: Color { c(e.textColor, theme.text) }
    private var secondary: Color { Color(hex: theme.secondaryText) }
    private var tint: Color { c(e.tint, theme.accent) }
    private var font: Font { Element.font(e, theme) }
    private var radius: Double { e.cornerRadius ?? theme.cornerRadius }

    private func label(_ s: String, _ color: Color) -> some View {
        Text(s)
            .font(font)
            .tracking(e.letterSpacing)
            .lineSpacing(e.lineSpacing)
            .multilineTextAlignment(e.align.text)
            .foregroundStyle(color)
            .minimumScaleFactor(0.5)
    }

    private var content: AnyView {
        switch e.kind {
        case .rectangle: return AnyView(Color.clear.modifier(Box(e: e, fill: theme.surface, radius: theme.cornerRadius)))
        case .ellipse: return AnyView(ellipse)
        case .text: return AnyView(textView)
        case .button: return AnyView(button)
        case .textField, .searchBar: return AnyView(field)
        case .image: return AnyView(image)
        case .icon: return AnyView(iconView)
        case .toggle: return AnyView(toggle)
        case .slider: return AnyView(slider)
        case .segmented: return AnyView(segmented)
        case .checkbox, .radio: return AnyView(checkbox)
        case .progress: return AnyView(progress)
        case .stepper: return AnyView(stepper)
        case .avatar: return AnyView(avatar)
        case .badge: return AnyView(badge)
        case .chip: return AnyView(chip)
        case .divider: return AnyView(Rectangle().fill(c(e.fill, theme.border)))
        case .navBar: return AnyView(navBar)
        case .tabBar: return AnyView(tabBar)
        case .listRow: return AnyView(listRow)
        case .map: return AnyView(map)
        case .chart: return AnyView(chart)
        case .video: return AnyView(video)
        case .pageDots: return AnyView(pageDots)
        case .fab: return AnyView(fab)
        }
    }

    private var ellipse: some View {
        Ellipse()
            .fill(Box.fillStyle(e, theme.surface) ?? AnyShapeStyle(Color.clear))
            .overlay(Ellipse().strokeBorder(Color(hex: e.stroke ?? "none"), lineWidth: e.strokeWidth ?? 0))
            .modifier(ShadowMod(e: e))
    }

    private var textView: some View {
        label(e.text, textColor)
            .padding(.horizontal, e.fill == nil ? 0 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: e.align.horizontal, vertical: .center))
            .modifier(Box(e: e, radius: 0))
    }

    private var button: some View {
        HStack(spacing: 8) {
            if let s = e.symbol, !s.isEmpty { Image(systemName: s) }
            if !e.text.isEmpty { Text(e.text).tracking(e.letterSpacing) }
        }
        .font(font)
        .foregroundStyle(c(e.textColor, theme.onAccent))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: e.align == .leading ? .center : e.align.horizontal, vertical: .center))
        .modifier(Box(e: e, fill: theme.accent, radius: theme.cornerRadius))
    }

    private var field: some View {
        let isSearch = e.kind == .searchBar
        let multi = e.h > 70
        let sym = e.symbol ?? (isSearch ? "magnifyingglass" : nil)
        return HStack(spacing: 10) {
            if let s = sym, !s.isEmpty { Image(systemName: s).foregroundStyle(secondary) }
            Text(e.text.isEmpty ? e.placeholder : e.text)
                .font(font)
                .foregroundStyle(e.text.isEmpty ? secondary : textColor)
                .lineLimit(multi ? 6 : 1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, multi ? 12 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: multi ? .topLeading : .leading)
        .modifier(Box(e: e, fill: theme.surface, stroke: isSearch ? nil : theme.border, strokeWidth: 1, radius: isSearch ? e.h / 2 : theme.cornerRadius))
    }

    @ViewBuilder private var imageFill: some View {
        if let d = e.imageData, let ui = UIImage(data: d) {
            Image(uiImage: ui).resizable().scaledToFill().frame(width: e.w, height: e.h).clipped()
        } else {
            ZStack {
                Rectangle().fill(Box.fillStyle(e, theme.surface) ?? AnyShapeStyle(Color.clear))
                Rectangle().fill(secondary.opacity(0.08))
                VStack(spacing: 6) {
                    Image(systemName: e.symbol ?? "photo").font(.system(size: max(14, min(e.w, e.h) * 0.22), weight: .light))
                    if !e.text.isEmpty { Text(e.text).font(.system(size: 12, weight: .medium)).lineLimit(2).multilineTextAlignment(.center) }
                }
                .foregroundStyle(secondary)
                .padding(6)
            }
        }
    }

    private var image: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return imageFill
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color(hex: e.stroke ?? "none"), lineWidth: e.strokeWidth ?? 0))
            .modifier(ShadowMod(e: e))
    }

    private var iconView: some View {
        let pad = e.fill == nil ? 0 : min(e.w, e.h) * 0.22
        return Image(systemName: (e.symbol?.isEmpty == false) ? e.symbol! : "star.fill")
            .resizable()
            .scaledToFit()
            .fontWeight(e.fontWeight.weight)
            .foregroundStyle(c(e.textColor, theme.accent))
            .padding(pad)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(Box(e: e, radius: theme.cornerRadius))
    }

    private var toggle: some View {
        HStack {
            if !e.text.isEmpty { label(e.text, textColor).lineLimit(1) }
            Spacer(minLength: 8)
            Capsule()
                .fill(e.isOn ? tint : secondary.opacity(0.25))
                .frame(width: 51, height: 31)
                .overlay(alignment: e.isOn ? .trailing : .leading) {
                    Circle().fill(Color.white).shadow(color: .black.opacity(0.15), radius: 2, y: 1).padding(2)
                }
        }
        .padding(.horizontal, e.fill == nil ? 0 : 14)
        .frame(maxHeight: .infinity)
        .modifier(Box(e: e, radius: theme.cornerRadius))
    }

    private var slider: some View {
        GeometryReader { g in
            let v = min(max(e.value, 0), 1)
            ZStack(alignment: .leading) {
                Capsule().fill(secondary.opacity(0.2)).frame(height: 4)
                Capsule().fill(tint).frame(width: max(4, g.size.width * v), height: 4)
                Circle().fill(Color.white).shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .frame(width: 26, height: 26)
                    .offset(x: (g.size.width - 26) * v)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var segmented: some View {
        let r = e.cornerRadius ?? min(theme.cornerRadius, e.h / 2)
        return HStack(spacing: 0) {
            ForEach(Array(e.items.enumerated()), id: \.offset) { i, s in
                Text(s)
                    .font(font)
                    .foregroundStyle(i == e.selectedIndex ? textColor : secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background {
                        if i == e.selectedIndex {
                            RoundedRectangle(cornerRadius: max(0, r - 2), style: .continuous)
                                .fill(c(e.tint, theme.background))
                                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                        }
                    }
            }
        }
        .padding(2)
        .modifier(Box(e: e, fill: theme.surface, radius: r))
    }

    private var checkbox: some View {
        HStack(spacing: 10) {
            ZStack {
                if e.kind == .radio {
                    Circle().strokeBorder(e.isOn ? tint : secondary.opacity(0.5), lineWidth: e.isOn ? 6 : 1.5)
                } else {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(e.isOn ? tint : Color.clear)
                    RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(e.isOn ? Color.clear : secondary.opacity(0.5), lineWidth: 1.5)
                    if e.isOn { Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.white) }
                }
            }
            .frame(width: 22, height: 22)
            if !e.text.isEmpty { label(e.text, textColor) }
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
        .modifier(Box(e: e, radius: theme.cornerRadius))
    }

    private var progress: some View {
        let v = min(max(e.value, 0), 1)
        return VStack(alignment: .leading, spacing: 6) {
            if !e.text.isEmpty {
                HStack {
                    label(e.text, textColor).lineLimit(1)
                    Spacer()
                    Text("\(Int((v * 100).rounded()))%").font(.system(size: 13, weight: .semibold)).foregroundStyle(secondary)
                }
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(secondary.opacity(0.18))
                    Capsule().fill(tint).frame(width: g.size.width * v)
                }
            }
            .frame(height: e.text.isEmpty ? max(2, e.h) : 8)
        }
        .frame(maxHeight: .infinity)
    }

    private var stepper: some View {
        HStack {
            if !e.text.isEmpty { label(e.text, textColor).lineLimit(1) }
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                Image(systemName: "minus").frame(width: 46, height: 32)
                Rectangle().fill(secondary.opacity(0.3)).frame(width: 1, height: 18)
                Image(systemName: "plus").frame(width: 46, height: 32)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(textColor)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(secondary.opacity(0.14)))
        }
        .frame(maxHeight: .infinity)
        .modifier(Box(e: e, radius: theme.cornerRadius))
    }

    private var avatar: some View {
        let shape = RoundedRectangle(cornerRadius: e.cornerRadius ?? min(e.w, e.h) / 2, style: .continuous)
        return ZStack {
            if let d = e.imageData, let ui = UIImage(data: d) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                Rectangle().fill(Box.fillStyle(e, theme.surface) ?? AnyShapeStyle(Color.clear))
                Text(initials(e.text))
                    .font(.system(size: min(e.w, e.h) * 0.36, weight: .semibold, design: .rounded))
                    .foregroundStyle(c(e.textColor, theme.secondaryText))
            }
        }
        .frame(width: e.w, height: e.h)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color(hex: e.stroke ?? "none"), lineWidth: e.strokeWidth ?? 0))
        .modifier(ShadowMod(e: e))
    }

    private var badge: some View {
        Text(e.text)
            .font(font)
            .foregroundStyle(c(e.textColor, "#FFFFFF"))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(Box(e: e, fill: "#E5484D", radius: e.h / 2))
    }

    private var chip: some View {
        HStack(spacing: 6) {
            if let s = e.symbol, !s.isEmpty { Image(systemName: s) }
            Text(e.text)
        }
        .font(font)
        .foregroundStyle(c(e.textColor, e.isOn ? theme.onAccent : theme.text))
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(Box(e: e, fill: e.isOn ? (e.tint ?? theme.accent) : theme.surface, stroke: e.isOn ? nil : theme.border, strokeWidth: 1, radius: e.h / 2))
    }

    private func navIcons(_ color: Color) -> some View {
        HStack(spacing: 6) {
            if let s = e.symbol, !s.isEmpty { Image(systemName: s).font(.system(size: 20, weight: .medium)) }
            if !e.placeholder.isEmpty { Text(e.placeholder).font(.system(size: 17)) }
            Spacer(minLength: 0)
            HStack(spacing: 18) {
                ForEach(Array(e.items.enumerated()), id: \.offset) { _, s in
                    Image(systemName: s).font(.system(size: 20, weight: .medium))
                }
            }
        }
        .foregroundStyle(color)
        .padding(.horizontal, 16)
    }

    private var navBar: some View {
        let iconColor = c(e.tint, theme.accent)
        return ZStack(alignment: .bottom) {
            Rectangle().fill(Box.fillStyle(e, theme.background) ?? AnyShapeStyle(Color.clear))
            Rectangle().fill(Color(hex: e.stroke ?? theme.border)).frame(height: e.strokeWidth ?? 0.5)
            if e.isOn {
                VStack(alignment: .leading, spacing: 0) {
                    navIcons(iconColor).frame(height: 44)
                    Text(e.text)
                        .font(Element.font(e, theme, size: max(e.fontSize, 34), weight: .bold))
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ZStack {
                    navIcons(iconColor)
                    Text(e.text).font(font).foregroundStyle(textColor).lineLimit(1).padding(.horizontal, 80)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .modifier(ShadowMod(e: e))
    }

    private var tabBar: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Box.fillStyle(e, theme.background) ?? AnyShapeStyle(Color.clear))
            Rectangle().fill(Color(hex: e.stroke ?? theme.border)).frame(height: e.strokeWidth ?? 0.5)
            HStack(spacing: 0) {
                ForEach(Array(e.items.enumerated()), id: \.offset) { i, raw in
                    let item = SymbolGuess.tab(raw)
                    VStack(spacing: 3) {
                        Image(systemName: item.symbol).font(.system(size: 22)).frame(height: 26)
                        Text(item.label).font(.system(size: 10, weight: .medium)).lineLimit(1)
                    }
                    .foregroundStyle(i == e.selectedIndex ? tint : secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 7)
        }
        .modifier(ShadowMod(e: e))
    }

    private var listRow: some View {
        HStack(spacing: 12) {
            if let s = e.symbol, !s.isEmpty {
                Image(systemName: s)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(tint))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(e.text).font(font).foregroundStyle(textColor).lineLimit(1)
                if !e.subtitle.isEmpty { Text(e.subtitle).font(.system(size: 13)).foregroundStyle(secondary).lineLimit(1) }
            }
            Spacer(minLength: 4)
            if !e.placeholder.isEmpty { Text(e.placeholder).font(.system(size: 15)).foregroundStyle(secondary).lineLimit(1) }
            if e.isOn { Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(secondary.opacity(0.7)) }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(Box(e: e, radius: 0))
    }

    private var map: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            Rectangle().fill(c(e.fill, "#E6ECEF"))
            MapRoads().stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            MapRoads(seed: 1).stroke(Color(hex: "#F6D88B"), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            Image(systemName: e.symbol ?? "mappin.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(tint)
                .background(Circle().fill(Color.white).padding(4))
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Color(hex: e.stroke ?? "none"), lineWidth: e.strokeWidth ?? 0))
        .modifier(ShadowMod(e: e))
    }

    private var chart: some View {
        let vals = e.items.compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        let mx = max(vals.max() ?? 1, 0.0001)
        let gap = max(2, e.w / Double(max(vals.count, 1)) * 0.25)
        return HStack(alignment: .bottom, spacing: gap) {
            ForEach(Array(vals.enumerated()), id: \.offset) { i, v in
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(i == e.selectedIndex ? tint : tint.opacity(0.35))
                    .frame(height: max(2, (e.h - 16) * v / mx))
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .modifier(Box(e: e, radius: theme.cornerRadius))
    }

    private var video: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            Rectangle().fill(Box.fillStyle(e, "#111418") ?? AnyShapeStyle(Color.black))
            Image(systemName: e.symbol ?? "play.circle.fill")
                .font(.system(size: max(10, min(e.w, e.h) * 0.25)))
                .foregroundStyle(Color.white.opacity(0.9))
        }
        .clipShape(shape)
        .modifier(ShadowMod(e: e))
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<max(1, min(e.count, 12)), id: \.self) { i in
                Capsule()
                    .fill(i == e.selectedIndex ? tint : secondary.opacity(0.3))
                    .frame(width: i == e.selectedIndex ? 20 : 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fab: some View {
        Image(systemName: e.symbol ?? "plus")
            .font(.system(size: max(10, min(e.w, e.h) * 0.4), weight: .semibold))
            .foregroundStyle(c(e.textColor, theme.onAccent))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .modifier(Box(e: e, fill: theme.accent, radius: min(e.w, e.h) / 2))
    }
}

struct MapRoads: Shape {
    var seed = 0
    func path(in r: CGRect) -> Path {
        var p = Path()
        if seed == 0 {
            for f in [0.22, 0.58, 0.86] {
                p.move(to: CGPoint(x: 0, y: r.height * f))
                p.addLine(to: CGPoint(x: r.width, y: r.height * (f - 0.1)))
            }
            for f in [0.3, 0.7] {
                p.move(to: CGPoint(x: r.width * f, y: 0))
                p.addLine(to: CGPoint(x: r.width * (f + 0.08), y: r.height))
            }
        } else {
            p.move(to: CGPoint(x: 0, y: r.height * 0.75))
            p.addQuadCurve(to: CGPoint(x: r.width, y: r.height * 0.3), control: CGPoint(x: r.width * 0.5, y: r.height * 0.95))
        }
        return p
    }
}

// MARK: - A whole screen

struct ScreenCanvas: View {
    let screen: Screen
    let project: Project
    var showTrace = true
    var showNotes = true

    var body: some View {
        let W = project.device.width
        let H = screen.height ?? project.device.height
        let t = project.theme
        let notes = showNotes ? screen.noteNumbers() : [:]
        ZStack(alignment: .topLeading) {
            Color(hex: screen.background ?? t.background)
            if showTrace, screen.showTrace, let d = screen.traceImage, let ui = UIImage(data: d) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: W, height: H, alignment: .top)
                    .clipped()
                    .opacity(screen.traceOpacity)
            }
            ForEach(screen.elements) { e in
                if !e.hidden {
                    ElementView(e: e, theme: t)
                        .rotationEffect(.degrees(e.rotation))
                        .opacity(e.opacity)
                        .position(x: e.x + e.w / 2, y: e.y + e.h / 2)
                }
            }
            if screen.showStatusBar {
                StatusBar(color: screen.statusBarLight ? Color.white : Color(hex: t.text), island: project.device.hasIsland, tablet: project.device.isTablet)
                    .frame(width: W, height: project.device.isTablet ? 24 : 54)
            }
            if screen.showHomeIndicator {
                Capsule()
                    .fill(screen.statusBarLight ? Color.white : Color(hex: t.text))
                    .frame(width: project.device.isTablet ? 320 : 134, height: 5)
                    .position(x: W / 2, y: H - 8)
            }
            ForEach(screen.elements.filter { notes[$0.id] != nil }) { e in
                NoteBadge(number: notes[e.id] ?? 0)
                    .position(x: min(e.x + e.w - 4, W - 14), y: max(e.y + 4, 14))
            }
        }
        .frame(width: W, height: H)
        .clipped()
    }
}

struct NoteBadge: View {
    let number: Int
    var body: some View {
        Text("\(number)")
            .font(.system(size: 12, weight: .heavy))
            .foregroundStyle(Color.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color(hex: "#D6336C")))
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
    }
}

struct StatusBar: View {
    let color: Color
    let island: Bool
    let tablet: Bool
    var body: some View {
        ZStack {
            if island {
                Capsule().fill(Color.black).frame(width: 125, height: 37).frame(maxHeight: .infinity, alignment: .top).padding(.top, 11)
            }
            HStack {
                Text(tablet ? "9:41  Tue Nov 19" : "9:41")
                    .font(.system(size: tablet ? 13 : 17, weight: .semibold))
                    .frame(width: tablet ? nil : 110)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "cellularbars")
                    Image(systemName: "wifi")
                    Image(systemName: "battery.100")
                }
                .font(.system(size: tablet ? 12 : 15, weight: .semibold))
                .frame(width: tablet ? nil : 110)
            }
            .padding(.horizontal, tablet ? 20 : 0)
            .padding(.top, tablet ? 0 : 6)
            .foregroundStyle(color)
        }
    }
}

struct DeviceFrame<Content: View>: View {
    let device: DeviceSize
    @ViewBuilder var content: Content
    var body: some View {
        let tablet = device.isTablet
        content
            .clipShape(RoundedRectangle(cornerRadius: tablet ? 20 : 46, style: .continuous))
            .padding(tablet ? 16 : 12)
            .background(RoundedRectangle(cornerRadius: tablet ? 34 : 58, style: .continuous).fill(Color(hex: "#16181C")))
    }
}
