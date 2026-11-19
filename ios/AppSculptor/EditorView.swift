import SwiftUI

struct EditorView: View {
    @State private var store: EditorStore
    @Environment(\.horizontalSizeClass) private var hsc
    @State private var showExport = false
    @State private var showImport = false
    @State private var panelOpen = true

    init(project: Project, library: Library) {
        _store = State(initialValue: EditorStore(project: project, library: library))
    }

    var body: some View {
        Group {
            if hsc == .regular {
                HStack(spacing: 0) {
                    VStack(spacing: 0) { ScreenStrip(store: store); CanvasArea(store: store) }
                    Divider()
                    panel.frame(width: 380)
                }
            } else {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        ScreenStrip(store: store)
                        CanvasArea(store: store)
                        panel.frame(height: panelOpen ? max(260, geo.size.height * 0.46) : 52)
                    }
                }
            }
        }
        .navigationTitle(store.project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showImport = true } label: { Image(systemName: "square.and.arrow.down") }
                    .accessibilityLabel("Import")
                Button { store.saveNow(); showExport = true } label: { Text("Send to Claude").fontWeight(.semibold) }
            }
        }
        .sheet(isPresented: $showExport) { ExportSheet(project: store.project, screenIndex: store.screenIndex) }
        .sheet(isPresented: $showImport) { ImportSheet(target: .editor(store)) }
        .onDisappear { store.saveNow() }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Panel", selection: $store.panel) {
                    ForEach(Panel.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: store.panel) { _, _ in panelOpen = true }
                if hsc != .regular {
                    Button { withAnimation(.snappy) { panelOpen.toggle() } } label: {
                        Image(systemName: panelOpen ? "chevron.down" : "chevron.up").frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            Divider()
            if panelOpen || hsc == .regular {
                Group {
                    switch store.panel {
                    case .add: AddPanel(store: store)
                    case .edit: InspectorPanel(store: store)
                    case .layers: LayersPanel(store: store)
                    case .screen: ScreenPanel(store: store)
                    case .style: StylePanel(store: store)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .background(Color(.systemBackground))
    }
}

struct ScreenStrip: View {
    @Bindable var store: EditorStore
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(store.project.screens.enumerated()), id: \.element.id) { i, s in
                    Button {
                        if store.screenIndex == i { store.panel = .screen } else { store.screenIndex = i; store.selectedID = nil }
                    } label: {
                        Text("\(i + 1). \(s.name)")
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Capsule().fill(i == store.screenIndex ? Color.primary : Color(.tertiarySystemFill)))
                            .foregroundStyle(i == store.screenIndex ? Color(.systemBackground) : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Button { store.addScreen() } label: {
                    Label("Screen", systemImage: "plus").font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .overlay(Capsule().strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Add

struct AddPanel: View {
    let store: EditorStore
    private let cols = [GridItem(.adaptive(minimum: 78), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                section("Quick styles") {
                    ForEach(Template.quick) { t in tile(t.title, t.symbol) { store.insert(t.build(store.width, store.project.theme)) } }
                }
                ForEach(ElementKind.groups, id: \.0) { group in
                    section(group.0) {
                        ForEach(group.1) { k in tile(k.label, k.symbol) { store.insert([Element.make(k, width: store.width)]) } }
                    }
                }
                section("Sections") {
                    ForEach(Template.sections) { t in tile(t.title, t.symbol) { store.insert(t.build(store.width, store.project.theme)) } }
                }
                Text("New items go under the selected one. Nav bars, tab bars and floating buttons snap to their usual spots. Everything can be moved and restyled afterwards.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            LazyVGrid(columns: cols, spacing: 8) { content() }
        }
    }

    private func tile(_ title: String, _ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 20)).frame(height: 24)
                Text(title).font(.caption).lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 66)
            .padding(.horizontal, 4)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Layers

struct LayersPanel: View {
    @Bindable var store: EditorStore

    var body: some View {
        let els = Array(store.screen.elements.reversed())
        if els.isEmpty {
            ContentUnavailableView("No layers yet", systemImage: "square.3.layers.3d", description: Text("Add components from the Add tab."))
        } else {
            List {
                Section {
                    ForEach(els) { e in row(e) }
                        .onMove { from, to in store.moveLayers(from: from, to: to) }
                } footer: {
                    Text("Top of the list is in front. Long-press and drag to reorder.")
                }
            }
            .listStyle(.plain)
        }
    }

    private func row(_ e: Element) -> some View {
        HStack(spacing: 10) {
            Image(systemName: e.kind.symbol).frame(width: 22).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(e.displayName).lineLimit(1)
                Text(e.kind.label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if !e.note.isEmpty { Image(systemName: "note.text").foregroundStyle(Color.pink) }
            Button { store.editElement(e.id, coalesce: false) { $0.locked.toggle() } } label: {
                Image(systemName: e.locked ? "lock.fill" : "lock.open").foregroundStyle(e.locked ? Color.orange : Color.secondary)
            }
            .buttonStyle(.borderless)
            Button { store.editElement(e.id, coalesce: false) { $0.hidden.toggle() } } label: {
                Image(systemName: e.hidden ? "eye.slash" : "eye").foregroundStyle(Color.secondary)
            }
            .buttonStyle(.borderless)
        }
        .opacity(e.hidden ? 0.5 : 1)
        .contentShape(Rectangle())
        .listRowBackground(e.id == store.selectedID ? Color.accentColor.opacity(0.15) : Color.clear)
        .onTapGesture { store.selectedID = e.id; store.panel = .edit }
        .swipeActions {
            Button(role: .destructive) { store.delete(e.id) } label: { Label("Delete", systemImage: "trash") }
            Button { store.duplicate(e.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }.tint(.blue)
        }
    }
}

// MARK: - Screen

struct ScreenPanel: View {
    @Bindable var store: EditorStore

    var body: some View {
        let s = store.screenBinding
        Form {
            Section("This screen") {
                TextField("Name", text: s.name)
                TextField("What this screen is for", text: s.notes, axis: .vertical).lineLimit(2...6)
                OptionalColorRow(title: "Background", hex: s.background, fallback: store.project.theme.background, allowNone: false, defaultLabel: "Theme")
                Toggle("Status bar", isOn: s.showStatusBar)
                Toggle("Light status bar & home bar", isOn: s.statusBarLight)
                Toggle("Home indicator", isOn: s.showHomeIndicator)
                HStack {
                    Text("Height")
                    Spacer()
                    TextField("Height", value: Binding(get: { store.screenHeight }, set: { v in store.editScreen(coalesce: true) { $0.height = max(200, v) } }), format: .number)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                    if store.screen.height != nil {
                        Button("Reset") { store.editScreen { $0.height = nil } }.buttonStyle(.borderless)
                    }
                }
            }
            if store.screen.traceImage != nil {
                Section {
                    Toggle("Show screenshot", isOn: s.showTrace)
                    SliderRow(title: "Opacity", value: s.traceOpacity, range: 0...1, step: 0.05, format: "%.2f")
                    Button("Remove screenshot", role: .destructive) { store.editScreen { $0.traceImage = nil } }
                } header: { Text("Screenshot reference") } footer: { Text("Shown behind your layers while editing. Never included in exports.") }
            }
            Section {
                ForEach(Array(store.project.screens.enumerated()), id: \.element.id) { i, sc in
                    Button {
                        store.screenIndex = i; store.selectedID = nil
                    } label: {
                        HStack {
                            Text("\(i + 1). \(sc.name)").foregroundStyle(Color.primary)
                            Spacer()
                            if i == store.screenIndex { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        }
                    }
                }
                .onMove { store.moveScreens(from: $0, to: $1) }
                .onDelete { store.deleteScreens(at: $0) }
                Button { store.addScreen() } label: { Label("Add screen", systemImage: "plus") }
                Button { store.duplicateScreen() } label: { Label("Duplicate this screen", systemImage: "plus.square.on.square") }
            } header: { Text("All screens") } footer: { Text("Swipe to delete, long-press and drag to reorder.") }
        }
    }
}

// MARK: - Style

struct StylePanel: View {
    @Bindable var store: EditorStore

    var body: some View {
        let t = store.themeBinding
        Form {
            Section("App") {
                TextField("App name", text: store.nameBinding)
                Picker("Device", selection: store.deviceBinding) {
                    ForEach(DeviceSize.presets, id: \.self) { d in Text("\(d.name) · \(Int(d.width))×\(Int(d.height))").tag(d) }
                    if !DeviceSize.presets.contains(store.project.device) {
                        Text("Custom · \(Int(store.project.device.width))×\(Int(store.project.device.height))").tag(store.project.device)
                    }
                }
            }
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Theme.presets) { p in
                            Button {
                                store.edit { proj in
                                    let keep = proj.theme
                                    proj.theme = p.theme
                                    proj.theme.cornerRadius = keep.cornerRadius
                                    proj.theme.fontDesign = keep.fontDesign
                                    proj.theme.fontFamily = keep.fontFamily
                                }
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack(alignment: .bottomTrailing) {
                                        RoundedRectangle(cornerRadius: 10).fill(Color(hex: p.theme.background))
                                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color(hex: p.theme.border)))
                                        Circle().fill(Color(hex: p.theme.accent)).frame(width: 18, height: 18).padding(6)
                                        Text("Aa").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: p.theme.text))
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(6)
                                    }
                                    .frame(width: 58, height: 46)
                                    Text(p.name).font(.caption2).foregroundStyle(Color.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: { Text("Palettes") } footer: { Text("Changes every element that uses theme colors. Elements with their own colors keep them.") }
            Section("Colors") {
                ColorRow(title: "Accent", hex: t.accent)
                ColorRow(title: "Text on accent", hex: t.onAccent)
                ColorRow(title: "Background", hex: t.background)
                ColorRow(title: "Surface (cards, fields)", hex: t.surface)
                ColorRow(title: "Text", hex: t.text)
                ColorRow(title: "Secondary text", hex: t.secondaryText)
                ColorRow(title: "Borders & dividers", hex: t.border)
            }
            Section("Shape & type") {
                SliderRow(title: "Default corner radius", value: t.cornerRadius, range: 0...32)
                Picker("Font design", selection: t.fontDesign) {
                    ForEach(DesignName.allCases) { Text($0.label).tag($0) }
                }
                Picker("Font family", selection: Binding(get: { t.wrappedValue.fontFamily ?? "" }, set: { t.wrappedValue.fontFamily = $0.isEmpty ? nil : $0 })) {
                    Text("System").tag("")
                    ForEach(FontList.families, id: \.self) { Text($0).tag($0) }
                }
            }
        }
    }
}

enum FontList {
    static let families: [String] = UIFont.familyNames.sorted()
}
