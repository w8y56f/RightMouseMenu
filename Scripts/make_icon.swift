import AppKit
let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let background = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 215, yRadius: 215)
// `make_icon.swift <out.png> --dev` draws the orange "DEV" variant used by Debug builds.
let dev = CommandLine.arguments.dropFirst(2).contains("--dev")
let gradient = dev
    ? NSGradient(starting: NSColor(calibratedRed: 0.90, green: 0.38, blue: 0.08, alpha: 1), ending: NSColor(calibratedRed: 1.0, green: 0.68, blue: 0.20, alpha: 1))!
    : NSGradient(starting: NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.87, alpha: 1), ending: NSColor(calibratedRed: 0.28, green: 0.67, blue: 0.99, alpha: 1))!
gradient.draw(in: background, angle: -45)
let menu = NSBezierPath(roundedRect: NSRect(x: 295, y: 286, width: 550, height: 495), xRadius: 72, yRadius: 72)
NSColor.white.setFill(); menu.fill()
for y in [674, 550, 426] {
    let dot = NSBezierPath(ovalIn: NSRect(x: 360, y: y-13, width: 26, height: 26))
    NSColor(calibratedRed: 0.16, green: 0.41, blue: 0.9, alpha: 1).setFill(); dot.fill()
    let line = NSBezierPath(roundedRect: NSRect(x: 414, y: y-10, width: y == 426 ? 240 : 335, height: 20), xRadius: 10, yRadius: 10)
    NSColor(calibratedWhite: 0.75, alpha: 1).setFill(); line.fill()
}
let cursor = NSBezierPath()
cursor.move(to: NSPoint(x: 198, y: 720)); cursor.line(to: NSPoint(x: 198, y: 280)); cursor.line(to: NSPoint(x: 302, y: 365)); cursor.line(to: NSPoint(x: 376, y: 205)); cursor.line(to: NSPoint(x: 456, y: 244)); cursor.line(to: NSPoint(x: 383, y: 398)); cursor.line(to: NSPoint(x: 523, y: 398)); cursor.close()
NSColor.white.setStroke(); cursor.lineWidth = 30; cursor.stroke()
NSColor(calibratedRed: 0.06, green: 0.18, blue: 0.47, alpha: 1).setFill(); cursor.fill()
if dev {
    let banner = NSBezierPath(roundedRect: NSRect(x: 560, y: 90, width: 400, height: 170), xRadius: 50, yRadius: 50)
    NSColor(calibratedWhite: 0.1, alpha: 0.9).setFill(); banner.fill()
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 120, weight: .heavy), .foregroundColor: NSColor.white]
    let text = NSAttributedString(string: "DEV", attributes: attributes)
    let textSize = text.size()
    text.draw(at: NSPoint(x: 760 - textSize.width / 2, y: 175 - textSize.height / 2))
}
image.unlockFocus()
let data = NSBitmapImageRep(data: image.tiffRepresentation!)!.representation(using: .png, properties: [:])!
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
