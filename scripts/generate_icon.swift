import AppKit
import CoreGraphics

func createIconImage(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    let rect = CGRect(x: 0, y: 0, width: size, height: size)
    let margin = size * 0.1
    let innerRect = rect.insetBy(dx: margin, dy: margin)
    let cornerRadius = size * 0.224

    // Clip to macOS squircle shape
    let squirclePath = CGPath(roundedRect: innerRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Base background gradient (Deep Space / Obsidian Indigo)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.07, green: 0.08, blue: 0.16, alpha: 1.0).cgColor,
        NSColor(red: 0.12, green: 0.09, blue: 0.24, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.04, blue: 0.10, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient, start: CGPoint(x: innerRect.minX, y: innerRect.maxY), end: CGPoint(x: innerRect.maxX, y: innerRect.minY), options: [])
    }

    // Inner subtle glow border
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.15).cgColor)
    ctx.setLineWidth(size * 0.012)
    ctx.addPath(squirclePath)
    ctx.strokePath()

    // Draw Vibrant Fluid Soundwave / Vocal Droplet Ribbons
    let waveColors = [
        NSColor(red: 0.18, green: 0.85, blue: 0.95, alpha: 0.9).cgColor, // Cyan
        NSColor(red: 0.45, green: 0.35, blue: 0.98, alpha: 0.95).cgColor, // Indigo/Violet
        NSColor(red: 0.98, green: 0.32, blue: 0.65, alpha: 0.9).cgColor  // Magenta
    ] as CFArray
    let waveLocations: [CGFloat] = [0.0, 0.5, 1.0]
    guard let waveGradient = CGGradient(colorsSpace: colorSpace, colors: waveColors, locations: waveLocations) else {
        ctx.restoreGState()
        image.unlockFocus()
        return image
    }

    // Draw 5 vertical fluid audio equalizer pills that form a graceful wave
    let bars: [(relX: CGFloat, relHeight: CGFloat)] = [
        (-0.24, 0.22),
        (-0.12, 0.46),
        (0.0,   0.62),
        (0.12,  0.42),
        (0.24,  0.26)
    ]

    let centerX = innerRect.midX
    let centerY = innerRect.midY
    let barWidth = size * 0.065

    for bar in bars {
        let x = centerX + (bar.relX * innerRect.width) - (barWidth / 2.0)
        let h = bar.relHeight * innerRect.height
        let y = centerY - (h / 2.0)
        let barRect = CGRect(x: x, y: y, width: barWidth, height: h)
        let barPath = CGPath(roundedRect: barRect, cornerWidth: barWidth / 2.0, cornerHeight: barWidth / 2.0, transform: nil)

        ctx.saveGState()
        // Shadow for depth
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.01), blur: size * 0.03, color: NSColor(red: 0.45, green: 0.35, blue: 0.98, alpha: 0.6).cgColor)
        ctx.addPath(barPath)
        ctx.clip()
        ctx.drawLinearGradient(waveGradient, start: CGPoint(x: x, y: y + h), end: CGPoint(x: x, y: y), options: [])
        ctx.restoreGState()
    }

    // Fluid ambient glow orb in the center
    ctx.saveGState()
    let glowColors = [
        NSColor(red: 0.25, green: 0.70, blue: 1.0, alpha: 0.25).cgColor,
        NSColor(red: 0.5, green: 0.2, blue: 0.9, alpha: 0.0).cgColor
    ] as CFArray
    if let glowGradient = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0]) {
        ctx.drawRadialGradient(glowGradient,
                               startCenter: CGPoint(x: centerX, y: centerY),
                               startRadius: 0,
                               endCenter: CGPoint(x: centerX, y: centerY),
                               endRadius: innerRect.width * 0.45,
                               options: [])
    }
    ctx.restoreGState()

    ctx.restoreGState()
    image.unlockFocus()
    return image
}

let fileManager = FileManager.default
let iconsetDir = "Resources/AppIcon.iconset"
try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let sizes: [(name: String, points: CGFloat, scale: Int)] = [
    ("icon_16x16.png", 16, 1),
    ("icon_16x16@2x.png", 16, 2),
    ("icon_32x32.png", 32, 1),
    ("icon_32x32@2x.png", 32, 2),
    ("icon_128x128.png", 128, 1),
    ("icon_128x128@2x.png", 128, 2),
    ("icon_256x256.png", 256, 1),
    ("icon_256x256@2x.png", 256, 2),
    ("icon_512x512.png", 512, 1),
    ("icon_512x512@2x.png", 512, 2)
]

for item in sizes {
    let pixelSize = item.points * CGFloat(item.scale)
    let icon = createIconImage(size: pixelSize)
    if let tiffData = icon.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let path = "\(iconsetDir)/\(item.name)"
        try? pngData.write(to: URL(fileURLWithPath: path))
    }
}

print("Iconset created at \(iconsetDir)")
