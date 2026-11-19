import SwiftUI
import PhotosUI

struct InspectorPanel: View {
    @Bindable var store: EditorStore
    var body: some View {
        if let id = store.selectedID, store.selected != nil {
            ElementInspector(store: store, e: store.binding(id), theme: store.project.theme)
                .id(id)
        } else {
            ContentUnavailableView("Nothing selected", systemImage: "hand.tap",
                                   description: Text("Tap something on the screen to edit it, or add a component from the Add tab."))
        }
    }
}

/// Which content fields each kind uses, and what to call them.
struct FieldSpec {
    var text: String? = nil
    var subtitle: String? = nil
    var placeholder: String? = nil
    var items: String? = nil
    var selected: String? = nil
    var value: String? = nil
    var isOn: String? = nil
    var count: String? = nil
    var symbol: String? = nil
    var image = false
    var tint = false
    var textStyle = false

    static func of(_ k: ElementKind) -> FieldSpec {
        switch k {
        case .rectangle, .ellipse, .divider: return FieldSpec()
        case .text: return FieldSpec(text: "Text", textStyle: true)
        case .button: return FieldSpec(text: "Label", symbol: "Icon", textStyle: true)
        case .textField: return FieldSpec(text: "Typed value", placeholder: "Placeholder", symbol: "Leading icon", textStyle: true)
        case .searchBar: return FieldSpec(text: "Typed value", placeholder: "Placeholder", symbol: "Icon", textStyle: true)
        case .image: return FieldSpec(text: "What it shows", symbol: "Placeholder icon", image: true)
        case .icon: return FieldSpec(symbol: "Symbol", textStyle: true)
        case .toggle: return FieldSpec(text: "Label", isOn: "Switched on", tint: true, textStyle: true)
        case .slider: return FieldSpec(value: "Value", tint: true)
        case .segmented: return FieldSpec(items: "Segments (one per line)", selected: "Selected", tint: true, textStyle: true)
        case .checkbox, .radio: return FieldSpec(text: "Label", isOn: "Checked", tint: true, textStyle: true)
        case .progress: return FieldSpec(text: "Label", value: "Value", tint: true, textStyle: true)
        case .stepper: return FieldSpec(text: "Label", textStyle: true)
        case .avatar: return FieldSpec(text: "Name (for initials)", image: true)
        case .badge: return FieldSpec(text: "Text", textStyle: true)
        case .chip: return FieldSpec(text: "Label", isOn: "Selected", symbol: "Icon", tint: true, textStyle: true)
        case .navBar: return FieldSpec(text: "Title", placeholder: "Back-button text", items: "Right-side icons (SF Symbol names, one per line)", isOn: "Large title", symbol: "Left icon", tint: true, textStyle: true)
        case .tabBar: return FieldSpec(items: "Tabs — one per line, optionally Label|sf.symbol", selected: "Selected tab", tint: true)
        case .listRow: return FieldSpec(text: "Title", subtitle: "Subtitle", placeholder: "Value on the right", isOn: "Chevron", symbol: "Icon", tint: true, textStyle: true)
        case .map: return FieldSpec(symbol: "Pin icon", tint: true)
        case .chart: return FieldSpec(items: "Bar values (numbers, one per line)", selected: "Highlighted bar", tint: true)
        case .video: return FieldSpec(symbol: "Overlay icon")
        case .pageDots: return FieldSpec(selected: "Current page", count: "Pages", tint: true)
        case .fab: return FieldSpec(symbol: "Icon", textStyle: true)
        }
    }

    var hasContent: Bool {
        text != nil || subtitle != nil || placeholder != nil || items != nil || selected != nil || value != nil
            || isOn != nil || count != nil || symbol != nil || image || tint
    }
}

struct ElementInspector: View {
    let store: EditorStore
    @Binding var e: Element
    let theme: Theme
    @State private var showSymbols = false
    @State private var photoItem: PhotosPickerItem?

    private var spec: FieldSpec { FieldSpec.of(e.kind) }

    var body: some View {
        Form {
            headerSection
            if spec.hasContent { contentSection }
            if spec.textStyle { textSection }
            styleSection
            shadowSection
            layoutSection
            Section {
                TextField("Behavior, data, anything the picture can't show", text: $e.note, axis: .vertical)
                    .lineLimit(2...8)
            } header: {
                Label("Note for Claude", systemImage: "note.text").foregroundStyle(Color.pink)
            } footer: {
                Text("Appears as a numbered pink marker in the exported image and brief.")
            }
        }
        .sheet(isPresented: $showSymbols) {
            SymbolPicker(selection: Binding(get: { e.symbol ?? "" }, set: { e.symbol = $0.isEmpty ? nil : $0 }))
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                    e.imageData = ui.downscaled(maxSide: 1200).jpegData(compressionQuality: 0.8)
                }
                photoItem = nil
            }
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        Section {
            HStack(spacing: 18) {
                iconButton("plus.square.on.square", "Duplicate") { store.duplicate(e.id) }
                iconButton("arrow.up.to.line", "Bring to front") { store.reorder(e.id, .front) }
                iconButton("arrow.up", "Bring forward") { store.reorder(e.id, .forward) }
                iconButton("arrow.down", "Send backward") { store.reorder(e.id, .backward) }
                iconButton("arrow.down.to.line", "Send to back") { store.reorder(e.id, .back) }
                Spacer()
                iconButton("trash", "Delete", tint: .red) { store.delete(e.id) }
            }
            Picker("Type", selection: $e.kind) {
                ForEach(ElementKind.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
            }
            TextField("Layer name (optional)", text: $e.name)
            Toggle("Locked", isOn: $e.locked)
            Toggle("Hidden", isOn: $e.hidden)
        } header: {
            Text(e.kind.label)
        }
    }

