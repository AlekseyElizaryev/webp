import Foundation

/// Stores security-scoped bookmarks for folders the user has granted access to,
/// so the sandboxed app can re-access them across launches.
final class BookmarkManager {
    static let shared = BookmarkManager()

    private let key = "BookmarkedFolders"
    private(set) var folders: [URL] = []

    private init() { load() }

    private func load() {
        folders = []
        guard let stored = UserDefaults.standard.array(forKey: key) as? [Data] else { return }
        for data in stored {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: data,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                if url.startAccessingSecurityScopedResource() {
                    folders.append(url)
                }
            } catch {
                NSLog("WebPViewer: failed to resolve bookmark: %@", error.localizedDescription)
            }
        }
    }

    /// Save a security-scoped bookmark for `url` and start accessing it.
    /// Returns false if creating the bookmark failed.
    @discardableResult
    func add(_ url: URL) -> Bool {
        if folders.contains(url) { return true }
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            var stored = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
            stored.append(data)
            UserDefaults.standard.set(stored, forKey: key)
            _ = url.startAccessingSecurityScopedResource()
            folders.append(url)
            return true
        } catch {
            NSLog("WebPViewer: failed to create bookmark: %@", error.localizedDescription)
            return false
        }
    }

    func remove(_ url: URL) {
        guard let idx = folders.firstIndex(of: url) else { return }
        folders[idx].stopAccessingSecurityScopedResource()
        folders.remove(at: idx)
        var stored = UserDefaults.standard.array(forKey: key) as? [Data] ?? []
        if idx < stored.count {
            stored.remove(at: idx)
            UserDefaults.standard.set(stored, forKey: key)
        }
    }
}
