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
    @StateObject private var auth = AuthStore.shared
    @StateObject private var favorites = FavoritesStore.shared

    var body: some Scene {
        Window("WallWright", id: "main") {
            Group {
                if auth.isSignedIn {
                    RootView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(state)
            .environmentObject(library)
            .environmentObject(downloads)
            .environmentObject(prefs)
            .environmentObject(steamcmd)
            .environmentObject(auth)
            .environmentObject(favorites)
            .frame(minWidth: 940, minHeight: 620)
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
            if auth.isSignedIn {
                MenuBarPanel()
                    .environmentObject(state)
                    .environmentObject(downloads)
                    .environmentObject(prefs)
                    .environmentObject(library)
            } else {
                SignedOutPanel()
            }
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

struct SignedOutPanel: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(.secondary)
            Text("需要先登录 Steam")
                .font(WW.Font.rounded(12, .semibold))
            Button("打开 WallWright") {
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .buttonStyle(CapsuleButtonStyle(kind: .primary))
        }
        .padding(20)
        .frame(width: 240)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--snapshot") {
            Task { await Snapshot.runIfRequested() }
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
