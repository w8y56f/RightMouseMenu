import Foundation

public enum SharedSettings {
    // The Debug build (DEV) uses its own suite and request folder so it never interferes with an installed copy.
    // Both names must match the sandbox exceptions in Config/Extension*.entitlements.
    #if DEV
    static let suiteName = "com.stone.RightMouseMenu.dev.shared"
    static let supportFolderName = "RightMouseMenu Dev"
    #else
    // Keep the existing preferences suite when the app bundle identifier changes.
    static let suiteName = "com.stone.RightMouseMenu.shared"
    static let supportFolderName = "RightMouseMenu"
    #endif
    nonisolated(unsafe) public static let defaults = UserDefaults(suiteName: suiteName) ?? .standard
    public static func enabled(_ key: String, default fallback: Bool = true) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }
}

extension SharedSettings {
    static func fileExtension(from input: String) -> String? {
        var ext = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ext.hasPrefix(".") { ext.removeFirst() }
        guard (1...32).contains(ext.count),
              ext.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { return nil }
        return ext
    }

    static func localized(_ key: String, language: String? = nil) -> String {
        let choice = language ?? defaults.string(forKey: "language") ?? "System"
        let chinese = choice == "中文" || (choice == "System" && Locale.preferredLanguages.first?.hasPrefix("zh") == true)
        guard chinese, let url = Bundle.main.url(forResource: "zh-Hans", withExtension: "lproj"),
              let bundle = Bundle(url: url) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}

enum ContextCommand: String, CaseIterable {
    case newFile = "newFileEnabled"
    case vscode = "menu.vscode"
    case terminal = "menu.terminal"
    case terminalTab = "menu.terminal.tab"
    case iterm = "menu.iterm"
    case itermTab = "menu.iterm.tab"
    case tabby = "menu.tabby"
    case tabbyTab = "menu.tabby.tab"
    case fullPath = "menu.fullPath"
    case fileInfo = "menu.fileInfo"

    static let orderKey = "contextMenuOrder"

    static func ordered(_ preference: String) -> [Self] {
        var remaining = allCases
        var ordered: [Self] = []
        for key in preference.split(separator: ",") {
            if let index = remaining.firstIndex(where: { $0.rawValue == key }) {
                ordered.append(remaining.remove(at: index))
            }
        }
        return ordered + remaining
    }

    var terminalApp: (name: String, bundle: String)? {
        switch self {
        case .terminal, .terminalTab: ("Terminal", "com.apple.Terminal")
        case .iterm, .itermTab: ("iTerm2", "com.googlecode.iterm2")
        case .tabby, .tabbyTab: ("Tabby", "org.tabby")
        default: nil
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .iterm, .itermTab, .tabby, .tabbyTab: false
        default: true
        }
    }

    var initialEnabled: Bool {
        isTab ? SharedSettings.enabled(String(rawValue.dropLast(4)), default: defaultEnabled) : defaultEnabled
    }

    var isTab: Bool { rawValue.hasSuffix(".tab") }

    func title(language: String? = nil) -> String {
        if let app = terminalApp {
            let format = SharedSettings.localized(isTab ? "New %@ Tab here" : "New %@ here", language: language)
            return String(format: format, app.name)
        }
        let key = switch self {
        case .newFile: "Show New File menu"
        case .vscode: "Open with Visual Studio Code"
        case .fullPath: "Copy Full Path"
        default: "File Information"
        }
        return SharedSettings.localized(key, language: language)
    }
}

struct FinderRequest: Codable {
    let action: String
    let directory: URL
    let items: [URL]

    private static let fileExtension = "rmmrequest"

    static func requestFolder() throws -> URL {
        // The extension runs with a sandbox home. Resolve the user's actual home directory.
        guard let home = getpwuid(getuid())?.pointee.pw_dir else {
            throw CocoaError(.fileNoSuchFile)
        }
        return URL(fileURLWithFileSystemRepresentation: home, isDirectory: true, relativeTo: nil)
            .appending(path: "Library/Application Support/\(SharedSettings.supportFolderName)/FinderRequests", directoryHint: .isDirectory)
    }

    static func prepareFolder() throws {
        try FileManager.default.createDirectory(
            at: requestFolder(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    func write() throws -> URL {
        let url = try Self.requestFolder().appending(path: UUID().uuidString)
            .appendingPathExtension(Self.fileExtension)
        try JSONEncoder().encode(self).write(to: url, options: .atomic)
        return url
    }

    static func take(from url: URL) throws -> Self? {
        let file = url.standardizedFileURL
        guard file.isFileURL, file.pathExtension == fileExtension,
              UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
              file.deletingLastPathComponent().path == (try requestFolder()).path,
              try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { return nil }

        let data = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
