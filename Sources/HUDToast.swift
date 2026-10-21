import Cocoa

final class HUDToast {
    static let shared = HUDToast()

    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(title: String, subtitle: String, isWarning: Bool = false) {
        DispatchQueue.main.async {
            if AppSettings.shared.playSound {
                let soundName = isWarning ? "Basso" : "Tink"
                if let sound = NSSound(named: NSSound.Name(soundName)) {
                    sound.play()
                }
            }

            guard AppSettings.shared.showHUD else { return }

            self.dismissWorkItem?.cancel()
            self.panel?.orderOut(nil)

            let width: CGFloat = 340
            let height: CGFloat = 68

            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let originX = screenFrame.midX - (width / 2)
            let originY = screenFrame.minY + 90

            let hudPanel = NSPanel(
                contentRect: NSRect(x: originX, y: originY, width: width, height: height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            hudPanel.isOpaque = false
            hudPanel.backgroundColor = .clear
            hudPanel.level = .statusBar
            hudPanel.hasShadow = true
            hudPanel.ignoresMouseEvents = true
            hudPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            let visualEffect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: width, height: height))
            visualEffect.material = .hudWindow
            visualEffect.blendingMode = .behindWindow
            visualEffect.state = .active
            visualEffect.wantsLayer = true
            visualEffect.layer?.cornerRadius = 14
            visualEffect.layer?.masksToBounds = true

            // Icon
            let iconView = NSImageView(frame: NSRect(x: 16, y: 18, width: 32, height: 32))
            let symbolName = isWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
            if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 24, weight: .semibold)
                iconView.image = img.withSymbolConfiguration(config)
                iconView.contentTintColor = isWarning ? .systemOrange : .systemGreen
            }
            visualEffect.addSubview(iconView)

            // Title
            let titleLabel = NSTextField(labelWithString: title)
            titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .labelColor
            titleLabel.frame = NSRect(x: 58, y: 36, width: width - 72, height: 18)
            titleLabel.lineBreakMode = .byTruncatingTail
            visualEffect.addSubview(titleLabel)

            // Subtitle preview
            let cleanSubtitle = subtitle
                .replacingOccurrences(of: "\r\n", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let subLabel = NSTextField(labelWithString: cleanSubtitle)
            subLabel.font = NSFont.systemFont(ofSize: 11.5, weight: .regular)
            subLabel.textColor = .secondaryLabelColor
            subLabel.frame = NSRect(x: 58, y: 14, width: width - 72, height: 18)
            subLabel.lineBreakMode = .byTruncatingTail
            visualEffect.addSubview(subLabel)

            hudPanel.contentView = visualEffect
            hudPanel.alphaValue = 0
            hudPanel.orderFrontRegardless()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                hudPanel.animator().alphaValue = 1.0
            }

            self.panel = hudPanel

            let workItem = DispatchWorkItem { [weak self, weak hudPanel] in
                guard let hudPanel = hudPanel else { return }
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = 0.25
                    hudPanel.animator().alphaValue = 0.0
                }, completionHandler: {
                    hudPanel.orderOut(nil)
                    if self?.panel === hudPanel {
                        self?.panel = nil
                    }
                })
            }
            self.dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1, execute: workItem)
        }
    }
}
