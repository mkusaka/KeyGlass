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

    // --- Background: macOS rounded rect ---
    let inset = size * 0.02
    let bgRect = bounds.insetBy(dx: inset, dy: inset)
    let cornerRadius = size * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        CGColor(red: 0.11, green: 0.13, blue: 0.17, alpha: 1.0),
        CGColor(red: 0.20, green: 0.24, blue: 0.31, alpha: 1.0),
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

    context.saveGState()
    context.addPath(bgPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    context.setLineWidth(size * 0.008)
    context.strokePath()
    context.restoreGState()

    // Subtle glass reflection near the top edge.
    context.saveGState()
    context.addPath(bgPath)
    context.clip()

    let shineGradientColors = [
        CGColor(red: 1, green: 1, blue: 1, alpha: 0.10),
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

    // A single, prominent keycap reads more like an actual keyboard key.
    let bodyRect = CGRect(
        x: size * 0.20,
        y: size * 0.20,
        width: size * 0.60,
        height: size * 0.44
    )
    let topRect = CGRect(
        x: size * 0.23,
        y: size * 0.30,
        width: size * 0.54,
        height: size * 0.40
    )

    drawKeycap(
        in: context,
        bodyRect: bodyRect,
        topRect: topRect,
        bodyCornerRadius: size * 0.11,
        topCornerRadius: size * 0.10,
        size: size,
        label: "\u{2318}"
    )

    // Diagonal glass streak to keep the original "glass" character.
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
    bodyRect: CGRect,
    topRect: CGRect,
    bodyCornerRadius: CGFloat,
    topCornerRadius: CGFloat,
    size: CGFloat,
    label: String?
) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bodyPath = CGPath(
        roundedRect: bodyRect,
        cornerWidth: bodyCornerRadius,
        cornerHeight: bodyCornerRadius,
        transform: nil
    )
    let topPath = CGPath(
        roundedRect: topRect,
        cornerWidth: topCornerRadius,
        cornerHeight: topCornerRadius,
        transform: nil
    )

    // Broad shadow anchors the key on the glass background.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: size * 0.035),
        blur: size * 0.075,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.40)
    )
    context.addPath(bodyPath)
    context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.18))
    context.fillPath()
    context.restoreGState()

    // Keycap skirt.
    let bodyGradientColors = [
        CGColor(red: 0.73, green: 0.77, blue: 0.83, alpha: 1.0),
        CGColor(red: 0.43, green: 0.48, blue: 0.56, alpha: 1.0),
    ] as CFArray
    let bodyGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: bodyGradientColors,
        locations: [0.0, 1.0]
    )!

    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    context.drawLinearGradient(
        bodyGradient,
        start: CGPoint(x: bodyRect.midX, y: bodyRect.maxY),
        end: CGPoint(x: bodyRect.midX, y: bodyRect.minY),
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(bodyPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.10))
    context.setLineWidth(size * 0.004)
    context.strokePath()
    context.restoreGState()

    // Shadow tucked under the top plate to emphasize the key profile.
    let underTopGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.16),
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.saveGState()
    context.addPath(bodyPath)
    context.clip()
    context.drawLinearGradient(
        underTopGradient,
        start: CGPoint(x: topRect.midX, y: topRect.minY),
        end: CGPoint(x: topRect.midX, y: bodyRect.minY),
        options: []
    )
    context.restoreGState()

    // Keycap top surface.
    let topGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0.99, green: 0.99, blue: 1.0, alpha: 1.0),
            CGColor(red: 0.88, green: 0.90, blue: 0.94, alpha: 1.0),
        ] as CFArray,
        locations: [0.0, 1.0]
    )!
    context.saveGState()
    context.addPath(topPath)
    context.clip()
    context.drawLinearGradient(
        topGradient,
        start: CGPoint(x: topRect.midX, y: topRect.maxY),
        end: CGPoint(x: topRect.midX, y: topRect.minY),
        options: []
    )
    context.restoreGState()

    // Top specular highlight.
    let highlightRect = CGRect(
        x: topRect.minX + topRect.width * 0.08,
        y: topRect.midY + topRect.height * 0.08,
        width: topRect.width * 0.84,
        height: topRect.height * 0.30
    )
    let highlightPath = CGPath(
        roundedRect: highlightRect,
        cornerWidth: topCornerRadius * 0.55,
        cornerHeight: topCornerRadius * 0.55,
        transform: nil
    )
    context.saveGState()
    context.addPath(topPath)
    context.clip()
    context.addPath(highlightPath)
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.34))
    context.fillPath()
    context.restoreGState()

    // Inner bottom shade makes the key surface feel concave enough to read as a cap.
    let innerShade = CGGradient(
        colorsSpace: colorSpace,
        colors: [
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.0),
            CGColor(red: 0, green: 0, blue: 0, alpha: 0.08),
        ] as CFArray,
        locations: [0.55, 1.0]
    )!
    context.saveGState()
    context.addPath(topPath)
    context.clip()
    context.drawLinearGradient(
        innerShade,
        start: CGPoint(x: topRect.midX, y: topRect.maxY),
        end: CGPoint(x: topRect.midX, y: topRect.minY),
        options: []
    )
    context.restoreGState()

    context.saveGState()
    context.addPath(topPath)
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.32))
    context.setLineWidth(size * 0.004)
    context.strokePath()
    context.restoreGState()

    // Legend.
    if let label, size >= 64 {
        let fontSize = topRect.height * 0.36
        let font = CTFontCreateWithName("Helvetica Neue" as CFString, fontSize, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(
                red: 0.21,
                green: 0.24,
                blue: 0.29,
                alpha: 0.92
            ),
        ]
        let attrString = NSAttributedString(string: label, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let lineBounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        let textX = topRect.midX - lineBounds.width / 2 - lineBounds.origin.x
        let textY = topRect.midY - lineBounds.height / 2 - lineBounds.origin.y - topRect.height * 0.01

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
