import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement
import FinderSync
import ApplicationServices

enum SettingsTab: String, CaseIterable, Identifiable {
    case general, contextMenu, permissions, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .about: "About"; case .general: "General"; case .permissions: "Permissions"
        case .contextMenu: "Context Menu"
        }
    }
    var icon: String {
        switch self {
        case .about: "info.circle"; case .general: "gearshape"; case .permissions: "lock.shield"
        case .contextMenu: "contextualmenu.and.cursorarrow"
        }
    }
}

struct SettingsRootView: View {
    @AppStorage("appearance") private var appearance = "System"
    @Binding var language: String
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?
    @State private var extensionEnabled: Bool?
    @State private var automationStatus: [String: OSStatus] = [:]
    @State private var selection: SettingsTab = .general

    private func localized(_ key: String) -> String {
        SharedSettings.localized(key, language: language)
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases) { tab in
                Button { selection = tab } label: {
                    Label(localized(tab.title), systemImage: tab.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(selection == tab ? Color.accentColor.opacity(0.16) : Color.clear)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            Group {
                switch selection {
                case .about: about
                case .general: general
                case .permissions: permissions
                case .contextMenu: ContextMenuSettingsView(language: language)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .navigationTitle(localized(selection.title))
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginStatus = SMAppService.mainApp.status
        }
        // preferredColorScheme(nil) does not fully restore the system appearance after an explicit one.
        .onAppear { Self.apply(appearance) }
        .onChange(of: appearance) { _, value in Self.apply(value) }
        .environment(\.locale, language == "中文" ? Locale(identifier: "zh-Hans") : language == "English" ? Locale(identifier: "en") : .current)
    }

    /// "0.1.0 (abc1234)", or "0.1.0 (abc1234 - dirty)" when built from uncommitted changes.
    private var versionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
        guard let revision = Bundle.main.object(forInfoDictionaryKey: "GitRevision") as? String, !revision.isEmpty else { return version }
        return "\(version) (\(revision))"
    }

    private static func apply(_ appearance: String) {
        NSApp.appearance = switch appearance {
        case "Dark": NSAppearance(named: .darkAqua)
        case "Light": NSAppearance(named: .aqua)
        default: nil
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 88, height: 88)
            Text(localized("RightMouseMenu")).font(.largeTitle.bold())
            Text(String(format: localized("Version %@"), versionDescription)).foregroundStyle(.secondary)
            Text(localized("Powered by Stone Wang")).padding(.top, 8)
            Spacer()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var general: some View {
        Form {
            Section(localized("General")) {
                Toggle(localized("Start at login"), isOn: Binding(
                    get: { loginStatus == .enabled || loginStatus == .requiresApproval },
                    set: { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch { loginError = error.localizedDescription }
                        loginStatus = SMAppService.mainApp.status
                    }
                ))
                if loginStatus == .requiresApproval {
                    Button(localized("Approve in Login Items")) { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError { Text(loginError).foregroundStyle(.red) }
                Picker(localized("Appearance"), selection: $appearance) { Text(localized("System")).tag("System"); Text(localized("Light")).tag("Light"); Text(localized("Dark")).tag("Dark") }
                Picker(localized("Language"), selection: $language) { Text(localized("System")).tag("System"); Text(localized("English")).tag("English"); Text(localized("中文")).tag("中文") }
            }
            Section { Label(localized("RightMouseMenu stays available from the menu bar."), systemImage: "menubar.rectangle").foregroundStyle(.secondary) }
        }.formStyle(.grouped)
    }

    private struct AutomationTarget {
        let bundleID: String
        let name: String
        let purpose: String
    }

    private static let automationTargets = [
        AutomationTarget(bundleID: "com.apple.finder", name: "Finder", purpose: "Used by File Information"),
        AutomationTarget(bundleID: "com.apple.Terminal", name: "Terminal", purpose: "Used by New Terminal here"),
        AutomationTarget(bundleID: "com.googlecode.iterm2", name: "iTerm2", purpose: "Used by New iTerm2 here and New iTerm2 Tab here"),
    ]

    private var installedAutomationTargets: [AutomationTarget] {
        Self.automationTargets.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleID) != nil }
    }

    private var permissions: some View {
        Form {
            Section {
                HStack {
                    if let extensionEnabled {
                        Label(localized(extensionEnabled ? "Enabled" : "Disabled"), systemImage: extensionEnabled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(extensionEnabled ? Color.green : Color.orange)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                    Button(localized("Open Login Items & Extensions")) { FIFinderSyncController.showExtensionManagementInterface() }
                }
            } header: {
                Text(localized("Finder Extension"))
            } footer: {
                Text(localized("Finder extensions are enabled in System Settings → General → Login Items & Extensions → Finder. Enable RightMouseMenu there to show its contextual commands."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(installedAutomationTargets, id: \.bundleID) { target in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.name)
                            Text(localized(target.purpose)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        automationState(for: target)
                    }
                }
                HStack {
                    Spacer()
                    Button(localized("Open Automation Settings")) { openPrivacySettings("Automation") }
                }
            } header: {
                Text(localized("Automation"))
            } footer: {
                Text(localized("macOS asks once for each app. New Terminal Tab here, Tabby, Visual Studio Code and Copy Full Path need no permission."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task {
            while !Task.isCancelled {
                extensionEnabled = await Task.detached { Self.finderExtensionEnabled() }.value
                for target in Self.automationTargets {
                    let id = target.bundleID
                    automationStatus[id] = await Task.detached { MenuActions.automationStatus(id, prompt: false) }.value
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @ViewBuilder
    private func automationState(for target: AutomationTarget) -> some View {
        switch automationStatus[target.bundleID] {
        case .none:
            ProgressView().controlSize(.small)
        case noErr:
            Label(localized("Allowed"), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
        case OSStatus(errAEEventNotPermitted):
            Label(localized("Denied"), systemImage: "xmark.circle.fill").foregroundStyle(.red)
        case OSStatus(procNotFound):
            // macOS can only check or ask while the target app is running.
            Text(localized("Asks on first use")).foregroundStyle(.secondary)
        default:
            Button(localized("Request")) {
                let id = target.bundleID
                Task {
                    automationStatus[id] = await Task.detached { MenuActions.automationStatus(id, prompt: true) }.value
                }
            }
        }
    }

    private func openPrivacySettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private nonisolated static func finderExtensionEnabled() -> Bool {
        // FinderSync can report false for a registered and enabled development build.
        if let bundle = Bundle.main.builtInPlugInsURL?.appending(path: "RightMouseMenuFinderSync.appex"),
           let identifier = Bundle(url: bundle)?.bundleIdentifier {
            let process = Process()
            let output = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = ["-m", "-p", "com.apple.FinderSync", "-i", identifier]
            process.standardOutput = output
            if (try? process.run()) != nil {
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                if process.terminationStatus == 0,
                   let line = String(decoding: data, as: UTF8.self).split(separator: "\n").first {
                    if line.first == "+" { return true }
                    if line.first == "-" || line.first == "!" { return false }
                }
            }
        }
        return FIFinderSyncController.isExtensionEnabled
    }
}

struct ContextMenuSettingsView: View {
    let language: String
    @AppStorage("newFileEnabled", store: SharedSettings.defaults) private var enabled = true
    @AppStorage("newFileIcons", store: SharedSettings.defaults) private var icons = true
    @AppStorage("newFile.custom", store: SharedSettings.defaults) private var customEnabled = true
    @AppStorage("customExtensions", store: SharedSettings.defaults) private var custom = ""
    @AppStorage("newFile.txt", store: SharedSettings.defaults) private var txt = true
    @AppStorage("newFile.md", store: SharedSettings.defaults) private var md = true
    @AppStorage("newFile.word", store: SharedSettings.defaults) private var word = true
    @AppStorage("newFile.excel", store: SharedSettings.defaults) private var excel = true
    @AppStorage("newFile.ppt", store: SharedSettings.defaults) private var ppt = true
    @AppStorage("newFileSubmenu", store: SharedSettings.defaults) private var submenu = false

    @AppStorage(ContextCommand.orderKey, store: SharedSettings.defaults) private var order = ""
    @State private var showsFileTypes = false
    @State private var insertion: CommandInsertion?
    @State private var isDragging = false

    private func insert(_ source: ContextCommand, at target: ContextCommand, after: Bool) {
        var commands = ContextCommand.ordered(order)
        guard source != target else { return }
        commands.removeAll { $0 == source }
        guard let index = commands.firstIndex(of: target) else { return }
        commands.insert(source, at: index + (after ? 1 : 0))
        withAnimation(.easeInOut(duration: 0.15)) {
            order = commands.map(\.rawValue).joined(separator: ",")
        }
    }

    private func localized(_ key: String) -> String {
        SharedSettings.localized(key, language: language)
    }

    var body: some View {
        Form {
            let commands = ContextCommand.ordered(order)
            Section {
                HStack {
                    Text(localized("Show icons"))
                    Spacer()
                    Toggle(localized("Show icons"), isOn: $icons)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
            Section {
                ForEach(commands, id: \.self) { command in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            CommandDragHandle(command: command, title: command.title(language: language)) { active in
                                insertion = nil
                                isDragging = active
                            }
                            .frame(width: 26, height: 26)
                                .help(localized("Drag to reorder"))
                            Text(command.title(language: language))
                            Spacer()
                            if command == .newFile {
                                Button(localized(showsFileTypes ? "Collapse" : "Expand")) { showsFileTypes.toggle() }
                            }
                            CommandToggle(command: command, language: language)
                        }
                        if command == .newFile && showsFileTypes {
                            VStack(alignment: .leading, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Toggle(localized("Show as submenu"), isOn: $submenu)
                                    Text(localized("Finder limitation: clicking the New File item itself closes the whole menu. Hover over it to open the submenu. Finder Sync extensions cannot prevent this, even on macOS 26."))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Text(localized("New File Items"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 6)
                                VStack(alignment: .leading, spacing: 10) {
                                    Toggle(localized("Plain Text (.txt)"), isOn: $txt)
                                    Toggle(localized("Markdown (.md)"), isOn: $md)
                                    Toggle(localized("Word document (.docx)"), isOn: $word)
                                    Toggle(localized("Excel workbook (.xlsx)"), isOn: $excel)
                                    Toggle(localized("PowerPoint presentation (.pptx)"), isOn: $ppt)
                                    Toggle(localized("Show Custom File and preset extensions"), isOn: $customEnabled)
                                    TextField(localized("Preset extensions (comma separated)"), text: $custom).disabled(!customEnabled)
                                }
                                .padding(.leading, 16)
                            }
                            .padding(.leading, 16)
                            .disabled(!enabled)
                        }
                    }
                    .modifier(CommandDropTarget(command: command, isDragging: $isDragging, insertion: $insertion) { source, after in insert(source, at: command, after: after) })
                }
            }
            HStack {
                Button(localized("Restore Default Order")) { order = "" }
                Button(localized("Restore All")) {
                    order = ""
                    for command in ContextCommand.allCases {
                        SharedSettings.defaults.set(command.defaultEnabled, forKey: command.rawValue)
                    }
                    icons = true
                    submenu = false
                    txt = true
                    md = true
                    word = true
                    excel = true
                    ppt = true
                    customEnabled = true
                    custom = ""
                }
            }
            Text(localized("Menu items are saved locally. Finder command execution will be available after the Finder extension is installed and enabled.")).font(.caption).foregroundStyle(.secondary)
        }.formStyle(.grouped)
    }
}

private struct CommandDragHandle: NSViewRepresentable {
    let command: ContextCommand
    let title: String
    let draggingChanged: (Bool) -> Void

    func makeNSView(context: Context) -> Handle {
        let view = Handle()
        view.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: title)
        view.contentTintColor = .secondaryLabelColor
        view.imageScaling = .scaleNone
        return view
    }

    func updateNSView(_ view: Handle, context: Context) {
        view.key = command.rawValue
        view.title = title
        view.draggingChanged = draggingChanged
    }

    final class Handle: NSImageView, NSDraggingSource {
        var key = ""
        var title = ""
        var draggingChanged: ((Bool) -> Void)?

        override func mouseDown(with event: NSEvent) {}

        override func mouseDragged(with event: NSEvent) {
            let item = NSDraggingItem(pasteboardWriter: key as NSString)
            let label = NSTextField(labelWithString: title)
            label.sizeToFit()
            let preview = NSImage(size: label.frame.size, flipped: false) { rect in
                (self.title as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize), .foregroundColor: NSColor.labelColor])
                return true
            }
            item.setDraggingFrame(NSRect(origin: .zero, size: preview.size), contents: preview)
            beginDraggingSession(with: [item], event: event, source: self)
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }

        func draggingSession(_ session: NSDraggingSession, willBeginAt point: NSPoint) {
            draggingChanged?(true)
        }

        func draggingSession(_ session: NSDraggingSession, endedAt point: NSPoint, operation: NSDragOperation) {
            draggingChanged?(false)
        }
    }
}

private struct CommandInsertion: Equatable {
    let command: ContextCommand
    let after: Bool
}

private struct CommandDropTarget: ViewModifier {
    let command: ContextCommand
    @Binding var isDragging: Bool
    @Binding var insertion: CommandInsertion?
    let insert: @MainActor (ContextCommand, Bool) -> Void
    @State private var height: CGFloat = 0
    private var insertAfter: Bool? { insertion?.command == command ? insertion?.after : nil }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
            .overlay(alignment: insertAfter == true ? .bottom : .top) {
                if isDragging && insertAfter != nil {
                    Rectangle().fill(Color.accentColor).frame(height: 2)
                        .transition(.identity)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.plainText], delegate: InsertionDelegate(
                command: command, midpoint: height / 2, isDragging: $isDragging, insertion: $insertion, insert: insert
            ))
    }

    private struct InsertionDelegate: DropDelegate {
        let command: ContextCommand
        let midpoint: CGFloat
        @Binding var isDragging: Bool
        @Binding var insertion: CommandInsertion?
        let insert: @MainActor (ContextCommand, Bool) -> Void

        func dropEntered(info: DropInfo) {
            guard isDragging else { return }
            insertion = CommandInsertion(command: command, after: info.location.y >= midpoint)
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            guard isDragging else { return DropProposal(operation: .cancel) }
            insertion = CommandInsertion(command: command, after: info.location.y >= midpoint)
            return DropProposal(operation: .move)
        }

        func dropExited(info: DropInfo) {
            if insertion?.command == command { insertion = nil }
        }

        func performDrop(info: DropInfo) -> Bool {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isDragging = false
                insertion = nil
            }
            guard let provider = info.itemProviders(for: [.plainText]).first else { return false }
            let after = info.location.y >= midpoint
            provider.loadObject(ofClass: NSString.self) { value, _ in
                guard let key = value as? String, let command = ContextCommand(rawValue: key) else { return }
                Task { @MainActor in insert(command, after) }
            }
            return true
        }
    }
}

private struct CommandToggle: View {
    let title: String
    @AppStorage private var enabled: Bool

    init(command: ContextCommand, language: String) {
        title = command.title(language: language)
        _enabled = AppStorage(wrappedValue: command.initialEnabled, command.rawValue, store: SharedSettings.defaults)
    }

    var body: some View {
        Toggle(title, isOn: $enabled).labelsHidden().toggleStyle(.switch)
    }
}
