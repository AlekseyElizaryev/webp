import Cocoa

final class ImageWindowController: NSWindowController, NSWindowDelegate,
    ThumbnailStripDelegate, FolderSidebarDelegate {
    private let scrollView = NSScrollView()
    private let imageContainer = NSView()
    private let imageView = NSImageView()
    private let toolbar = ToolbarView()
    private let thumbStrip = ThumbnailStripView()
    private let sidebar = FolderSidebarView()
    private let statusLabel = NSTextField(labelWithString: "")
    private var dropView: DropView!

    private var originalImage: NSImage?
    private var currentURL: URL?
    private var siblings: [URL] = []
    private var siblingIndex: Int = 0
    private var zoom: CGFloat = 1.0
    private var fitMode: Bool = true
    private var rotationDegrees: CGFloat = 0

    private var sidebarVisible: Bool = true
    private let sidebarWidth: CGFloat = 220
    private var keyMonitor: Any?

    static let supportedExts: Set<String> = [
        "webp", "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic",
    ]

    private let toolbarHeight: CGFloat = 44
    private let statusHeight: CGFloat = 22
    private let stripHeight: CGFloat = 92

    convenience init() {
        let style: NSWindow.StyleMask = [
            .titled, .closable, .resizable, .miniaturizable, .fullSizeContentView,
        ]
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = "WebPViewer"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(white: 0.10, alpha: 1.0)
        window.minSize = NSSize(width: 600, height: 420)
        window.collectionBehavior.insert(.fullScreenPrimary)

        self.init(window: window)
        window.delegate = self
        setupLayout()
        installKeyMonitor()
        showPlaceholder()
    }

    deinit {
        if let m = keyMonitor { NSEvent.removeMonitor(m) }
    }

    private func installKeyMonitor() {
        // Catches arrow keys / space regardless of which view holds first responder
        // (the sidebar's outline view would otherwise eat ←/→ for collapse/expand).
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            return self.handleGlobalKeyDown(event) ? nil : event
        }
    }

    /// Returns true when the event was consumed.
    private func handleGlobalKeyDown(_ event: NSEvent) -> Bool {
        // Only handle events targeted at our window.
        guard event.window === self.window else { return false }
        // Skip when typing in a text input.
        if let responder = self.window?.firstResponder, responder is NSText { return false }
        // If no image is loaded yet, let other views handle keys normally.
        if siblings.isEmpty { return false }
        // Ignore key combos that include a modifier — those are menu shortcuts.
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let interesting: NSEvent.ModifierFlags = [.command, .option, .control]
        if !mods.intersection(interesting).isEmpty { return false }

        switch Int(event.keyCode) {
        case 123, 126:  // ←, ↑
            previous(nil); return true
        case 124, 125:  // →, ↓
            next(nil); return true
        case 49:        // space
            fitToWindow(nil); return true
        case 115:       // Home — first image
            if !siblings.isEmpty {
                _ = loadCore(url: siblings[0], recomputeSiblings: false, revealInSidebar: false)
            }
            return true
        case 119:       // End — last image
            if let last = siblings.last {
                _ = loadCore(url: last, recomputeSiblings: false, revealInSidebar: false)
            }
            return true
        default:
            return false
        }
    }

    private func setupLayout() {
        guard let window = window else { return }
        dropView = DropView(frame: NSRect(origin: .zero, size: window.frame.size))
        dropView.onDrop = { [weak self] url in self?.load(url: url) }
        dropView.controller = self
        dropView.autoresizingMask = [.width, .height]
        window.contentView = dropView

        let W = dropView.bounds.width
        let H = dropView.bounds.height

        // Toolbar on top
        toolbar.frame = NSRect(x: 0, y: H - toolbarHeight, width: W, height: toolbarHeight)
        toolbar.autoresizingMask = [.width, .minYMargin]
        toolbar.onAction = { [weak self] in self?.handleToolbarAction($0) }
        dropView.addSubview(toolbar)

        // Thumbnail strip on bottom
        thumbStrip.frame = NSRect(x: 0, y: 0, width: W, height: stripHeight)
        thumbStrip.autoresizingMask = [.width, .maxYMargin]
        thumbStrip.delegate = self
        dropView.addSubview(thumbStrip)

        // Status label between image area and strip
        statusLabel.frame = NSRect(x: 12, y: stripHeight, width: W - 24, height: statusHeight)
        statusLabel.autoresizingMask = [.width, .maxYMargin]
        statusLabel.font = NSFont.systemFont(ofSize: 11)
        statusLabel.textColor = NSColor(white: 0.65, alpha: 1.0)
        statusLabel.alignment = .center
        statusLabel.drawsBackground = false
        statusLabel.isBezeled = false
        statusLabel.isEditable = false
        statusLabel.lineBreakMode = .byTruncatingMiddle
        dropView.addSubview(statusLabel)

        // Folder sidebar on the left (visible by default)
        let scrollY = stripHeight + statusHeight
        let middleH = H - toolbarHeight - scrollY
        let initialSidebarW = sidebarVisible ? sidebarWidth : 0
        sidebar.frame = NSRect(x: 0, y: scrollY, width: initialSidebarW, height: middleH)
        sidebar.autoresizingMask = [.height]
        sidebar.isHidden = !sidebarVisible
        sidebar.delegate = self
        dropView.addSubview(sidebar)

        // Image area (scroll view) in the middle, right of sidebar
        scrollView.frame = NSRect(x: initialSidebarW, y: scrollY, width: W - initialSidebarW, height: middleH)
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(white: 0.06, alpha: 1.0)
        dropView.addSubview(scrollView)

        imageContainer.frame = scrollView.bounds
        scrollView.documentView = imageContainer

        imageView.imageScaling = .scaleAxesIndependently
        imageView.imageAlignment = .alignCenter
        imageContainer.addSubview(imageView)

        window.makeFirstResponder(dropView)
    }

    // MARK: - Sidebar toggle

    @objc func toggleSidebar(_ sender: Any?) {
        sidebarVisible.toggle()
        let targetWidth: CGFloat = sidebarVisible ? sidebarWidth : 0
        let scrollY = stripHeight + statusHeight
        let middleH = dropView.bounds.height - toolbarHeight - scrollY

        if sidebarVisible { sidebar.isHidden = false }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.18
            ctx.allowsImplicitAnimation = true
            sidebar.animator().frame = NSRect(x: 0, y: scrollY, width: targetWidth, height: middleH)
            scrollView.animator().frame = NSRect(
                x: targetWidth, y: scrollY,
                width: dropView.bounds.width - targetWidth, height: middleH
            )
        }, completionHandler: { [weak self] in
            guard let self = self else { return }
            if !self.sidebarVisible { self.sidebar.isHidden = true }
            self.applyZoom()
            if let url = self.currentURL, self.sidebarVisible {
                self.sidebar.reveal(folder: url.deletingLastPathComponent())
            }
        })
    }

    // MARK: - FolderSidebarDelegate

    func folderSidebar(_ sidebar: FolderSidebarView, didSelectFolder url: URL) {
        let images = listImages(in: url)
        if let first = images.first {
            // User explicitly clicked this folder in the sidebar — no need to
            // re-reveal/re-expand it (that's what was causing the scroll jump).
            if !loadCore(url: first, recomputeSiblings: true, revealInSidebar: false) {
                NSSound.beep()
            }
        } else {
            // Folder has no images — clear main area, keep sidebar
            siblings = []
            siblingIndex = 0
            currentURL = url
            originalImage = nil
            imageView.image = nil
            window?.title = url.lastPathComponent
            thumbStrip.setURLs([], selectedIndex: 0)
            statusLabel.stringValue = "\(url.lastPathComponent) · no images"
        }
    }

    private func listImages(in dir: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        return contents
            .filter { Self.supportedExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    private func showPlaceholder() {
        statusLabel.stringValue = "Drop a WebP here or press ⌘O"
        imageView.image = nil
        originalImage = nil
    }

    // MARK: - Loading

    /// Public entry: open a file picked by user / dropped / passed from Finder.
    /// Rescans the parent folder and refreshes the thumbnail strip.
    func load(url: URL) {
        if !loadCore(url: url, recomputeSiblings: true) {
            NSSound.beep()
        }
    }

    @discardableResult
    private func loadCore(url: URL, recomputeSiblings: Bool, revealInSidebar: Bool = true) -> Bool {
        guard let image = ImageLoader.load(url: url) else { return false }
        originalImage = image
        currentURL = url
        rotationDegrees = 0
        zoom = 1.0
        fitMode = true
        imageView.image = image
        applyZoom()
        window?.title = url.lastPathComponent

        if recomputeSiblings {
            updateSiblings(for: url)
            thumbStrip.setURLs(siblings, selectedIndex: siblingIndex)
        } else {
            siblingIndex = siblings.firstIndex(of: url) ?? siblingIndex
            thumbStrip.setSelectedIndex(siblingIndex)
        }
        if sidebarVisible && revealInSidebar {
            sidebar.reveal(folder: url.deletingLastPathComponent())
        }
        updateStatus()
        return true
    }

    private func updateSiblings(for url: URL) {
        let dir = url.deletingLastPathComponent()
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        )) ?? []
        siblings = contents
            .filter { Self.supportedExts.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        siblingIndex = siblings.firstIndex(of: url) ?? 0
    }

    private func updateStatus() {
        guard let url = currentURL, let image = originalImage else {
            statusLabel.stringValue = ""
            return
        }
        let attr = try? FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attr?[.size] as? Int) ?? 0
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
        let w = Int(image.size.width), h = Int(image.size.height)
        let idx = siblingIndex + 1
        let total = max(siblings.count, 1)
        statusLabel.stringValue = "\(url.lastPathComponent)  ·  \(w)×\(h)  ·  \(sizeStr)  ·  \(idx)/\(total)"
    }

    // MARK: - ThumbnailStripDelegate

    func thumbnailStrip(_ strip: ThumbnailStripView, didSelect index: Int) {
        guard index >= 0, index < siblings.count else { return }
        if !loadCore(url: siblings[index], recomputeSiblings: false, revealInSidebar: false) {
            NSSound.beep()
        }
    }

    // MARK: - Toolbar handling

    private func handleToolbarAction(_ action: ToolbarView.Action) {
        switch action {
        case .toggleSidebar: toggleSidebar(nil)
        case .previous: previous(nil)
        case .next: next(nil)
        case .rotateLeft: rotate(by: -90)
        case .rotateRight: rotate(by: 90)
        case .zoomIn: zoomIn(nil)
        case .zoomOut: zoomOut(nil)
        case .fit: fitToWindow(nil)
        case .actualSize: actualSize(nil)
        case .toggleFullScreen: window?.toggleFullScreen(nil)
        }
    }

    // MARK: - Navigation

    @objc func next(_ sender: Any?) { step(by: +1) }
    @objc func previous(_ sender: Any?) { step(by: -1) }

    private func step(by delta: Int) {
        guard !siblings.isEmpty else { return }
        let n = siblings.count
        var idx = siblingIndex
        for _ in 0..<n {
            idx = ((idx + delta) % n + n) % n
            if loadCore(url: siblings[idx], recomputeSiblings: false, revealInSidebar: false) {
                return
            }
        }
        NSSound.beep()
    }

    // MARK: - Zoom & Rotate

    @objc func actualSize(_ sender: Any?) { fitMode = false; zoom = 1.0; applyZoom() }
    @objc func fitToWindow(_ sender: Any?) { fitMode = true; applyZoom() }
    @objc func zoomIn(_ sender: Any?) { fitMode = false; zoom = min(zoom * 1.25, 16.0); applyZoom() }
    @objc func zoomOut(_ sender: Any?) { fitMode = false; zoom = max(zoom / 1.25, 0.05); applyZoom() }

    private func rotate(by degrees: CGFloat) {
        rotationDegrees = (rotationDegrees + degrees).truncatingRemainder(dividingBy: 360)
        if rotationDegrees < 0 { rotationDegrees += 360 }
        applyRotationAndZoom()
    }

    private func applyRotationAndZoom() {
        guard let original = originalImage else { return }
        let displayed = rotationDegrees == 0 ? original : original.rotated(byDegrees: rotationDegrees)
        imageView.image = displayed
        applyZoom()
    }

    private func applyZoom() {
        guard let image = imageView.image else { return }
        let imageSize = image.size
        let visible = scrollView.contentView.bounds.size
        guard imageSize.width > 0, imageSize.height > 0, visible.width > 0, visible.height > 0 else { return }
        let targetZoom: CGFloat
        if fitMode {
            targetZoom = min(visible.width / imageSize.width, visible.height / imageSize.height, 1.0)
        } else {
            targetZoom = zoom
        }
        let newSize = NSSize(width: imageSize.width * targetZoom,
                             height: imageSize.height * targetZoom)
        let docSize = NSSize(
            width: max(visible.width, newSize.width),
            height: max(visible.height, newSize.height)
        )
        imageContainer.frame = NSRect(origin: .zero, size: docSize)
        imageView.frame = NSRect(
            x: (docSize.width - newSize.width) / 2,
            y: (docSize.height - newSize.height) / 2,
            width: newSize.width,
            height: newSize.height
        )
    }

    // MARK: - Window delegate

    func windowDidResize(_ notification: Notification) {
        if fitMode { applyZoom() }
    }
}

// MARK: - Drop view (key handling and drag-and-drop)

final class DropView: NSView {
    var onDrop: ((URL) -> Void)?
    weak var controller: ImageWindowController?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.10, alpha: 1.0).cgColor
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
              let first = urls.first else { return false }
        onDrop?(first)
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 124: controller?.next(nil)        // →
        case 123: controller?.previous(nil)    // ←
        case 49:  controller?.fitToWindow(nil) // space
        default:  super.keyDown(with: event)
        }
    }
}

// MARK: - NSImage rotation

extension NSImage {
    func rotated(byDegrees degrees: CGFloat) -> NSImage {
        let radians = degrees * .pi / 180
        let cosA = abs(cos(radians))
        let sinA = abs(sin(radians))
        let newSize = NSSize(
            width:  size.width  * cosA + size.height * sinA,
            height: size.width  * sinA + size.height * cosA
        )
        let img = NSImage(size: newSize)
        img.lockFocus()
        let xform = NSAffineTransform()
        xform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        xform.rotate(byDegrees: degrees)
        xform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        xform.concat()
        draw(at: .zero,
             from: NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1.0)
        img.unlockFocus()
        return img
    }
}
