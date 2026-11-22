import SwiftUI

@main
struct KuarasyApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(appDelegate.store)
        } label: {
            MenuBarLabel(store: appDelegate.store)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ClockStore()
    #if DEBUG
    private var previewWindow: NSWindow?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        openPreviewWindowIfRequested()
        #endif
    }

    #if DEBUG
    /// `--preview [list|add|settings|edit] [--scrub]` opens the popover content in a normal
    /// window, so it can be inspected and screenshotted without clicking the menu bar.
    private func openPreviewWindowIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "--preview") else { return }
        let name = i + 1 < args.count ? args[i + 1] : "list"
        // `--demo` uses a throwaway store with counted and reference locations,
        // so the preview never touches saved data.
        let store = args.contains("--demo") ? Self.demoStore() : self.store
        let route: Route = switch name {
        case "add": .add
        case "settings": .settings
        case "edit": store.locations.first.map { .edit($0.id) } ?? .list
        default: .list
        }
        if args.contains("--scrub") {
            let day = TimeMath.day(containing: Date(), in: store.homeTimeZone)
            store.selectedDate = day.start.addingTimeInterval(15 * 3600)
        }
        let host = NSHostingView(rootView: PopoverView(initialRoute: route).environment(store))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 700),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.title = "Kuarasy Preview"
        window.contentView = host
        window.setContentSize(host.fittingSize)
        window.setFrameTopLeftPoint(NSPoint(x: 80, y: (NSScreen.main?.visibleFrame.maxY ?? 900) - 40))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        previewWindow = window
        if let j = args.firstIndex(of: "--snapshot"), j + 1 < args.count {
            let path = NSTemporaryDirectory() + args[j + 1]  // sandbox: container tmp
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Self.snapshot(host, to: path)
                NSApp.terminate(nil)
            }
        }
    }

    private static func demoStore() -> ClockStore {
        let suite = "kuarasy.demo"
        UserDefaults().removePersistentDomain(forName: suite)
        let store = ClockStore(defaults: UserDefaults(suiteName: suite)!)
        store.settings.homeTimeZoneID = "America/Sao_Paulo"
        store.locations = [
            Location(timeZoneID: "America/New_York"),
            Location(timeZoneID: "America/Los_Angeles"),
            Location(timeZoneID: "Asia/Kolkata", alias: "Varanasi", countsTowardBar: false),
            Location(timeZoneID: "Europe/London", countsTowardBar: false),
        ]
        return store
    }

    /// Writes the view to a PNG (layout only: system glass blur is composited by the window server).
    private static func snapshot(_ view: NSView, to path: String) {
        let size = view.fittingSize
        view.frame.size = size
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let data = rep.representation(using: .png, properties: [:])
        try? data?.write(to: URL(fileURLWithPath: path))
    }
    #endif
}
