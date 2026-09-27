import AppKit
import SwiftUI

/// Observable state for the floating capsule widget
@MainActor
public final class CapsuleViewModel: ObservableObject {
    public static let shared = CapsuleViewModel()

    @Published public var isDictating: Bool = false
    @Published public var liveTranscript: String = ""
    @Published public var isHovered: Bool = false
}

/// The floating bottom-screen capsule widget.
/// Idle: Minimal, subtle dark-grey pill (no square artifacts, no clutter).
/// Hover/Dictate: Expands with smooth, subtle animations inside a stable transparent container.
public struct CapsuleWidgetView: View {
    @ObservedObject var model = CapsuleViewModel.shared

    var onToggleDictation: () -> Void
    var onOpenDashboard: () -> Void

    public init(
        onToggleDictation: @escaping () -> Void,
        onOpenDashboard: @escaping () -> Void
    ) {
        self.onToggleDictation = onToggleDictation
        self.onOpenDashboard = onOpenDashboard
    }

    public var body: some View {
        HStack {
            Spacer(minLength: 0)

            capsuleContent
                .onHover { hovering in
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        model.isHovered = hovering
                    }
                }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var capsuleContent: some View {
        ZStack {
            if model.isDictating {
                // DICTATING: Sleek capsule showing live transcript right inside!
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.25, blue: 0.2))
                        .frame(width: 7, height: 7)

                    // Subtle mini waveform bars
                    HStack(spacing: 2) {
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 7)
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 13)
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 9)
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 14)
                        Capsule().fill(Color.white.opacity(0.85)).frame(width: 2, height: 6)
                    }

                    // Live transcript inside the capsule with smooth head truncation
                    Text(model.liveTranscript.isEmpty ? "Listening…" : model.liveTranscript)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .frame(minWidth: 40, maxWidth: .infinity, alignment: .leading)

                    Button(action: onToggleDictation) {
                        Text("fn")
                            .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.white.opacity(0.18))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .frame(width: dynamicDictatingWidth, height: 26)
                .transition(.opacity)

            } else if model.isHovered {
                // HOVERED: Clean small control pill
                HStack(spacing: 6) {
                    Button(action: onToggleDictation) {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)

                            Text("fn")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.8))
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 1.5)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.16))
                                )
                        }
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .help("Hold Fn or Right ⌥ to speak")

                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 11)

                    Button(action: onOpenDashboard) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.75))
                            .frame(width: 18, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Open Dashboard")
                }
                .padding(.horizontal, 8)
                .frame(width: 120, height: 26)
                .transition(.opacity)

            } else {
                // IDLE: Sleek, minimalist small grey capsule pill (no icons, pure subtle indicator)
                Button(action: onToggleDictation) {
                    Capsule()
                        .fill(Color(white: 0.38).opacity(0.85))
                        .frame(width: 28, height: 5)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 6)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("VocalFluid — Hold Fn to speak")
                .frame(width: 40, height: 26)
                .transition(.opacity)
            }
        }
        .background(
            ZStack {
                Capsule()
                    .fill(Color(red: 0.14, green: 0.14, blue: 0.16).opacity(0.88))

                Capsule()
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }

    private var dynamicDictatingWidth: CGFloat {
        let textLen = model.liveTranscript.count
        if textLen <= 10 {
            return 210
        } else {
            let estimated = CGFloat(160 + min(textLen * 7, 280))
            return min(max(estimated, 210), 450)
        }
    }
}

@MainActor
public final class CapsuleWidgetController {
    public static let shared = CapsuleWidgetController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<CapsuleWidgetView>?

    public var onToggleDictation: (() -> Void)?
    public var onOpenDashboard: (() -> Void)?

    public init() {}

    public func show() {
        if panel == nil {
            buildPanel()
        }
        update()
        panel?.orderFrontRegardless()
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    public func setDictating(_ dictating: Bool, partialText: String = "") {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            CapsuleViewModel.shared.isDictating = dictating
            CapsuleViewModel.shared.liveTranscript = partialText
        }
    }

    private func buildPanel() {
        let width: CGFloat = 480
        let height: CGFloat = 38

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.isMovableByWindowBackground = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        self.panel = panel
        reposition()
    }

    private func update() {
        guard let panel else { return }

        if hostingView == nil {
            let view = CapsuleWidgetView(
                onToggleDictation: { [weak self] in self?.onToggleDictation?() },
                onOpenDashboard: { [weak self] in self?.onOpenDashboard?() }
            )
            let hosting = NSHostingView(rootView: view)
            hosting.wantsLayer = true
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentView = hosting
            self.hostingView = hosting
        }

        reposition()
    }

    public func reposition() {
        guard let panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame

        let width: CGFloat = 480
        let height: CGFloat = 38

        let x = screenFrame.midX - (width / 2.0)
        let y = screenFrame.minY + 20

        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
