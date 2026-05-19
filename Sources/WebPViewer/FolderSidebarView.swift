import Cocoa

protocol FolderSidebarDelegate: AnyObject {
    func folderSidebar(_ sidebar: FolderSidebarView, didSelectFolder url: URL)
}

final class FolderSidebarView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    weak var delegate: FolderSidebarDelegate?

    private let scrollView = NSScrollView()
    private let outlineView = NSOutlineView()
    private let addButton = NSButton()
    private var rootNodes: [FolderNode] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.13, alpha: 1.0).cgColor

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true
        addSubview(scrollView)

        outlineView.headerView = nil
        outlineView.allowsMultipleSelection = false
        outlineView.allowsEmptySelection = true
        outlineView.indentationPerLevel = 14
        outlineView.rowSizeStyle = .small
        outlineView.backgroundColor = .clear
        outlineView.gridStyleMask = []
        outlineView.usesAlternatingRowBackgroundColors = false
        outlineView.selectionHighlightStyle = .regular
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.menu = makeContextMenu()

        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.minWidth = 80
        col.title = ""
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.target = self
        outlineView.action = #selector(handleClick(_:))
        scrollView.documentView = outlineView

        // "+ Add Folder…" button anchored to the bottom of the sidebar.
        addButton.attributedTitle = NSAttributedString(
            string: "  +  Add Folder…",
            attributes: [
                .foregroundColor: NSColor(white: 0.78, alpha: 1.0),
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            ]
        )
        addButton.bezelStyle = .smallSquare
        addButton.isBordered = false
        addButton.alignment = .left
        addButton.focusRingType = .none
        addButton.target = self
        addButton.action = #selector(addFolderClicked(_:))
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: addButton.topAnchor, constant: -4),

            addButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            addButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            addButton.heightAnchor.constraint(equalToConstant: 26),
        ])

        // Right-edge hairline separator
        let line = NSView()
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor(white: 0.0, alpha: 1.0).cgColor
        line.translatesAutoresizingMaskIntoConstraints = false
        addSubview(line)
        NSLayoutConstraint.activate([
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.topAnchor.constraint(equalTo: topAnchor),
            line.bottomAnchor.constraint(equalTo: bottomAnchor),
            line.widthAnchor.constraint(equalToConstant: 1),
        ])

        loadRoots()
        outlineView.reloadData()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let item = menu.addItem(
            withTitle: "Remove from Sidebar",
            action: #selector(removeBookmarkClicked(_:)),
            keyEquivalent: ""
        )
        item.target = self
        return menu
    }

    @objc private func addFolderClicked(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder to add to the sidebar."
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if BookmarkManager.shared.add(url) {
            loadRoots()
            outlineView.reloadData()
        }
    }

    @objc private func removeBookmarkClicked(_ sender: Any?) {
        let row = outlineView.clickedRow
        guard row >= 0, let node = outlineView.item(atRow: row) as? FolderNode else { return }
        // Only allow removing user-added bookmarks (not the built-in Pictures/Downloads).
        guard BookmarkManager.shared.folders.contains(node.url) else {
            NSSound.beep(); return
        }
        BookmarkManager.shared.remove(node.url)
        loadRoots()
        outlineView.reloadData()
    }

    private func loadRoots() {
        // Inside App Sandbox, FileManager.homeDirectoryForCurrentUser, NSHomeDirectory(),
        // and NSHomeDirectoryForUser() all return the *container* home
        // (~/Library/Containers/<bundle-id>/Data/...). getpwuid bypasses that.
        var realHomePath = NSHomeDirectory()
        if let pw = getpwuid(getuid()) {
            realHomePath = String(cString: pw.pointee.pw_dir)
        }
        let home = URL(fileURLWithPath: realHomePath)
        // Only show folders the sandbox can actually enumerate:
        //   - Pictures / Downloads via entitlements
        //   - everything else the user has explicitly granted via NSOpenPanel
        var urls: [URL] = [
            home.appendingPathComponent("Pictures"),
            home.appendingPathComponent("Downloads"),
        ]
        for url in BookmarkManager.shared.folders where !urls.contains(url) {
            urls.append(url)
        }
        rootNodes = urls.map { FolderNode(url: $0) }
    }

    /// Highlight a folder URL in the tree (called by controller when image loads).
    func reveal(folder url: URL) {
        // Find a root containing this URL; expand path; select row.
        for (i, root) in rootNodes.enumerated() {
            if url == root.url || url.path.hasPrefix(root.url.path + "/") {
                expandAndSelect(target: url, under: root, rowHint: i)
                return
            }
        }
        outlineView.deselectAll(nil)
    }

    private func expandAndSelect(target: URL, under root: FolderNode, rowHint: Int) {
        // Walk down from root to target, expanding nodes along the way.
        var current = root
        let rootPath = root.url.path
        let relative = target.path.hasPrefix(rootPath) ? String(target.path.dropFirst(rootPath.count)) : ""
        let parts = relative.split(separator: "/").map(String.init)

        outlineView.expandItem(current)
        for part in parts {
            current.loadChildrenIfNeeded()
            guard let next = current.children?.first(where: { $0.url.lastPathComponent == part }) else {
                break
            }
            outlineView.expandItem(next)
            current = next
            if current.url == target { break }
        }
        let row = outlineView.row(forItem: current)
        if row >= 0 {
            outlineView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            outlineView.scrollRowToVisible(row)
        }
    }

    // MARK: - NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return rootNodes.count }
        guard let node = item as? FolderNode else { return 0 }
        node.loadChildrenIfNeeded()
        return node.children?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return rootNodes[index] }
        let node = item as! FolderNode
        node.loadChildrenIfNeeded()
        return node.children![index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FolderNode else { return false }
        node.loadChildrenIfNeeded()
        return (node.children?.count ?? 0) > 0
    }

    // MARK: - NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        let node = item as! FolderNode
        let id = NSUserInterfaceItemIdentifier("FolderCell")
        let view: NSTableCellView
        if let reused = outlineView.makeView(withIdentifier: id, owner: self) as? NSTableCellView {
            view = reused
        } else {
            view = NSTableCellView()
            view.identifier = id

            let iv = NSImageView()
            iv.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(iv)
            view.imageView = iv

            let tf = NSTextField(labelWithString: "")
            tf.font = NSFont.systemFont(ofSize: 12)
            tf.textColor = NSColor(white: 0.9, alpha: 1.0)
            tf.lineBreakMode = .byTruncatingMiddle
            tf.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(tf)
            view.textField = tf

            NSLayoutConstraint.activate([
                iv.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                iv.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                iv.widthAnchor.constraint(equalToConstant: 16),
                iv.heightAnchor.constraint(equalToConstant: 16),
                tf.leadingAnchor.constraint(equalTo: iv.trailingAnchor, constant: 6),
                tf.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -4),
                tf.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }
        view.imageView?.image = node.icon
        view.textField?.stringValue = node.name
        return view
    }

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        return 22
    }

    @objc private func handleClick(_ sender: NSOutlineView) {
        let row = sender.clickedRow
        guard row >= 0, let node = sender.item(atRow: row) as? FolderNode else { return }
        delegate?.folderSidebar(self, didSelectFolder: node.url)
    }
}

final class FolderNode {
    let url: URL
    var children: [FolderNode]?
    private var didLoad = false

    init(url: URL) {
        self.url = url
    }

    var name: String {
        return FileManager.default.displayName(atPath: url.path)
    }

    var icon: NSImage {
        let img = NSWorkspace.shared.icon(forFile: url.path)
        img.size = NSSize(width: 16, height: 16)
        return img
    }

    func loadChildrenIfNeeded() {
        if didLoad { return }
        didLoad = true
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            children = []
            return
        }
        // Keep only regular directories. Bundles / packages
        // (.app, .photoslibrary, .musiclibrary, …) are technically directories
        // but the user thinks of them as files — hide them from the tree.
        let dirs = contents.filter { url in
            guard let v = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey]) else {
                return false
            }
            return v.isDirectory == true && v.isPackage != true
        }
        children = dirs
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { FolderNode(url: $0) }
    }
}
