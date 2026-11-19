import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Import

enum ImportTarget {
    case newProject
    case editor(EditorStore)
}

struct ImportSheet: View {
    let target: ImportTarget
    var onCreated: ((Project) -> Void)? = nil

    @Environment(Library.self) private var library
    @Environment(\.dismiss) private var dismiss
    @State private var found: Project?
    @State private var errorText: String?
    @State private var promptCopied = false
    @State private var showFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var readText = true
    @State private var readShapes = true
    @State private var keepTrace = true
    @State private var busy = false

    private var isEditor: Bool { if case .editor = target { return true } else { return false } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        UIPasteboard.general.string = Interchange.importPrompt
                        promptCopied = true
                    } label: {
                        Label(promptCopied ? "Prompt copied" : "Copy prompt for your app's thread", systemImage: promptCopied ? "checkmark" : "doc.on.doc")
                    }
                } header: {
                    Text("1 · Ask the thread that builds your app")
                } footer: {
                    Text("Paste the prompt into that Claude thread. It reads your app's code and replies with every screen as AppSculptor JSON. Copy its reply, then come back here.")
                }

                Section {
                    Button { pasteFromClipboard() } label: { Label("Paste Claude's reply", systemImage: "doc.on.clipboard") }
                    Button { showFiles = true } label: { Label("Open a .json file", systemImage: "folder") }
                    if let p = found {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.name).font(.headline)
                            Text("\(p.screens.count) screen\(p.screens.count == 1 ? "" : "s") · \(p.screens.reduce(0) { $0 + $1.elements.count }) elements")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        if isEditor {
                            Button { apply(p, replace: false) } label: { Label("Add these screens", systemImage: "plus.rectangle.on.rectangle") }
                            Button(role: .destructive) { apply(p, replace: true) } label: { Label("Replace this project", systemImage: "arrow.triangle.2.circlepath") }
                        } else {
                            Button { apply(p, replace: false) } label: { Label("Open as a new project", systemImage: "arrow.right.circle.fill") }
                        }
                    }
                    if let errorText {
                        Text(errorText).font(.footnote).foregroundStyle(Color.red)
                    }
                } header: {
                    Text("2 · Bring it in")
                }

                Section {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 20, matching: .images) {
                        Label("Choose screenshots", systemImage: "photo.on.rectangle.angled")
                    }
                    Toggle("Turn text into editable text", isOn: $readText)
                    Toggle("Turn boxes into editable shapes", isOn: $readShapes)
                    Toggle("Keep screenshot as a tracing layer", isOn: $keepTrace)
                    if busy { HStack { ProgressView(); Text("Reading screenshots…").foregroundStyle(.secondary) } }
                } header: {
                    Text("Or start from screenshots")
                } footer: {
                    Text("Works with any app, including builds you've sideloaded. Text and shapes are read on this device; nothing is uploaded.")
                }

                Section {
                    Text("An .ipa holds your app compiled to machine code, so the screens can't be read back out of it. The thread that builds your app has the source, which describes the real layout, text and colors — that's what the prompt above uses.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Why not import the .ipa?")
                }
            }
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.json, .plainText, .text]) { result in
                guard case .success(let url) = result else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url), let s = String(data: data, encoding: .utf8) { read(s) }
                else { errorText = "That file couldn't be opened." }
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await importPhotos(items) }
            }
        }
    }

    private func pasteFromClipboard() {
        guard let s = UIPasteboard.general.string, !s.isEmpty else {
            errorText = "The clipboard is empty. In your app's thread, copy Claude's reply first."
            found = nil
            return
        }
        read(s)
    }

    private func read(_ s: String) {
        do {
            found = try Interchange.parse(s)
            errorText = nil
        } catch {
            found = nil
            errorText = error.localizedDescription
        }
    }

    private func apply(_ p: Project, replace: Bool) {
        switch target {
        case .newProject:
            let saved = library.add(p)
            dismiss()
            onCreated?(saved)
        case .editor(let store):
            let fresh = p.withFreshIDs()
            if replace { store.replaceContent(with: fresh) } else { store.appendScreens(fresh.screens) }
            dismiss()
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        busy = true
        let device: DeviceSize
        if case .editor(let store) = target { device = store.project.device } else { device = DeviceSize() }
        var screens: [Screen] = []
        for (n, item) in items.enumerated() {
            guard let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) else { continue }
            let s = await ScreenshotReader.screen(from: img, name: "Screenshot \(n + 1)", device: device,
                                                  readText: readText, readShapes: readShapes, keepTrace: keepTrace)
            screens.append(s)
        }
        busy = false
        photoItems = []
        guard !screens.isEmpty else { errorText = "Those images couldn't be read."; return }
        switch target {
        case .newProject:
            var p = Project()
            p.name = "Imported screenshots"
            p.device = device
            p.screens = screens
            library.save(p)
            dismiss()
            onCreated?(p)
        case .editor(let store):
            store.appendScreens(screens)
            dismiss()
        }
    }
}

// MARK: - Export

struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct ExportSheet: View {
    let project: Project
    let screenIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var share: ShareItem?
    @State private var toast: String?

    private var slug: String {
        let base = project.name.replacingOccurrences(of: "(example)", with: "").lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        return (base.isEmpty ? "app" : base) + "-mockup"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Group {
                        if let image {
                            Image(uiImage: image).resizable().scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        } else {
                            ProgressView().frame(maxWidth: .infinity, minHeight: 180)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 8) {
                        step(1, "Share the image", "Save it to Photos or Files, or share it straight into the Claude app.")
                        step(2, "Copy the brief + layout", "A written description of every screen, plus exact JSON.")
                        step(3, "In your app's thread", "Attach the image and paste. Claude applies the changes.")
                    }

                    VStack(spacing: 10) {
                        Button { shareBoard(only: nil) } label: { big("Share image", "photo") }
                            .buttonStyle(.borderedProminent)
                        Button { copy(Exporter.handoff(project), "Brief + layout copied") } label: { big("Copy brief + layout", "doc.on.doc") }
                            .buttonStyle(.borderedProminent)
                        HStack(spacing: 10) {
                            Button { shareBoard(only: screenIndex) } label: { small("This screen only") }
                            Button { copy(Exporter.brief(project), "Brief copied") } label: { small("Brief only") }
                        }
                        .buttonStyle(.bordered)
                        HStack(spacing: 10) {
                            Button { shareFiles() } label: { small("Share as files") }
                            Button { copy(Interchange.json(project), "JSON copied") } label: { small("JSON only") }
                        }
                        .buttonStyle(.bordered)
                    }

                    if let toast {
                        Label(toast, systemImage: "checkmark.circle.fill").foregroundStyle(Color.green).font(.subheadline.weight(.semibold))
                    }
                }
                .padding()
            }
            .navigationTitle("Send to Claude")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .task { image = Exporter.board(project) }
            .sheet(item: $share) { ShareSheet(items: $0.items).ignoresSafeArea() }
        }
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(Color.white)
                .frame(width: 22, height: 22).background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func big(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
    }

    private func small(_ title: String) -> some View {
        Text(title).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity)
    }

    private func copy(_ text: String, _ message: String) {
        UIPasteboard.general.string = text
        withAnimation { toast = message }
    }

    private func write(_ data: Data?, _ name: String) -> URL? {
        guard let data else { return nil }
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do { try data.write(to: url, options: .atomic); return url } catch { return nil }
    }

    private func shareBoard(only: Int?) {
        let img = only == nil ? (image ?? Exporter.board(project)) : Exporter.board(project, only: only)
        let name = only == nil ? "\(slug).png" : "\(slug)-\((only ?? 0) + 1).png"
        if let url = write(img?.pngData(), name) { share = ShareItem(items: [url]) }
    }

    private func shareFiles() {
        var items: [Any] = []
        if let u = write((image ?? Exporter.board(project))?.pngData(), "\(slug).png") { items.append(u) }
        if let u = write(Exporter.brief(project).data(using: .utf8), "\(slug).md") { items.append(u) }
        if let u = write(Interchange.json(project).data(using: .utf8), "\(slug).appsculptor.json") { items.append(u) }
        if !items.isEmpty { share = ShareItem(items: items) }
    }
}

// MARK: - Project list

struct ProjectListView: View {
    @Environment(Library.self) private var library
    @State private var path: [String] = []
    @State private var showImport = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(library.projects) { p in
                        NavigationLink(value: p.id) { ProjectRow(project: p) }
                            .contextMenu {
                                Button { library.duplicate(p.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button(role: .destructive) { library.delete(p.id) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { library.projects[$0].id }
                        ids.forEach { library.delete($0) }
                    }
                } footer: {
                    Text("Projects are saved on this device as you work.")
                }
            }
            .navigationTitle("AppSculptor")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { path.append(library.createBlank().id) } label: { Label("Blank project", systemImage: "square.dashed") }
                        Button { showImport = true } label: { Label("Import from Claude or screenshots", systemImage: "square.and.arrow.down") }
                        Button { path.append(library.add(SampleProject.make()).id) } label: { Label("Example project", systemImage: "sparkles") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .overlay {
                if library.projects.isEmpty {
                    ContentUnavailableView("No projects", systemImage: "rectangle.on.rectangle.angled",
                                           description: Text("Tap + to start one, or import your app's screens from Claude."))
                }
            }
            .navigationDestination(for: String.self) { id in
                if let p = library.project(id) {
                    EditorView(project: p, library: library)
                } else {
                    ContentUnavailableView("Project not found", systemImage: "questionmark.folder")
                }
            }
            .sheet(isPresented: $showImport) {
                ImportSheet(target: .newProject) { p in path.append(p.id) }
            }
        }
    }
}

struct ProjectRow: View {
    let project: Project
    var body: some View {
        HStack(spacing: 14) {
            if let s = project.screens.first {
                let scale = 64.0 / project.device.height
                ScreenCanvas(screen: s, project: project, showTrace: true, showNotes: false)
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: project.device.width * scale, height: 64, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.secondary.opacity(0.3)))
                    .allowsHitTesting(false)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name).font(.headline)
                Text("\(project.screens.count) screen\(project.screens.count == 1 ? "" : "s") · \(project.device.name)")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text(Date(timeIntervalSince1970: project.updatedAt), style: .relative)
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - App

@main
struct AppSculptorApp: App {
    @State private var library = Library()

    var body: some Scene {
        WindowGroup {
            ProjectListView()
                .environment(library)
                .onOpenURL { url in library.importFile(url) }
        }
    }
}