    private var contentSection: some View {
        let s = spec
        return Section("Content") {
            if let l = s.text { TextField(l, text: $e.text, axis: .vertical).lineLimit(1...6) }
            if let l = s.subtitle { TextField(l, text: $e.subtitle) }
            if let l = s.placeholder { TextField(l, text: $e.placeholder) }
            if let l = s.items {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l).font(.caption).foregroundStyle(.secondary)
                    TextField(l, text: Binding(get: { e.items.joined(separator: "\n") },
                                               set: { e.items = $0.components(separatedBy: "\n") }), axis: .vertical)
                        .lineLimit(2...10)
                        .textInputAutocapitalization(e.kind == .navBar ? .never : .sentences)
                        .autocorrectionDisabled(e.kind == .navBar || e.kind == .chart)
                }
            }
            if let l = s.selected {
                let n = max(e.items.count, e.count, 1)
                Stepper("\(l): \(e.selectedIndex + 1)", value: $e.selectedIndex, in: 0...max(0, n - 1))
            }
            if let l = s.count { Stepper("\(l): \(e.count)", value: $e.count, in: 1...12) }
            if let l = s.value { SliderRow(title: l, value: $e.value, range: 0...1, step: 0.01, format: "%.2f") }
            if let l = s.isOn { Toggle(l, isOn: $e.isOn) }
            if let l = s.symbol {
                Button { showSymbols = true } label: {
                    HStack {
                        Text(l).foregroundStyle(Color.primary)
                        Spacer()
                        if let sym = e.symbol, !sym.isEmpty {
                            Image(systemName: sym)
                            Text(sym).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        } else {
                            Text("None").foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            if s.image {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label(e.imageData == nil ? "Use a photo" : "Replace photo", systemImage: "photo")
                }
                if e.imageData != nil {
                    Button("Remove photo", role: .destructive) { e.imageData = nil }
                }
            }
            if s.tint {
                OptionalColorRow(title: "Highlight color", hex: $e.tint, fallback: theme.accent, allowNone: false, defaultLabel: "Accent")
            }
        }
    }

    private var textSection: some View {
        Section("Text") {
            SliderRow(title: "Size", value: $e.fontSize, range: 6...120)
            Picker("Weight", selection: $e.fontWeight) {
                ForEach(WeightName.allCases) { Text($0.label).tag($0) }
            }
            Picker("Design", selection: $e.fontDesign) {
                Text("Theme").tag(DesignName?.none)
                ForEach(DesignName.allCases) { Text($0.label).tag(DesignName?.some($0)) }
            }
            Picker("Font", selection: Binding(get: { e.fontFamily ?? "" }, set: { e.fontFamily = $0.isEmpty ? nil : $0 })) {
                Text("Theme").tag("")
                ForEach(FontList.families, id: \.self) { Text($0).tag($0) }
            }
            Toggle("Italic", isOn: $e.italic)
            Picker("Alignment", selection: $e.align) {
                ForEach(AlignName.allCases) { Image(systemName: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)
            OptionalColorRow(title: e.kind == .icon || e.kind == .fab ? "Icon color" : "Text color", hex: $e.textColor,
                             fallback: defaultTextColor, allowNone: false)
            SliderRow(title: "Letter spacing", value: $e.letterSpacing, range: -3...12, step: 0.1, format: "%.1f")
            SliderRow(title: "Line spacing", value: $e.lineSpacing, range: 0...24)
        }
    }

    private var defaultTextColor: String {
        switch e.kind {
        case .button, .fab: return theme.onAccent
        case .icon: return theme.accent
        case .badge: return "#FFFFFF"
        default: return theme.text
        }
    }

    private var defaultFill: String {
        switch e.kind {
        case .button, .fab: return theme.accent
        case .badge: return "#E5484D"
        case .rectangle, .ellipse, .textField, .searchBar, .segmented, .chip, .avatar, .image: return theme.surface
        case .navBar, .tabBar: return theme.background
        case .divider: return theme.border
        default: return theme.background
        }
    }

    private var styleSection: some View {
        Section("Fill, border & corners") {
            OptionalColorRow(title: "Fill", hex: $e.fill, fallback: defaultFill)
            OptionalColorRow(title: "Gradient to", hex: $e.gradientTo, fallback: e.fill ?? defaultFill, allowNone: false, defaultLabel: "Off")
            OptionalColorRow(title: "Border", hex: $e.stroke, fallback: theme.border)
            SliderRow(title: "Border width", value: optional(\.strokeWidth, 0), range: 0...16, step: 0.5, format: "%.1f")
            SliderRow(title: "Corner radius", value: optional(\.cornerRadius, theme.cornerRadius), range: 0...max(200, e.h / 2))
            SliderRow(title: "Opacity", value: $e.opacity, range: 0...1, step: 0.01, format: "%.2f")
        }
    }

    private var shadowSection: some View {
        Section("Shadow") {
            SliderRow(title: "Blur", value: $e.shadowRadius, range: 0...50)
            SliderRow(title: "Offset Y", value: $e.shadowY, range: -20...40)
            SliderRow(title: "Strength", value: $e.shadowOpacity, range: 0...1, step: 0.01, format: "%.2f")
            OptionalColorRow(title: "Shadow color", hex: $e.shadowColor, fallback: "#000000", allowNone: false)
        }
    }

    private var layoutSection: some View {
        Section("Position & size") {
            HStack(spacing: 12) { NumberField(title: "X", value: $e.x); NumberField(title: "Y", value: $e.y) }
            HStack(spacing: 12) { NumberField(title: "W", value: $e.w); NumberField(title: "H", value: $e.h) }
            SliderRow(title: "Rotation", value: $e.rotation, range: -180...180, format: "%.0f°")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    quick("Center") { e.x = ((store.width - e.w) / 2).rounded() }
                    quick("Full width") { e.x = 16; e.w = store.width - 32 }
                    quick("Edge to edge") { e.x = 0; e.w = store.width }
                    quick("Left 16") { e.x = 16 }
                    quick("Right 16") { e.x = store.width - 16 - e.w }
                    quick("Square") { e.h = e.w }
                }
            }
        }
    }

    // MARK: Helpers

    private func optional(_ kp: WritableKeyPath<Element, Double?>, _ def: Double) -> Binding<Double> {
        Binding(get: { e[keyPath: kp] ?? def }, set: { e[keyPath: kp] = $0 })
    }

    private func iconButton(_ symbol: String, _ label: String, tint: Color = .accentColor, _ action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol).foregroundStyle(tint) }
            .buttonStyle(.borderless)
            .accessibilityLabel(label)
    }

    private func quick(_ title: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.caption.weight(.medium))
            .buttonStyle(.bordered)
            .controlSize(.small)
    }
}

