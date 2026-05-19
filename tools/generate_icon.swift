#!/usr/bin/env swift
import Foundation
import AppKit

// Generates an .iconset folder ready for `iconutil -c icns`.
// Usage: generate_icon.swift <output_dir>

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("Usage: generate_icon.swift <output_dir>\n".data(using: .utf8)!)
    exit(1)
}
let outDir = CommandLine.arguments[1]

let masterSize = 1024
let master = NSImage(size: NSSize(width: masterSize, height: masterSize))
master.lockFocus()

let rect = NSRect(x: 0, y: 0, width: masterSize, height: masterSize)
// Apple's macOS squircle approximation
let cornerRadius = CGFloat(masterSize) * 0.2237
let bg = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
bg.addClip()

let topLeft = NSColor(red: 0.30, green: 0.81, blue: 0.88, alpha: 1.0)
let bottomRight = NSColor(red: 0.10, green: 0.46, blue: 0.82, alpha: 1.0)
let gradient = NSGradient(colors: [topLeft, bottomRight])!
gradient.draw(in: rect, angle: -45)

let text = "WP"
let font = NSFont.systemFont(ofSize: 460, weight: .heavy)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
    .kern: -20.0,
]
let textSize = (text as NSString).size(withAttributes: attrs)
let textRect = NSRect(
    x: (CGFloat(masterSize) - textSize.width) / 2,
    y: (CGFloat(masterSize) - textSize.height) / 2 - 30,
    width: textSize.width,
    height: textSize.height
)
(text as NSString).draw(in: textRect, withAttributes: attrs)

master.unlockFocus()

guard let masterCG = master.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("Failed to render master image\n".data(using: .utf8)!)
    exit(1)
}

let fm = FileManager.default
let iconsetDir = (outDir as NSString).appendingPathComponent("WebPViewer.iconset")
try? fm.removeItem(atPath: iconsetDir)
try! fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, px) in sizes {
    guard let ctx = CGContext(
        data: nil, width: px, height: px,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { continue }
    ctx.interpolationQuality = .high
    ctx.draw(masterCG, in: CGRect(x: 0, y: 0, width: px, height: px))
    guard let scaled = ctx.makeImage() else { continue }
    let rep = NSBitmapImageRep(cgImage: scaled)
    let data = rep.representation(using: .png, properties: [:])!
    let path = (iconsetDir as NSString).appendingPathComponent(name)
    try! data.write(to: URL(fileURLWithPath: path))
}

print("Wrote \(iconsetDir)")
