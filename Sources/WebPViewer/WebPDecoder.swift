import Cocoa
import libwebp

enum WebPDecoder {
    static func decode(data: Data) -> NSImage? {
        var width: Int32 = 0
        var height: Int32 = 0
        let count = data.count

        let pixelsPtr: UnsafeMutablePointer<UInt8>? = data.withUnsafeBytes { raw -> UnsafeMutablePointer<UInt8>? in
            guard let base = raw.bindMemory(to: UInt8.self).baseAddress else { return nil }
            return WebPDecodeRGBA(base, count, &width, &height)
        }
        guard let pixels = pixelsPtr, width > 0, height > 0 else { return nil }

        let byteCount = Int(width) * Int(height) * 4
        guard let provider = CGDataProvider(
            dataInfo: pixels,
            data: pixels,
            size: byteCount,
            releaseData: { _, ptr, _ in
                WebPFree(UnsafeMutableRawPointer(mutating: ptr))
            }
        ) else {
            WebPFree(pixels)
            return nil
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue)
        guard let cg = CGImage(
            width: Int(width),
            height: Int(height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(width) * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }

        return NSImage(cgImage: cg, size: NSSize(width: Int(width), height: Int(height)))
    }
}
