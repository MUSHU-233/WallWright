#if DEBUG
import SwiftUI

// 在 Xcode 里按 ⌥⌘↩ 打开画布，改动代码会实时预览，不必运行整个 App。

#Preview("主窗口") {
    RootView()
        .environmentObject(AppState.shared)
        .environmentObject(LibraryStore.shared)
        .environmentObject(DownloadManager.shared)
        .environmentObject(Preferences.shared)
        .environmentObject(SteamCMDService.shared)
        .frame(width: 1160, height: 740)
}

#Preview("悬浮 HUD") {
    HUDView()
        .environmentObject(DownloadManager.shared)
        .environmentObject(AppState.shared)
        .environmentObject(LibraryStore.shared)
        .frame(width: 400, height: 320)
        .background(AuroraBackground())
}

#Preview("壁纸卡片") {
    ItemCard(item: Snapshot.sample, onOpen: {}, onDownload: {})
        .frame(width: 240)
        .padding(30)
        .background(AuroraBackground())
}

#Preview("玻璃按钮") {
    HStack(spacing: 12) {
        Button("主按钮") {}.buttonStyle(CapsuleButtonStyle(kind: .primary))
        Button("玻璃按钮") {}.buttonStyle(CapsuleButtonStyle(kind: .glass))
        Button("幽灵按钮") {}.buttonStyle(CapsuleButtonStyle(kind: .ghost))
    }
    .padding(40)
    .background(AuroraBackground())
}

#Preview("设置页") {
    SettingsView()
        .environmentObject(Preferences.shared)
        .environmentObject(SteamCMDService.shared)
        .frame(width: 760, height: 620)
}
#endif
