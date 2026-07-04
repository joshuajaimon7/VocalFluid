import AppKit

/// A small floating, non-activating panel that shows the live partial
/// transcript while dictating (bottom-center of the active screen, like the
/// system dictation indicator). Never steals focus from the target app.
@MainActor
final class TranscriptHUD {
    private var panel: NSPanel?
    private var label: NSTextField?

    func show() {
        if panel == nil { build() }
        update(text: "Listening…")
        panel?.orderFrontRegardless()
    }

    func update(text: String) {
        guard let label, let panel else { return }
        label.stringValue = text.isEmpty ? "Listening…" : text
        layout(panel: panel, label: label)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func build() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient]

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 12

        let label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14)
        label.textColor = .labelColor
        label.alignment = .center
        label.lineBreakMode = .byTruncatingHead // show the most recent words
        label.maximumNumberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false

        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: effect.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -10),
        ])

        panel.contentView = effect
        self.panel = panel
        self.label = label
    }

    private func layout(panel: NSPanel, label: NSTextField) {
        guard let screen = NSScreen.main else { return }
        let maxWidth: CGFloat = min(560, screen.visibleFrame.width - 80)
        let size = label.sizeThatFits(NSSize(width: maxWidth - 32, height: 60))
        let width = min(maxWidth, max(220, size.width + 32))
        let height = size.height + 20
        let x = screen.visibleFrame.midX - width / 2
        let y = screen.visibleFrame.minY + 60
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}
