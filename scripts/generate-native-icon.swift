import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("Usage: generate-native-icon.swift <output.png>\n".utf8))
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: 1024,
    pixelsHigh: 1024,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Unable to create icon canvas")
}

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 0) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

context.imageInterpolation = .high

let lightGrayBackground = color(239, 239, 237)
let darkGray = color(82, 82, 79)
let midGray = color(145, 145, 141)
let paper = color(253, 253, 252)

roundedRect(NSRect(x: 32, y: 32, width: 960, height: 960), radius: 220, fill: lightGrayBackground)

NSGraphicsContext.saveGraphicsState()
let notebookShadow = NSShadow()
notebookShadow.shadowColor = color(42, 42, 40, alpha: 0.16)
notebookShadow.shadowBlurRadius = 34
notebookShadow.shadowOffset = NSSize(width: 0, height: -16)
notebookShadow.set()
roundedRect(
    NSRect(x: 238, y: 176, width: 548, height: 672),
    radius: 68,
    fill: paper,
    stroke: darkGray,
    width: 32
)
NSGraphicsContext.restoreGraphicsState()

let binding = NSBezierPath()
binding.move(to: NSPoint(x: 350, y: 192))
binding.line(to: NSPoint(x: 350, y: 832))
binding.lineWidth = 30
binding.lineCapStyle = .round
darkGray.setStroke()
binding.stroke()

for line in [682.0, 572.0, 462.0] {
    let rule = NSBezierPath()
    rule.move(to: NSPoint(x: 430, y: line))
    rule.line(to: NSPoint(x: line == 572 ? 646 : 698, y: line))
    rule.lineWidth = 28
    rule.lineCapStyle = .round
    midGray.setStroke()
    rule.stroke()
}

let pencilBody = NSBezierPath()
pencilBody.move(to: NSPoint(x: 548, y: 318))
pencilBody.line(to: NSPoint(x: 780, y: 550))
pencilBody.line(to: NSPoint(x: 838, y: 492))
pencilBody.line(to: NSPoint(x: 606, y: 260))
pencilBody.close()
darkGray.setFill()
pencilBody.fill()

let pencilHighlight = NSBezierPath()
pencilHighlight.move(to: NSPoint(x: 578, y: 311))
pencilHighlight.line(to: NSPoint(x: 791, y: 524))
pencilHighlight.line(to: NSPoint(x: 812, y: 503))
pencilHighlight.line(to: NSPoint(x: 599, y: 290))
pencilHighlight.close()
color(166, 166, 162).setFill()
pencilHighlight.fill()

let pencilTip = NSBezierPath()
pencilTip.move(to: NSPoint(x: 502, y: 214))
pencilTip.line(to: NSPoint(x: 548, y: 318))
pencilTip.line(to: NSPoint(x: 606, y: 260))
pencilTip.close()
color(205, 205, 199).setFill()
pencilTip.fill()

let graphite = NSBezierPath()
graphite.move(to: NSPoint(x: 502, y: 214))
graphite.line(to: NSPoint(x: 518, y: 251))
graphite.line(to: NSPoint(x: 539, y: 230))
graphite.close()
color(52, 52, 50).setFill()
graphite.fill()

let pencilCap = NSBezierPath()
pencilCap.move(to: NSPoint(x: 780, y: 550))
pencilCap.line(to: NSPoint(x: 812, y: 582))
pencilCap.curve(to: NSPoint(x: 870, y: 524), controlPoint1: NSPoint(x: 828, y: 598), controlPoint2: NSPoint(x: 886, y: 540))
pencilCap.line(to: NSPoint(x: 838, y: 492))
pencilCap.close()
color(112, 112, 108).setFill()
pencilCap.fill()

context.flushGraphics()
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Unable to render icon")
}

try png.write(to: outputURL, options: .atomic)
