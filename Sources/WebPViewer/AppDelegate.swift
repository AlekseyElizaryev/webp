import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: ImageWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()
        if windowController == nil {
            windowController = ImageWindowController()
            windowController.showWindow(nil)
            windowController.window?.center()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        if windowController == nil {
            windowController = ImageWindowController()
            windowController.showWindow(nil)
        }
        windowController.load(url: first)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["webp", "png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "heic"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            windowController.load(url: url)
        }
    }

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About WebPViewer",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide WebPViewer",
                        action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit WebPViewer",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…",
                         action: #selector(openDocument(_:)),
                         keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Close",
                         action: #selector(NSWindow.performClose(_:)),
                         keyEquivalent: "w")
        fileItem.submenu = fileMenu

        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        let sidebarItem = NSMenuItem(
            title: "Toggle Sidebar",
            action: #selector(ImageWindowController.toggleSidebar(_:)),
            keyEquivalent: "s"
        )
        sidebarItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(sidebarItem)
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Next",
                         action: #selector(ImageWindowController.next(_:)),
                         keyEquivalent: String(utf16CodeUnits: [unichar(NSRightArrowFunctionKey)], count: 1))
        viewMenu.addItem(withTitle: "Previous",
                         action: #selector(ImageWindowController.previous(_:)),
                         keyEquivalent: String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1))
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Actual Size",
                         action: #selector(ImageWindowController.actualSize(_:)),
                         keyEquivalent: "0")
        viewMenu.addItem(withTitle: "Fit to Window",
                         action: #selector(ImageWindowController.fitToWindow(_:)),
                         keyEquivalent: "f")
        viewMenu.addItem(withTitle: "Zoom In",
                         action: #selector(ImageWindowController.zoomIn(_:)),
                         keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Zoom Out",
                         action: #selector(ImageWindowController.zoomOut(_:)),
                         keyEquivalent: "-")
        viewItem.submenu = viewMenu

        NSApp.mainMenu = mainMenu
    }
}
