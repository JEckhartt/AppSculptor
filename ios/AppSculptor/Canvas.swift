import SwiftUI

enum Handle: CaseIterable, Identifiable {
    case tl, t, tr, r, br, b, bl, l
    var id: Self { self }

    func point(in r: CGRect) -> CGPoint {
        switch self {
        case .tl: return CGPoint(x: r.minX, y: r.minY)
        case .t: return CGPoint(x: r.midX, y: r.minY)
        case .tr: return CGPoint(x: r.maxX, y: r.minY)
        case .r: return CGPoint(x: r.maxX, y: r.midY)
        case .br: return CGPoint(x: r.maxX, y: r.maxY)
        case .b: return CGPoint(x: r.midX, y: r.maxY)
        case .bl: return CGPoint(x: r.minX, y: r.maxY)
        case .l: return CGPoint(x: r.minX, y: r.midY)
        }
    }

    func apply(_ s: CGRect, _ dx: Double, _ dy: Double) -> CGRect {
        var x = Double(s.minX), y = Double(s.minY), w = Double(s.width), h = Double(s.height)
        switch self {
        case .tl: x += dx; w -= dx; y += dy; h -= dy
        case .t: y += dy; h -= dy
        case .tr: w += dx; y += dy; h -= dy
        case .r: w += dx
        case .br: w += dx; h += dy
        case .b: h += dy
        case .bl: x += dx; w -= dx; h += dy
        case .l: x += dx; w -= dx
        }
        if w < 4 { if self == .tl || self == .bl || self == .l { x -= 4 - w }; w = 4 }
        if h < 1 { if self == .tl || self == .t || self == .tr { y -= 1 - h }; h = 1 }
        return CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: max(1, h.rounded()))
    }
}

/// The editable screen, drawn at 1:1 in its own coordinate space ("canvas") and scaled by the parent.
struct EditorCanvas: View {
    @Bindable var store: EditorStore
    let scale: Double

    var body: some View {
        let W = store.width
        let H = store.screenHeight
        ZStack(alignment: .topLeading) {
            ScreenCanvas(screen: store.screen, project: store.project, showTrace: true, showNotes: true)
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { p in store.select(at: p) }

            if H > store.project.device.height + 1 {
                FoldLine(width: W, scale: scale).position(x: W / 2, y: store.project.device.height)
                    .allowsHitTesting(false)
            }

            if let e = store.selected, !e.hidden {
                SelectionOverlay(store: store, e: e, scale: scale)
            }

            ForEach(store.guides) { g in
                if g.vertical {
                    Rectangle().fill(Color.pink).frame(width: 1 / scale, height: H).position(x: g.pos, y: H / 2)
                } else {
                    Rectangle().fill(Color.pink).frame(width: W, height: 1 / scale).position(x: W / 2, y: g.pos)
                }
            }
            .allowsHitTesting(false)
        }
        .frame(width: W, height: H)
        .coordinateSpace(.named("canvas"))
    }
}

struct FoldLine: View {
    let width: Double
    let scale: Double
    var body: some View {
        ZStack(alignment: .trailing) {
            Rectangle()
                .stroke(Color.accentColor.opacity(0.6), style: StrokeStyle(lineWidth: 1 / scale, dash: [6 / scale, 5 / scale]))
                .frame(width: width, height: 0.5)
            Text("end of first screen — content below scrolls")
                .font(.system(size: 10 / max(scale, 0.3), weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.trailing, 6)
                .offset(y: -9 / max(scale, 0.3))
        }
        .frame(width: width)
    }
}

struct SelectionOverlay: View {
    @Bindable var store: EditorStore
    let e: Element
    let scale: Double
    @State private var start: CGRect?

