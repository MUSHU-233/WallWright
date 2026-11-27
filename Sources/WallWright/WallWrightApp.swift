import SwiftUI
import AppKit

@main
struct WallWrightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState.shared
    @StateObject private var library = LibraryStore.shared
    @StateObject private var downloads = DownloadManager.shared
    @StateObject private var prefs = Preferences.shared
    @StateObject private var steamcmd = SteamCMDService.shared

    var body: some Scene {
        Window("WallWright", id: "main") {
            RootView()
                .environmentObject(state)
                .environmentObject(library)
                .environmentObject(downloads)
                .environmentObject(prefs)
                .environmentObject(steamcmd)
                .frame(minWidth: 940, minHeight: 620)
                .task { await state.bootstrap() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1160, height: 740)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .windowList) {
                Button("显示下载 HUD") { HUDController.shared.show() }
                    .keyboardShortcut("h", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(state)
                .environmentObject(downloads)
                .environmentObject(prefs)
                .environmentObject(library)
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--snapshot") {
            Snapshot.runIfRequested()
            return
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        HUDController.shared.prepare()
        SteamCMDService.shared.refresh()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        return true
    }
}
