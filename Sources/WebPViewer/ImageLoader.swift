import Cocoa

enum ImageLoader {
    static func load(url: URL) -> NSImage? {
        if url.pathExtension.lowercased() == "webp" {
            guard let data = try? Data(contentsOf: url) else { return nil }
            return WebPDecoder.decode(data: data)
        }
        return NSImage(contentsOf: url)
    }
}