    var body: some View {
        let rect = e.frame
        let hs = 12 / scale
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .overlay(Rectangle().strokeBorder(e.locked ? Color.orange : Color.accentColor, lineWidth: 1.5 / scale))
                .frame(width: max(rect.width, 1), height: max(rect.height, 1))
                .position(x: rect.midX, y: rect.midY)
                .onTapGesture(coordinateSpace: .named("canvas")) { p in store.select(at: p) }
                .gesture(moveGesture, including: e.locked ? .subviews : .all)

            if !e.locked {
                ForEach(Handle.allCases) { h in
                    ZStack {
                        Color.white.opacity(0.001)
                        Circle()
                            .fill(Color.white)
                            .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: 1.5 / scale))
                            .frame(width: hs, height: hs)
                    }
                    .frame(width: hs * 2.6, height: hs * 2.6)
                    .position(h.point(in: rect))
                    .gesture(resizeGesture(h))
                }
            }

            Text("\(Int(e.w)) × \(Int(e.h))")
                .font(.system(size: 10 / scale, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.white)
                .padding(.horizontal, 5 / scale)
                .padding(.vertical, 2 / scale)
                .background(Capsule().fill(Color.accentColor))
                .fixedSize()
                .position(x: rect.midX, y: rect.maxY + 16 / scale)
                .allowsHitTesting(false)
        }
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("canvas"))
            .onChanged { v in
                if start == nil { start = e.frame }
                guard let s = start else { return }
                let moved = s.offsetBy(dx: v.translation.width, dy: v.translation.height)
                let (r, guides) = store.snapped(moved, excluding: e.id, threshold: 6 / scale)
                store.guides = guides
                let id = e.id
                store.editElement(id) { el in
                    el.x = Double(r.minX).rounded()
                    el.y = Double(r.minY).rounded()
                }
            }
            .onEnded { _ in
                start = nil
                store.guides = []
            }
    }

    private func resizeGesture(_ h: Handle) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named("canvas"))
            .onChanged { v in
                if start == nil { start = e.frame }
                guard let s = start else { return }
                let r = h.apply(s, Double(v.translation.width), Double(v.translation.height))
                let id = e.id
                store.editElement(id) { el in
                    el.x = Double(r.minX); el.y = Double(r.minY)
                    el.w = Double(r.width); el.h = Double(r.height)
                }
            }
            .onEnded { _ in start = nil }
    }
}

/// Scroll + zoom container around the canvas.
struct CanvasArea: View {
    @Bindable var store: EditorStore
    @State private var pinchBase: Double?

    var body: some View {
        GeometryReader { geo in
            let W = store.width
            let H = store.screenHeight
            let deviceH = store.project.device.height
            let fit = min((geo.size.width - 32) / W, (geo.size.height - 32) / deviceH)
            let s = max(0.1, fit * store.zoom)
            ScrollView([.horizontal, .vertical]) {
                EditorCanvas(store: store, scale: s)
                    .scaleEffect(s, anchor: .topLeading)
                    .frame(width: W * s, height: H * s, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: (store.project.device.isTablet ? 18 : 40) * s, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    .padding(16)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .top)
            }
            .background(Color(.secondarySystemBackground))
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { v in
                        if pinchBase == nil { pinchBase = store.zoom }
                        store.zoom = min(5, max(0.4, (pinchBase ?? 1) * v.magnification))
                    }
                    .onEnded { _ in pinchBase = nil }
            )
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 2) {
                    Button { store.undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(store.undoStack.isEmpty)
                    Button { store.redo() } label: { Image(systemName: "arrow.uturn.forward") }
                        .disabled(store.redoStack.isEmpty)
                    Divider().frame(height: 18)
                    Button { store.zoom = max(0.4, store.zoom / 1.25) } label: { Image(systemName: "minus.magnifyingglass") }
                    Button { store.zoom = 1 } label: { Text("Fit").font(.footnote.weight(.semibold)) }
                    Button { store.zoom = min(5, store.zoom * 1.25) } label: { Image(systemName: "plus.magnifyingglass") }
                }
                .buttonStyle(.borderless)
                .labelStyle(.iconOnly)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.regularMaterial, in: Capsule())
                .padding(12)
            }
        }
    }
}
