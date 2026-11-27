import SwiftUI

@MainActor
enum Snapshot {
    static func runIfRequested() {
        guard let index = CommandLine.arguments.firstIndex(of: "--snapshot"),
              CommandLine.arguments.count > index + 1 else { return }
        let dir = CommandLine.arguments[index + 1]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let state = AppState.shared
        let library = LibraryStore.shared
        let downloads = DownloadManager.shared
        let prefs = Preferences.shared
        let steamcmd = SteamCMDService.shared

        func env<V: View>(_ view: V) -> AnyView {
            AnyView(view
                .environmentObject(state)
                .environmentObject(library)
                .environmentObject(downloads)
                .environmentObject(prefs)
                .environmentObject(steamcmd))
        }

        let shots: [(String, AnyView, CGFloat, CGFloat)] = [
            ("main", env(RootView()), 1160, 740),
            ("hud", env(HUDView()), 400, 320),
            ("detail", env(ItemDetailView(item: sample)), 860, 540),
            ("menu", env(MenuBarPanel()), 344, 460)
        ]

        for (name, view, w, h) in shots {
            render(view, name: name, width: w, height: h, dir: dir)
        }
        NSApp.terminate(nil)
    }

    static var sample: WorkshopItem {
        WorkshopItem(
            id: "3007983717",
            title: "【孤独摇滚】永不停息的旅程",
            summary: "4K 60FPS 场景壁纸，带音频响应与可自定义配色。",
            previewURL: URL(string: "https://images.steamusercontent.com/ugc/2053132367043461878/94647364943E78EA0AD47A6E6B5F95AB708550E7/"),
            fileSize: 55_535_026,
            subscriptions: 43775,
            views: 1_204_882,
            tags: ["Wallpaper", "Scene", "Anime", "Audio responsive", "3840 x 2160"],
            created: Date(),
            updated: Date(),
            kind: .scene
        )
    }

    private static func render(_ view: AnyView, name: String, width: CGFloat, height: CGFloat, dir: String) {
        let renderer = ImageRenderer(content:
            view
                .frame(width: width, height: height)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            print("snapshot failed: \(name)")
            return
        }
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        print("wrote \(name).png")
    }
}
