import AppKit
import ApplicationServices

enum MenuActions {
    @MainActor
    static func perform(_ request: FinderRequest) {
        guard request.directory.isFileURL, request.items.allSatisfy(\.isFileURL) else { return }
        do {
            let parts = request.action.split(separator: ":", maxSplits: 1)
            switch parts.first {
            case "copy":
                guard !request.items.isEmpty else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(request.items.map(\.path).joined(separator: "\n"), forType: .string)
            case "info":
                guard !request.items.isEmpty else { return }
                try showInfo(request.items)
            case "create":
                guard parts.count == 2, let ext = SharedSettings.fileExtension(from: String(parts[1])) else { return }
                try createFile(in: request.directory, extension: ext, useTemplate: true)
            case "create-custom":
                if let ext = promptForFileExtension() {
                    try createFile(in: request.directory, extension: ext, useTemplate: false)
                }
            case "open", "tab":
                guard parts.count == 2 else { return }
                try open(String(parts[1]), tab: parts[0] == "tab", directory: request.directory, items: request.items)
            default: return
            }
        } catch { report(error) }
    }

    @MainActor
    private static func promptForFileExtension() -> String? {
        let alert = NSAlert()
        alert.messageText = SharedSettings.localized("Custom File…")
        alert.informativeText = SharedSettings.localized("Enter a file extension, such as log or .log.")
        alert.addButton(withTitle: SharedSettings.localized("Create"))
        alert.addButton(withTitle: SharedSettings.localized("Cancel")).keyEquivalent = "\u{1b}"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 245, height: 24))
        input.placeholderString = "log"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        NSApp.activate()
        while alert.runModal() == .alertFirstButtonReturn {
            if let ext = SharedSettings.fileExtension(from: input.stringValue) { return ext }
            alert.informativeText = SharedSettings.localized("Use 1–32 letters (A–Z), numbers, hyphens, or underscores.")
            input.selectText(nil)
        }
        return nil
    }

    private static func createFile(in directory: URL, extension ext: String, useTemplate: Bool) throws {
        var name = "Untitled"
        var index = 2
        while true {
            let destination = directory.appendingPathComponent(name).appendingPathExtension(ext)
            do {
                if useTemplate {
                    try OfficeDocument.create(at: destination)
                } else {
                    try Data().write(to: destination, options: .withoutOverwriting)
                }
                NSWorkspace.shared.activateFileViewerSelecting([destination])
                return
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                name = "Untitled \(index)"
                index += 1
            }
        }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "RightMouseMenu", code: 1, userInfo: [NSLocalizedDescriptionKey: SharedSettings.localized(message)])
    }

    static func report(_ error: Error) {
        DispatchQueue.main.async {
            NSApp.activate()
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    static func finderAutomationStatus(prompt: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        return AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, prompt)
    }

    private static func windowIDs(of pid: pid_t, options: CGWindowListOption) -> Set<CGWindowID> {
        let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return Set(windows.compactMap { window in
            guard window[kCGWindowOwnerPID as String] as? pid_t == pid,
                  window[kCGWindowLayer as String] as? Int == 0 else { return nil }
            return window[kCGWindowNumber as String] as? CGWindowID
        })
    }

    private static func showInfo(_ items: [URL]) throws {
        let aliases = items.map { "(POSIX file " + literal($0.path) + ") as alias" }.joined(separator: ", ")
        try run("""
        set selectedItems to {\(aliases)}
        tell application id "com.apple.finder"
            activate
            repeat with selectedItem in selectedItems
                open information window of (contents of selectedItem)
            end repeat
        end tell
        """)
    }

    static func open(_ bundleID: String, tab: Bool, directory: URL, items: [URL]) throws {
        guard ["com.microsoft.VSCode", "org.tabby", "com.apple.Terminal", "com.googlecode.iterm2"].contains(bundleID) else { return }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw failure("The selected application is not installed.")
        }
        switch bundleID {
        case "com.microsoft.VSCode":
            NSWorkspace.shared.open(items, withApplicationAt: url, configuration: .init()) { _, error in
                if let error { DispatchQueue.main.async { report(error) } }
            }
        case "org.tabby":
            guard let executable = Bundle(url: url)?.executableURL else { throw failure("Tabby’s launcher was not found.") }
            Task { @MainActor in
                do {
                    if !tab, let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
                        let pid = app.processIdentifier
                        let previous = windowIDs(of: pid, options: .optionAll)
                        if !previous.isEmpty {
                            // A second Tabby invocation without arguments requests a new window.
                            _ = try Process.run(executable, arguments: [])
                            let deadline = ContinuousClock.now + .seconds(8)
                            while windowIDs(of: pid, options: .optionOnScreenOnly).subtracting(previous).isEmpty {
                                guard ContinuousClock.now < deadline else {
                                    throw failure("Tabby did not open a new window.")
                                }
                                try await Task.sleep(for: .milliseconds(100))
                            }
                            // Electron shows the window before Tabby registers its CLI handler.
                            try await Task.sleep(for: .seconds(1))
                        }
                    }
                    try Process.run(executable, arguments: ["open", directory.path]) { task in
                        if task.terminationStatus != 0 {
                            report(failure("Tabby could not open the selected folder."))
                        }
                    }
                } catch { report(error) }
            }
        case "com.apple.Terminal":
            if tab {
                let pasteboard = NSPasteboard.withUniqueName()
                defer { pasteboard.releaseGlobally() }
                pasteboard.writeObjects([directory as NSURL])
                pasteboard.setString(directory.path, forType: .string)
                guard NSPerformService("New Terminal Tab at Folder", pasteboard) else {
                    throw failure("Terminal could not open a tab at the selected folder.")
                }
                return
            }
            let command = "cd -- " + shellQuote(directory.path)
            try run("""
            tell application id "com.apple.Terminal"
                do script \(literal(command))
                activate
            end tell
            """)
        case "com.googlecode.iterm2":
            let command = literal("cd -- " + shellQuote(directory.path))
            try run("""
            tell application id "com.googlecode.iterm2"
                activate
                if \(tab) and (count of windows) > 0 then
                    tell current window to set newTab to (create tab with default profile)
                    tell current session of newTab to write text \(command)
                else
                    set newWindow to (create window with default profile)
                    tell current session of newWindow to write text \(command)
                end if
            end tell
            """)
        default: break
        }
    }

    private static func run(_ source: String) throws {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error {
            if error[NSAppleScript.errorNumber] as? Int == -1743 {
                throw failure("Allow RightMouseMenu to control the requested app in System Settings → Privacy & Security → Automation, then try again.")
            }
            throw failure(error[NSAppleScript.errorMessage] as? String ?? "The application could not complete the command.")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func literal(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
