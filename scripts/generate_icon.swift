#!/usr/bin/swift
import AppKit

// MARK: - Configuration

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "."

let iconSizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

// MARK: - Drawing

func drawIcon(in context: CGContext, size: CGFloat) {
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)

    // --- Background: macOS Big Sur rounded rect ---
    let inset = size * 0.02
    let bgRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Dark blue-grey gradient (reminiscent of dark glass)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1.0),
        CGColor(red: 0.22, green: 0.28, blue: 0.38, alpha: 1.0),
    ] as CFArray
    let gradientLocations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: gradientLocations)!

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: 0),
        end: CGPoint(x: size, y: size),
        options: []
    )
    context.restoreGState()

    // Subtle border
    context.saveGState()
    context.addPath(bgPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    context.setLineWidth(size * 0.008)
    context.strokePath()
    context.restoreGState()

    // --- Glass reflection arc (top-left shine) ---
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    let shineGradientColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.12),
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.0),
    ] as CFArray
    let shineLocations: [CGFloat] = [0.0, 1.0]
    let shineGradient = CGGradient(colorsSpace: colorSpace, colors: shineGradientColors, locations: shineLocations)!

    context.drawRadialGradient(
        shineGradient,
        startCenter: CGPoint(x: size * 0.25, y: size * 0.75),
        startRadius: 0,
        endCenter: CGPoint(x: size * 0.25, y: size * 0.75),
        endRadius: size * 0.6,
        options: []
    )
    context.restoreGState()

    // --- Keycap grid (3x3 arrangement, center row visible) ---
    let keySize = size * 0.17
    let keyGap = size * 0.04
    let keyCorner = size * 0.035
    let gridStartX = size * 0.18
    let gridStartY = size * 0.18

    // Draw 3 rows x 3 cols of keycaps
    for row in 0..<3 {
        for col in 0..<3 {
            let x = gridStartX + CGFloat(col) * (keySize + keyGap)
            let y = gridStartY + CGFloat(row) * (keySize + keyGap)
            let keyRect = CGRect(x: x, y: y, width: keySize, height: keySize)

            // Skip center key (will be drawn as the featured key)
            if row == 1, col == 1 { continue }

            drawKeycap(
                in: context,
                rect: keyRect,
                cornerRadius: keyCorner,
                alpha: 0.35,
                size: size,
                label: nil
            )
        }
    }

    // --- Featured center keycap with ⌘ symbol ---
    let centerX = gridStartX + 1 * (keySize + keyGap)
    let centerY = gridStartY + 1 * (keySize + keyGap)
    let featuredSize = keySize * 1.1
    let featuredOffset = (featuredSize - keySize) / 2
    let featuredRect = CGRect(
        x: centerX - featuredOffset,
        y: centerY - featuredOffset,
        width: featuredSize,
        height: featuredSize
    )

    drawKeycap(
        in: context,
        rect: featuredRect,
        cornerRadius: keyCorner * 1.2,
        alpha: 0.85,
        size: size,
        label: "\u{2318}"
    )

    // --- Glass overlay effect (diagonal light streak) ---
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    let streakWidth = size * 0.18
    let streakPath = CGMutablePath()
    streakPath.move(to: CGPoint(x: size * 0.55, y: size * 1.1))
    streakPath.addLine(to: CGPoint(x: size * 0.55 + streakWidth, y: size * 1.1))
    streakPath.addLine(to: CGPoint(x: size * 1.1, y: size * 0.55 + streakWidth))
    streakPath.addLine(to: CGPoint(x: size * 1.1, y: size * 0.55))
    streakPath.closeSubpath()

    context.addPath(streakPath)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    context.fillPath()
    context.restoreGState()
}

func drawKeycap(
    in context: CGContext,
    rect: CGRect,
    cornerRadius: CGFloat,
    alpha: CGFloat,
    size: CGFloat,
    label: String?
) {
    let keyPath = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Keycap shadow
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -size * 0.008),
        blur: size * 0.02,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.4 * Double(alpha))
    )
    context.addPath(keyPath)
    context.setFillColor(CGColor(red: 0.85, green: 0.88, blue: 0.92, alpha: Double(alpha)))
    context.fillPath()
    context.restoreGState()

    // Keycap body (glass-like translucent)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let keyGradientColors = [
        CGColor(red: 0.92, green: 0.94, blue: 0.97, alpha: Double(alpha)),
        CGColor(red: 0.78, green: 0.82, blue: 0.88, alpha: Double(alpha)),
    ] as CFArray
    let keyGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: keyGradientColors,
        locations: [0.0, 1.0]
    )!

    context.saveGState()
    context.addPath(keyPath)
    context.clip()
    context.drawLinearGradient(
        keyGradient,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY),
        options: []
    )
    context.restoreGState()

    // Keycap top highlight
    let highlightRect = CGRect(
        x: rect.minX + rect.width * 0.1,
        y: rect.midY,
        width: rect.width * 0.8,
        height: rect.height * 0.42
    )
    let highlightPath = CGPath(
        roundedRect: highlightRect,
        cornerWidth: cornerRadius * 0.6,
        cornerHeight: cornerRadius * 0.6,
        transform: nil
    )
    context.saveGState()
    context.addPath(keyPath)
    context.clip()
    context.addPath(highlightPath)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.25 * Double(alpha)))
    context.fillPath()
    context.restoreGState()

    // Keycap border
    context.saveGState()
    context.addPath(keyPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15 * Double(alpha)))
    context.setLineWidth(size * 0.004)
    context.strokePath()
    context.restoreGState()

    // Label (⌘ symbol)
    if let label, size >= 64 {
        let fontSize = rect.height * 0.48
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                red: 0.15,
                green: 0.18,
                blue: 0.25,
                alpha: Double(alpha)
            ),
        ]
        let attrString = NSAttributedString(string: label, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let lineBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        let textX = rect.midX - lineBounds.width / 2 - lineBounds.origin.x
        let textY = rect.midY - lineBounds.height / 2 - lineBounds.origin.y

        context.saveGState()
        context.textPosition = CGPoint(x: textX, y: textY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}

// MARK: - Export

func generateIcon(pointSize: Int, scale: Int) {
    let pixelSize = pointSize * scale
    let size = CGFloat(pixelSize)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    ) else {
        print("Failed to create context for \(pixelSize)x\(pixelSize)")
        return
    }

    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    drawIcon(in: context, size: size)

    guard let cgImage = context.makeImage() else {
        print("Failed to create image for \(pixelSize)x\(pixelSize)")
        return
    }

    let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
    bitmapRep.size = NSSize(width: pointSize, height: pointSize)

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(pixelSize)x\(pixelSize)")
        return
    }

    let filename = "icon_\(pointSize)x\(pointSize)@\(scale)x.png"
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent(filename)

    do {
        try pngData.write(to: url)
        print("Generated: \(filename) (\(pixelSize)x\(pixelSize) pixels)")
    } catch {
        print("Failed to write \(filename): \(error)")
    }
}

// MARK: - Main

print("Generating KeyGlass app icons in: \(outputDir)")

for (pointSize, scale) in iconSizes {
    generateIcon(pointSize: pointSize, scale: scale)
}

let contentsJSON = """
{
  "images" : [
    {
      "filename" : "icon_16x16@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512@1x.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

let contentsURL = URL(fileURLWithPath: outputDir).appendingPathComponent("Contents.json")
do {
    try contentsJSON.write(to: contentsURL, atomically: true, encoding: .utf8)
    print("Updated: Contents.json")
} catch {
    print("Failed to write Contents.json: \(error)")
}

print("Done!")
