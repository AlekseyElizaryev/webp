import Cocoa

final class ToolbarView: NSView {
    enum Action: String {
        case toggleSidebar
        case previous, next
        case rotateLeft, rotateRight
        case zoomOut, zoomIn, fit, actualSize
        case toggleFullScreen
    }

    var onAction: ((Action) -> Void)?

    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.10, alpha: 1.0).cgColor

        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        // left inset = 80 reserves space for window traffic-light buttons
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 80, bottom: 6, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        addButton("☰", tip: "Toggle Sidebar (⌥⌘S)", action: .toggleSidebar)
        addSeparator()
        addButton("◀", tip: "Previous (←)", action: .previous)
        addButton("▶", tip: "Next (→)", action: .next)
        addSeparator()
        addButton("↺", tip: "Rotate Left", action: .rotateLeft)
        addButton("↻", tip: "Rotate Right", action: .rotateRight)
        addSeparator()
        addButton("−", tip: "Zoom Out (⌘−)", action: .zoomOut)
        addButton("+", tip: "Zoom In (⌘+)", action: .zoomIn)
        addButton("Fit", tip: "Fit (Space)", action: .fit)
        addButton("1:1", tip: "Actual Size (⌘0)", action: .actualSize)
        addSeparator()
        addButton("⤢", tip: "Full Screen (⌃⌘F)", action: .toggleFullScreen)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.addArrangedSubview(spacer)

        // bottom hairline
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(white: 0.0, alpha: 1.0).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    private func addButton(_ title: String, tip: String, action: Action) {
        let b = ToolbarButton(title: title)
        b.toolTip = tip
        b.target = self
        b.action = #selector(handle(_:))
        b.identifier = NSUserInterfaceItemIdentifier(rawValue: action.rawValue)
        stack.addArrangedSubview(b)
    }

    private func addSeparator() {
        let sep = NSView()
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor(white: 0.28, alpha: 1.0).cgColor
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.widthAnchor.constraint(equalToConstant: 1).isActive = true
        sep.heightAnchor.constraint(equalToConstant: 22).isActive = true
        stack.addArrangedSubview(sep)
    }

    @objc private func handle(_ sender: NSButton) {
        guard let raw = sender.identifier?.rawValue, let action = Action(rawValue: raw) else { return }
        onAction?(action)
        if let win = window, let cv = win.contentView {
            win.makeFirstResponder(cv)
        }
    }
}

final class ToolbarButton: NSButton {
    private var trackingArea: NSTrackingArea?

    init(title: String) {
        super.init(frame: .zero)
        self.isBordered = false
        self.bezelStyle = .smallSquare
        self.focusRingType = .none
        self.wantsLayer = true
        self.layer?.cornerRadius = 4
        self.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: NSColor(white: 0.92, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            ]
        )
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 0.22, alpha: 1.0).cgColor
    }
    override func mouseExited(with event: NSEvent) {
        layer?.backgroundColor = nil
    }
}
