import SwiftUI

final class MenuRequestReceiver: NSObject, NSApplicationDelegate {
    private var requestWatcher: DispatchSourceFileSystemObject?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if UserDefaults.standard.object(forKey: "appearance") == nil,
           let appearance = UserDefaults(suiteName: "com.stone.RightMouseMenu")?.string(forKey: "appearance") {
            UserDefaults.standard.set(appearance, forKey: "appearance")
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = SharedSettings.defaults
        for command in ContextCommand.allCases where command.isTab && defaults.object(forKey: command.rawValue) == nil {
            defaults.set(command.initialEnabled, forKey: command.rawValue)
        }
        do { try watchFinderRequests() }
        catch { MenuActions.report(error) }
    }

    func applicationWillTerminate(_ notification: Notification) {
        requestWatcher?.cancel()
    }

    private func watchFinderRequests() throws {
        try FinderRequest.prepareFolder()
        let folder = try FinderRequest.requestFolder()
        let descriptor = Darwin.open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileReadUnknown) }
        let watcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor, eventMask: .write, queue: .main
        )
        watcher.setEventHandler { [weak self] in self?.receiveFinderRequests(in: folder) }
        watcher.setCancelHandler { Darwin.close(descriptor) }
        requestWatcher = watcher
        watcher.resume()
        receiveFinderRequests(in: folder)
    }

    private func receiveFinderRequests(in folder: URL) {
        do {
            for url in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey]) {
                do {
                    if let request = try FinderRequest.take(from: url) {
                        DispatchQueue.main.async { MenuActions.perform(request) }
                    }
                } catch { MenuActions.report(error) }
            }
        } catch { MenuActions.report(error) }
    }
}

@main
struct RightMouseMenuApp: App {
    @NSApplicationDelegateAdaptor(MenuRequestReceiver.self) private var receiver
    @Environment(\.openWindow) private var openWindow
    @AppStorage("language", store: SharedSettings.defaults) private var language = "System"

    static let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "RightMouseMenu"
    #if DEV
    private static let menuBarIcon = "hammer.circle"
    #else
    private static let menuBarIcon = "contextualmenu.and.cursorarrow"
    #endif

    var body: some Scene {
        Window("RightMouseMenu", id: "settings") {
            SettingsRootView(language: $language)
                .frame(minWidth: 720, minHeight: 500)
        }
        .windowResizability(.contentSize)

        MenuBarExtra(Self.displayName, systemImage: Self.menuBarIcon) {
            Button(SharedSettings.localized("Open Settings…", language: language)) {
                openWindow(id: "settings")
                NSApp.activate()
            }
            Divider()
            Button(SharedSettings.localized("Quit RightMouseMenu", language: language)) { NSApp.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
