import SwiftUI
import AppKit
import Combine

final class HUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HUDController {
    static let shared = HUDController()

    private var panel: HUDPanel?
    private var cancellables = Set<AnyCancellable>()
    private let width: CGFloat = 400
    private var currentHeight: CGFloat = 240

    private init() {}

    func prepare() {
        guard panel == nil else { return }
        let panel = HUDPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: currentHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = false
        panel.animationBehavior = .utilityWindow

        let host = NSHostingView(rootView:
            HUDView()
                .environmentObject(DownloadManager.shared)
                .environmentObject(AppState.shared)
                .environmentObject(LibraryStore.shared)
        )
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host

        self.panel = panel
        position()

        DownloadManager.shared.$jobs
            .receive(on: RunLoop.main)
            .sink { [weak self] jobs in
                guard let self else { return }
                if !jobs.contains(where: { $0.state.isActive }) && self.isVisible {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        if !DownloadManager.shared.jobs.contains(where: { $0.state.isActive }) {
                            self.hide()
                        }
                    }
                }
            }
            .store(in: &cancellables)

        DownloadManager.shared.onJobStarted = { [weak self] _ in
            guard Preferences.shared.autoShowHUD else { return }
            self?.show()
        }
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        prepare()
        guard let panel else { return }
        position()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func resize(to size: CGSize) {
        guard let panel else { return }
        let height = max(140, size.height)
        guard abs(height - currentHeight) > 0.5 else { return }
        currentHeight = height
        var frame = panel.frame
        frame.origin.y += frame.height - height
        frame.size = CGSize(width: width, height: height)
        panel.setFrame(frame, display: true, animate: true)
    }

    private func position() {
        guard let panel, let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let x = visible.maxX - width - 6
        let y = visible.minY + 6
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
