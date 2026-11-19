import SwiftUI
import Observation

// MARK: - All projects on this device

@Observable
final class Library {
    var projects: [Project] = []
    @ObservationIgnored private let dir: URL

    init() {
        dir = URL.documentsDirectory.appending(path: "Projects", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        load()
        if projects.isEmpty {
            let p = SampleProject.make()
            projects = [p]
            write(p)
        }
    }

    func load() {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        projects = files.filter { $0.pathExtension == "json" }
            .compactMap { url -> Project? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(Project.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func fileURL(_ id: String) -> URL { dir.appending(path: "\(id).json") }

    private func write(_ p: Project) {
        if let d = try? JSONEncoder().encode(p) { try? d.write(to: fileURL(p.id), options: .atomic) }
    }

    func project(_ id: String) -> Project? { projects.first { $0.id == id } }

    func save(_ p: Project) {
        var p = p
        p.updatedAt = Date().timeIntervalSince1970
        if let i = projects.firstIndex(where: { $0.id == p.id }) { projects[i] = p } else { projects.insert(p, at: 0) }
        write(p)
    }

    @discardableResult
    func add(_ p: Project) -> Project {
        let fresh = p.withFreshIDs()
        save(fresh)
        return fresh
    }

    @discardableResult
    func createBlank() -> Project {
        var p = Project()
        p.name = "New app"
        var s = Screen()
        s.name = "Home"
        var nav = Element.make(.navBar, width: p.device.width)
        nav.text = "Home"; nav.symbol = nil; nav.y = 54
        s.elements = [nav]
        p.screens = [s]
        save(p)
        return p
    }

    func duplicate(_ id: String) {
        guard var p = project(id) else { return }
        p.name += " copy"
        add(p)
    }

    func delete(_ id: String) {
        projects.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: fileURL(id))
    }

    /// Files opened from the share sheet or Files app.
    @discardableResult
    func importFile(_ url: URL) -> Project? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8),
              let p = try? Interchange.parse(text) else { return nil }
        return add(p)
    }
}

// MARK: - One open project

enum Panel: String, CaseIterable, Identifiable {
    case add = "Add", edit = "Edit", layers = "Layers", screen = "Screen", style = "Style"
    var id: String { rawValue }
}

struct Guide: Identifiable, Equatable {
    let id = UUID()
    let vertical: Bool
    let pos: Double
}

enum LayerMove { case front, forward, backward, back }

@Observable
final class EditorStore {
    var project: Project
    var screenIndex = 0
    var selectedID: String?
    var panel: Panel = .add
    var zoom: Double = 1
    var guides: [Guide] = []
    private(set) var undoStack: [Project] = []
    private(set) var redoStack: [Project] = []
    @ObservationIgnored private var lastEdit = Date.distantPast
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored let library: Library

    init(project: Project, library: Library) {
        self.project = project
        self.library = library
    }

    // MARK: Reading

    var screen: Screen { project.screens[min(max(screenIndex, 0), project.screens.count - 1)] }
    var width: Double { project.device.width }
    var screenHeight: Double { screen.height ?? project.device.height }
    var selected: Element? {
        guard let id = selectedID else { return nil }
        return screen.elements.first { $0.id == id }
    }

    // MARK: Editing with undo

    func edit(coalesce: Bool = false, _ change: (inout Project) -> Void) {
        var p = project
        change(&p)
        guard p != project else { return }
        if !coalesce || Date().timeIntervalSince(lastEdit) > 0.8 {
            undoStack.append(project)
            if undoStack.count > 150 { undoStack.removeFirst() }
            redoStack.removeAll()
        }
        lastEdit = Date()
        project = p
        scheduleSave()
    }

    func editScreen(coalesce: Bool = false, _ change: (inout Screen) -> Void) {
        let i = min(screenIndex, project.screens.count - 1)
        edit(coalesce: coalesce) { change(&$0.screens[i]) }
    }

    func editElement(_ id: String, coalesce: Bool = true, _ change: (inout Element) -> Void) {
        editScreen(coalesce: coalesce) { s in
            if let i = s.elements.firstIndex(where: { $0.id == id }) { change(&s.elements[i]) }
        }
    }

    func undo() {
        guard let p = undoStack.popLast() else { return }
        redoStack.append(project)
        project = p
        afterHistoryJump()
    }

