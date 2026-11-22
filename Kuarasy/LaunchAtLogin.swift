import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp`. State is read live, never cached.
enum LaunchAtLogin {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Kuarasy: launch at login change failed: \(error.localizedDescription)")
        }
    }
}
