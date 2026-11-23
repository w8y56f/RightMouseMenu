import AppKit
import FinderSync
import OSLog

final class FinderExtension: FIFinderSync {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.stone.rightmousemenu", category: "FinderExtension")
    private var menuRequests: [FinderRequest] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard [.contextualMenuForItems, .contextualMenuForContainer, .contextualMenuForSidebar].contains(menuKind) else { return nil }
        menuRequests.removeAll(keepingCapacity: true)
        SharedSettings.defaults.synchronize()
        let controller = FIFinderSyncController.default()
        let target = controller.targetedURL()
        let selected = menuKind == .contextualMenuForItems ? (controller.selectedItemURLs() ?? []) : []
        guard let first = target ?? selected.first else { return nil }
        let isDirectory = first.hasDirectoryPath || (try? first.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let directory = isDirectory ? first : first.deletingLastPathComponent()
        let context = MenuContext(directory: directory, items: selected.isEmpty ? [first] : selected)

        let menu = NSMenu(title: "RightMouseMenu")
        menu.autoenablesItems = false
        let preference = SharedSettings.defaults.string(forKey: ContextCommand.orderKey) ?? ""
        for command in ContextCommand.ordered(preference) {
            guard SharedSettings.enabled(command.rawValue, default: command.initialEnabled) else { continue }
            let title = command.title()
            switch command {
            case .newFile:
                if selected.count <= 1 { addNewFiles(to: menu, context: context) }
            case .vscode:
                add(menu, title, "open:com.microsoft.VSCode", context, icon: "chevron.left.forwardslash.chevron.right")
            case .fullPath:
                add(menu, title, "copy", context, icon: "document.on.clipboard")
            case .fileInfo:
                add(menu, title, "info", context, icon: "info.circle")
            default:
                guard let app = command.terminalApp,
                      NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundle) != nil else { continue }
                add(menu, title, (command.isTab ? "tab:" : "open:") + app.bundle, context, icon: "terminal")
            }
        }
        if menu.items.last?.isSeparatorItem == true { menu.removeItem(at: menu.numberOfItems - 1) }
        return menu.items.isEmpty ? nil : menu
    }

    private func addNewFiles(to menu: NSMenu, context: MenuContext) {
        let start = menu.numberOfItems
        for (name, ext, key) in [("Text File", "txt", "txt"), ("Markdown File", "md", "md"), ("Word Document", "docx", "word"), ("Excel Workbook", "xlsx", "excel"), ("PowerPoint Presentation", "pptx", "ppt")] {
            if SharedSettings.enabled("newFile.\(key)") { add(menu, name, "create:\(ext)", context, icon: "doc.badge.plus") }
        }
        if SharedSettings.enabled("newFile.custom") {
            add(menu, "Custom File…", "create-custom", context, icon: "doc.badge.plus")
            let presets = SharedSettings.defaults.string(forKey: "customExtensions") ?? ""
            var seen = Set(["txt", "md", "docx", "xlsx", "pptx"])
            for value in presets.split(separator: ",") {
                guard let ext = SharedSettings.fileExtension(from: String(value)),
                      seen.insert(ext).inserted else { continue }
                add(menu, String(format: SharedSettings.localized("%@ File"), ext.uppercased()), "create:\(ext)", context, icon: "doc.badge.plus")
            }
        }
        // Finder closes the whole menu when the submenu's parent item is clicked; extensions cannot prevent it.
        if menu.numberOfItems > start, SharedSettings.enabled("newFileSubmenu", default: false) {
            let submenu = NSMenu(title: SharedSettings.localized("New File"))
            submenu.autoenablesItems = false
            while menu.numberOfItems > start {
                let item = menu.item(at: start)!
                menu.removeItem(at: start)
                submenu.addItem(item)
            }
            let parent = NSMenuItem(title: SharedSettings.localized("New File"), action: nil, keyEquivalent: "")
            if SharedSettings.enabled("newFileIcons") {
                parent.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: parent.title)
            }
            parent.submenu = submenu
            menu.addItem(parent)
        } else if menu.numberOfItems > start {
            let heading = NSMenuItem.sectionHeader(title: SharedSettings.localized("New File"))
            heading.isEnabled = false
            menu.insertItem(heading, at: start)
            menu.addItem(.separator())
        }
    }

    private struct MenuContext {
        let directory: URL
        let items: [URL]
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: String, _ context: MenuContext, icon: String) {
        let label = SharedSettings.localized(title)
        let item = NSMenuItem(title: label, action: #selector(performAction(_:)), keyEquivalent: "")
        item.target = self
        // Finder sends the menu item's tag back to the extension.
        menuRequests.append(FinderRequest(action: action, directory: context.directory, items: context.items))
        item.tag = menuRequests.count
        if SharedSettings.enabled("newFileIcons") {
            item.image = NSImage(systemSymbolName: icon, accessibilityDescription: label)
        }
        menu.addItem(item)
    }

    @objc private func performAction(_ sender: NSMenuItem) {
        guard sender.tag > 0, sender.tag <= menuRequests.count else { return }
        let request = menuRequests[sender.tag - 1]
        let app = Bundle(for: FinderExtension.self).bundleURL
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        do {
            let url = try request.write()
            if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleURL == app }) { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = false
            config.addsToRecentItems = false
            config.allowsRunningApplicationSubstitution = false
            NSWorkspace.shared.openApplication(at: app, configuration: config) { [logger] _, error in
                if let error {
                    try? FileManager.default.removeItem(at: url)
                    logger.error("Could not open Finder command in RightMouseMenu: \(error.localizedDescription, privacy: .public)")
                }
            }
        } catch {
            logger.error("Could not save Finder command: \(error.localizedDescription, privacy: .public)")
        }
    }
}