    func redo() {
        guard let p = redoStack.popLast() else { return }
        undoStack.append(project)
        project = p
        afterHistoryJump()
    }

    private func afterHistoryJump() {
        screenIndex = min(screenIndex, project.screens.count - 1)
        if selected == nil { selectedID = nil }
        lastEdit = .distantPast
        scheduleSave()
    }

    func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            self.library.save(self.project)
        }
    }

    func saveNow() {
        saveTask?.cancel()
        library.save(project)
    }

    // MARK: Bindings for the inspector

    func binding(_ id: String) -> Binding<Element> {
        Binding(
            get: { self.screen.elements.first(where: { $0.id == id }) ?? Element(kind: .rectangle) },
            set: { new in self.editElement(id) { $0 = new } }
        )
    }

    var screenBinding: Binding<Screen> {
        Binding(get: { self.screen }, set: { new in self.editScreen(coalesce: true) { $0 = new } })
    }

    var themeBinding: Binding<Theme> {
        Binding(get: { self.project.theme }, set: { new in self.edit(coalesce: true) { $0.theme = new } })
    }

    var nameBinding: Binding<String> {
        Binding(get: { self.project.name }, set: { new in self.edit(coalesce: true) { $0.name = new } })
    }

    var deviceBinding: Binding<DeviceSize> {
        Binding(get: { self.project.device }, set: { new in self.edit { $0.device = new } })
    }

    // MARK: Selection

    func select(at p: CGPoint) {
        let hits = screen.elements.reversed().filter { !$0.hidden && $0.frame.contains(p) }
        guard !hits.isEmpty else { selectedID = nil; return }
        if let cur = selectedID, let i = hits.firstIndex(where: { $0.id == cur }) {
            selectedID = hits[(i + 1) % hits.count].id
        } else {
            selectedID = hits[0].id
        }
        panel = .edit
    }

    // MARK: Adding

    func insert(_ els: [Element]) {
        guard !els.isEmpty else { return }
        var placed = els
        let minY = els.map(\.y).min() ?? 0
        let groupH = (els.map { $0.y + $0.h }.max() ?? 0) - minY
        let single = els.count == 1 ? els[0].kind : nil
        let W = width
        let anchor = nextY()
        editScreen { s in
            let H = s.height ?? self.project.device.height
            var dy: Double
            switch single {
            case .tabBar?:
                dy = H - groupH - minY
            case .navBar?:
                dy = (s.showStatusBar ? 54 : 0) - minY
            case .fab?:
                let hasTab = s.elements.contains { $0.kind == .tabBar }
                dy = H - (hasTab ? 83 : 34) - 16 - groupH - minY
                placed[0].x = W - 16 - placed[0].w
            default:
                dy = anchor - minY
                let bottom = anchor + groupH
                if bottom > H - 100 {
                    let grow = bottom - (H - 100)
                    for j in s.elements.indices where s.elements[j].y >= H - 140 { s.elements[j].y += grow }
                    s.height = H + grow
                }
            }
            for j in placed.indices {
                placed[j].y += dy
                placed[j].id = UUID().uuidString
            }
            // Bars go on top of everything else.
            s.elements += placed
        }
        selectedID = placed.first?.id
    }

    private func nextY() -> Double {
        let s = screen
        let H = screenHeight
        if let sel = selected, sel.kind != .tabBar, sel.kind != .fab, sel.h < H * 0.7 { return sel.y + sel.h + 12 }
        let flow = s.elements.filter { $0.kind != .tabBar && $0.kind != .fab && $0.h < H * 0.7 && $0.y < H - 120 && !$0.hidden }
        let bottom = flow.map { $0.y + $0.h }.max() ?? (s.showStatusBar ? 54 : 0)
        return bottom + 16
    }

    // MARK: Element operations

    func duplicate(_ id: String) {
        guard let e = screen.elements.first(where: { $0.id == id }) else { return }
        var c = e
        c.id = UUID().uuidString
        c.y += 12; c.x += 12
        editScreen { s in
            let i = s.elements.firstIndex(where: { $0.id == id }) ?? s.elements.count - 1
            s.elements.insert(c, at: i + 1)
        }
        selectedID = c.id
    }

    func delete(_ id: String) {
        editScreen { s in s.elements.removeAll { $0.id == id } }
        if selectedID == id { selectedID = nil }
    }

    func reorder(_ id: String, _ move: LayerMove) {
        editScreen { s in
            guard let i = s.elements.firstIndex(where: { $0.id == id }) else { return }
            let e = s.elements.remove(at: i)
            switch move {
            case .front: s.elements.append(e)
            case .back: s.elements.insert(e, at: 0)
            case .forward: s.elements.insert(e, at: min(i + 1, s.elements.count))
            case .backward: s.elements.insert(e, at: max(i - 1, 0))
            }
        }
    }

    /// Layers are shown front-most first, so offsets are reversed.
    func moveLayers(from: IndexSet, to: Int) {
        editScreen { s in
            var rev = Array(s.elements.reversed())
            rev.move(fromOffsets: from, toOffset: to)
            s.elements = Array(rev.reversed())
        }
    }

    // MARK: Screens

    func addScreen() {
        var s = Screen()
        s.name = "Screen \(project.screens.count + 1)"
        var nav = Element.make(.navBar, width: width)
        nav.text = s.name; nav.y = 54
        s.elements = [nav]
        if var tab = screen.elements.first(where: { $0.kind == .tabBar }) {
            tab.id = UUID().uuidString
            tab.y = project.device.height - tab.h
            s.elements.append(tab)
        }
        edit { $0.screens.append(s) }
        screenIndex = project.screens.count - 1
        selectedID = nil
    }

    func duplicateScreen() {
        var s = screen
        s.id = UUID().uuidString
        s.name += " copy"
        for i in s.elements.indices { s.elements[i].id = UUID().uuidString }
        let at = screenIndex + 1
        edit { $0.screens.insert(s, at: at) }
        screenIndex = at
        selectedID = nil
    }

    func deleteScreens(at offsets: IndexSet) {
        guard project.screens.count - offsets.count >= 1 else { return }
        edit { $0.screens.remove(atOffsets: offsets) }
        screenIndex = min(screenIndex, project.screens.count - 1)
        selectedID = nil
    }

    func moveScreens(from: IndexSet, to: Int) {
        let currentID = screen.id
        edit { $0.screens.move(fromOffsets: from, toOffset: to) }
        screenIndex = project.screens.firstIndex(where: { $0.id == currentID }) ?? 0
    }

    func appendScreens(_ screens: [Screen]) {
        guard !screens.isEmpty else { return }
        edit { $0.screens += screens }
        screenIndex = project.screens.count - screens.count
        selectedID = nil
    }

    func replaceContent(with p: Project) {
        let keepID = project.id
        edit { cur in
            cur = p
            cur.id = keepID
        }
        screenIndex = 0
        selectedID = nil
    }

    // MARK: Snapping

    func snapped(_ r: CGRect, excluding id: String, threshold: Double) -> (CGRect, [Guide]) {
        let W = width, H = screenHeight
        var xs: [Double] = [0, 16, 20, W / 2, W - 16, W - 20, W]
        var ys: [Double] = [0, 54, H / 2, H]
        for o in screen.elements where o.id != id && !o.hidden {
            xs += [o.x, o.x + o.w / 2, o.x + o.w]
            ys += [o.y, o.y + o.h / 2, o.y + o.h]
        }
        var out = r
        var guides: [Guide] = []
        let vx = [Double(r.minX), Double(r.midX), Double(r.maxX)]
        let vy = [Double(r.minY), Double(r.midY), Double(r.maxY)]
        if let m = best(vx, xs, threshold) {
            out.origin.x += CGFloat(m.0)
            guides.append(Guide(vertical: true, pos: m.1))
        }
        if let m = best(vy, ys, threshold) {
            out.origin.y += CGFloat(m.0)
            guides.append(Guide(vertical: false, pos: m.1))
        }
        return (out, guides)
    }

    private func best(_ vals: [Double], _ cands: [Double], _ t: Double) -> (Double, Double)? {
        var bestD = Double.infinity
        var res: (Double, Double)?
        for v in vals {
            for c in cands {
                let d = c - v
                if abs(d) <= t && abs(d) < abs(bestD) { bestD = d; res = (d, c) }
            }
        }
        return res
    }
}
