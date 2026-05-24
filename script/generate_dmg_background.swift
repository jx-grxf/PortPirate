#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = root.appendingPathComponent("Assets/dmg")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func renderBackground(scale: CGFloat, outputName: String) {
    let logicalWidth: CGFloat = 540
    let logicalHeight: CGFloat = 380
    let pixelWidth = Int(logicalWidth * scale)
    let pixelHeight = Int(logicalHeight * scale)

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: pixelWidth,
        height: pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fputs("Failed to create CGContext\n", stderr)
        exit(1)
    }

    ctx.scaleBy(x: scale, y: scale)
    ctx.setShouldAntialias(true)
    ctx.setShouldSmoothFonts(true)
    ctx.setShouldSubpixelPositionFonts(true)
    ctx.setShouldSubpixelQuantizeFonts(true)
    ctx.interpolationQuality = .high

    let gradientColors = [
        CGColor(red: 0.985, green: 0.985, blue: 0.99, alpha: 1),
        CGColor(red: 0.93, green: 0.94, blue: 0.97, alpha: 1)
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: logicalHeight),
            end: CGPoint(x: 0, y: 0),
            options: []
        )
    } else {
        ctx.setFillColor(CGColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: logicalWidth, height: logicalHeight))
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

    let title = "PortPirate"
    let titleParagraph = NSMutableParagraphStyle()
    titleParagraph.alignment = .center
    let titleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 26, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 0.10, alpha: 1),
        .kern: 0.2,
        .paragraphStyle: titleParagraph
    ]
    let titleString = NSAttributedString(string: title, attributes: titleAttrs)
    let titleSize = titleString.size()
    let titleY = logicalHeight - 50 - titleSize.height
    titleString.draw(in: CGRect(
        x: 0,
        y: titleY,
        width: logicalWidth,
        height: titleSize.height
    ))

    let subtitle = "Drag PortPirate to your Applications folder"
    let subtitleParagraph = NSMutableParagraphStyle()
    subtitleParagraph.alignment = .center
    let subtitleAttrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor(calibratedWhite: 0.38, alpha: 1),
        .paragraphStyle: subtitleParagraph
    ]
    let subtitleString = NSAttributedString(string: subtitle, attributes: subtitleAttrs)
    let subtitleSize = subtitleString.size()
    subtitleString.draw(in: CGRect(
        x: 0,
        y: titleY - subtitleSize.height - 6,
        width: logicalWidth,
        height: subtitleSize.height
    ))

    NSGraphicsContext.restoreGraphicsState()

    guard let image = ctx.makeImage() else {
        fputs("Failed to create image\n", stderr)
        exit(1)
    }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: logicalWidth, height: logicalHeight)
    guard let pngData = rep.representation(using: .png, properties: [
        .interlaced: false
    ]) else {
        fputs("Failed to encode PNG\n", stderr)
        exit(1)
    }
    let outURL = outDir.appendingPathComponent(outputName)
    do {
        try pngData.write(to: outURL)
        print("wrote \(outURL.path) (\(pixelWidth)x\(pixelHeight))")
    } catch {
        fputs("Failed to write \(outURL.path): \(error)\n", stderr)
        exit(1)
    }
}

renderBackground(scale: 1, outputName: "dmg-background.png")
renderBackground(scale: 2, outputName: "dmg-background@2x.png")

let tiffURL = outDir.appendingPathComponent("dmg-background.tiff")
let oneX = outDir.appendingPathComponent("dmg-background.png").path
let twoX = outDir.appendingPathComponent("dmg-background@2x.png").path
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
proc.arguments = ["-cathidpicheck", oneX, twoX, "-out", tiffURL.path]
do {
    try proc.run()
    proc.waitUntilExit()
    if proc.terminationStatus == 0 {
        print("wrote \(tiffURL.path) (HiDPI 1x+2x)")
    } else {
        fputs("tiffutil exited with status \(proc.terminationStatus)\n", stderr)
    }
} catch {
    fputs("Failed to run tiffutil: \(error)\n", stderr)
}