// MARK: - Reusable rows

struct SliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    var format = "%.0f"

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: format, value)).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}

struct NumberField: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        HStack(spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).frame(width: 16, alignment: .leading)
            TextField(title, value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct OptionalColorRow: View {
    let title: String
    @Binding var hex: String?
    let fallback: String
    var allowNone = true
    var defaultLabel = "Default"

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Menu {
                Button(defaultLabel) { hex = nil }
                if allowNone { Button("None (transparent)") { hex = "none" } }
                Button("Copy hex") { UIPasteboard.general.string = hex ?? fallback }
                Button("Paste hex") {
                    if let s = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), s.hasPrefix("#") { hex = s }
                }
            } label: {
                Text(labelText).font(.caption.monospaced())
            }
            ColorPicker(title, selection: Binding(
                get: { Color(hex: (hex == nil || hex == "none") ? fallback : (hex ?? fallback)) },
                set: { hex = $0.hexString }
            ), supportsOpacity: true)
            .labelsHidden()
        }
    }

    private var labelText: String {
        guard let h = hex else { return defaultLabel }
        return h == "none" ? "None" : h.uppercased()
    }
}

struct ColorRow: View {
    let title: String
    @Binding var hex: String
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(hex.uppercased()).font(.caption.monospaced()).foregroundStyle(.secondary)
            ColorPicker(title, selection: Binding(get: { Color(hex: hex) }, set: { hex = $0.hexString }), supportsOpacity: false)
                .labelsHidden()
        }
    }
}

// MARK: - SF Symbol picker

struct SymbolPicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var cleaned: String { query.trimmingCharacters(in: .whitespaces).lowercased() }
    private var filtered: [String] { cleaned.isEmpty ? Symbols.all : Symbols.all.filter { $0.contains(cleaned) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                if !cleaned.isEmpty, UIImage(systemName: cleaned) != nil, !Symbols.all.contains(cleaned) {
                    Button { selection = cleaned; dismiss() } label: {
                        Label("Use “\(cleaned)”", systemImage: cleaned).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding([.horizontal, .top])
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 10)], spacing: 10) {
                    ForEach(filtered, id: \.self) { name in
                        Button { selection = name; dismiss() } label: {
                            Image(systemName: name)
                                .font(.system(size: 22))
                                .frame(width: 58, height: 58)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(name == selection ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                    }
                }
                .padding()
                Text("Any SF Symbol works — type its exact name (e.g. figure.yoga) to use one that isn't listed.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal).padding(.bottom)
            }
            .searchable(text: $query, prompt: "Search or type any SF Symbol name")
            .textInputAutocapitalization(.never)
            .navigationTitle("Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("No icon") { selection = ""; dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let s = maxSide / longest
        let target = CGSize(width: (size.width * s).rounded(), height: (size.height * s).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
    }
}
