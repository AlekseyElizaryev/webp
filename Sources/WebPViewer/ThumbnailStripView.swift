import Cocoa

protocol ThumbnailStripDelegate: AnyObject {
    func thumbnailStrip(_ strip: ThumbnailStripView, didSelect index: Int)
}

final class ThumbnailStripView: NSView {
    weak var delegate: ThumbnailStripDelegate?

    private let scrollView = NSScrollView()
    private let stack = NSStackView()
    private var cells: [ThumbnailCell] = []
    private(set) var selectedIndex: Int = 0

    private var thumbCache: [URL: NSImage] = [:]
    private let loadQueue = DispatchQueue(label: "thumbs.load", qos: .utility, attributes: .concurrent)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 1.0).cgColor

        // top hairline
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(white: 0.0, alpha: 1.0).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: topAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
        ])

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.usesPredominantAxisScrolling = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
        ])

        stack.orientation = .horizontal
        stack.spacing = 4
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false
        let flipped = FlippedClipView()
        flipped.translatesAutoresizingMaskIntoConstraints = false
        flipped.drawsBackground = false
        scrollView.contentView = flipped
        scrollView.documentView = stack
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: flipped.leadingAnchor),
            stack.topAnchor.constraint(equalTo: flipped.topAnchor),
            stack.bottomAnchor.constraint(equalTo: flipped.bottomAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    func setURLs(_ urls: [URL], selectedIndex: Int) {
        cells.forEach { $0.removeFromSuperview() }
        cells.removeAll()
        for (idx, url) in urls.enumerated() {
            let cell = ThumbnailCell(url: url)
            cell.image = thumbCache[url]
            cell.isSelected = (idx == selectedIndex)
            cell.onClick = { [weak self] in
                guard let self = self else { return }
                self.delegate?.thumbnailStrip(self, didSelect: idx)
            }
            cells.append(cell)
            stack.addArrangedSubview(cell)
        }
        self.selectedIndex = selectedIndex
        loadMissingThumbnails(urls: urls)
        DispatchQueue.main.async { [weak self] in self?.scrollToSelected(animated: false) }
    }

    func setSelectedIndex(_ index: Int) {
        guard index >= 0, index < cells.count else { return }
        if selectedIndex < cells.count { cells[selectedIndex].isSelected = false }
        selectedIndex = index
        cells[index].isSelected = true
        scrollToSelected(animated: true)
    }

    private func scrollToSelected(animated: Bool) {
        guard selectedIndex < cells.count else { return }
        let cell = cells[selectedIndex]
        let cellFrame = cell.convert(cell.bounds, to: stack)
        let visibleWidth = scrollView.contentView.bounds.width
        let targetX = max(0, cellFrame.midX - visibleWidth / 2)
        let clip = scrollView.contentView
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                clip.animator().setBoundsOrigin(NSPoint(x: targetX, y: 0))
            }
        } else {
            clip.scroll(to: NSPoint(x: targetX, y: 0))
        }
        scrollView.reflectScrolledClipView(clip)
    }

    private func loadMissingThumbnails(urls: [URL]) {
        for (idx, url) in urls.enumerated() {
            if thumbCache[url] != nil { continue }
            loadQueue.async { [weak self] in
                guard let image = ImageLoader.load(url: url) else { return }
                let thumb = image.thumbnail(maxDim: 72)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.thumbCache[url] = thumb
                    if idx < self.cells.count, self.cells[idx].url == url {
                        self.cells[idx].image = thumb
                    }
                }
            }
        }
    }
}

private final class FlippedClipView: NSClipView {
    override var isFlipped: Bool { false }
}

final class ThumbnailCell: NSView {
    let url: URL
    var onClick: (() -> Void)?
    var isSelected: Bool = false { didSet { needsDisplay = true } }

    private let imageView = NSImageView()

    var image: NSImage? {
        didSet { imageView.image = image }
    }

    init(url: URL) {
        self.url = url
        super.init(frame: NSRect(x: 0, y: 0, width: 80, height: 80))
        wantsLayer = true
        layer?.cornerRadius = 4
        layer?.backgroundColor = NSColor(white: 0.14, alpha: 1.0).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 80).isActive = true
        heightAnchor.constraint(equalToConstant: 80).isActive = true

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 3),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -3),
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -3),
        ])

        // Fallback: system file icon. Overwritten by thumbnail when it finishes loading.
        imageView.image = NSWorkspace.shared.icon(forFile: url.path)
        toolTip = url.lastPathComponent
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isSelected {
            NSColor.controlAccentColor.setStroke()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            path.lineWidth = 2
            path.stroke()
        }
    }
}

extension NSImage {
    /// Thread-safe scaled copy. Uses CGContext (no AppKit lockFocus, so safe off main).
    func thumbnail(maxDim: CGFloat) -> NSImage {
        let aspect = size.width / max(size.height, 1)
        let target: NSSize = aspect > 1
            ? NSSize(width: maxDim, height: maxDim / aspect)
            : NSSize(width: maxDim * aspect, height: maxDim)
        guard let cg = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return self
        }
        let w = max(1, Int(target.width.rounded()))
        let h = max(1, Int(target.height.rounded()))
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return self }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let scaled = ctx.makeImage() else { return self }
        return NSImage(cgImage: scaled, size: target)
    }
}
