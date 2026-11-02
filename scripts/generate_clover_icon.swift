import AppKit

let side = 1024.0
let canvas = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
    NSColor(calibratedRed: 0.94, green: 1.0, blue: 0.93, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: side, height: side).fill()
    let halo = NSBezierPath(ovalIn: NSRect(x: 206, y: 320, width: 612, height: 612))
    NSColor.white.withAlphaComponent(0.65).setFill()
    halo.fill()
    // Clover stem
    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 496, y: 500))
    stem.curve(to: NSPoint(x: 418, y: 328), controlPoint1: NSPoint(x: 492, y: 436), controlPoint2: NSPoint(x: 443, y: 379))
    stem.lineWidth = 24
    stem.lineCapStyle = .round
    NSColor(calibratedRed: 0.06, green: 0.55, blue: 0.28, alpha: 1).setStroke()
    stem.stroke()
    for index in 0..<3 {
        NSGraphicsContext.saveGraphicsState()
        let transform = AffineTransform(translationByX: 496, byY: 602)
        var rotate = transform
        rotate.rotate(byDegrees: Double(index) * 120)
        let t = NSAffineTransform(transform: rotate)
        t.concat()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: 0, y: -10))
        leaf.curve(to: NSPoint(x: -135, y: 155), controlPoint1: NSPoint(x: -90, y: 58), controlPoint2: NSPoint(x: -166, y: 113))
        leaf.curve(to: NSPoint(x: 0, y: 202), controlPoint1: NSPoint(x: -103, y: 217), controlPoint2: NSPoint(x: -35, y: 196))
        leaf.curve(to: NSPoint(x: 131, y: 154), controlPoint1: NSPoint(x: 39, y: 215), controlPoint2: NSPoint(x: 106, y: 202))
        leaf.curve(to: NSPoint(x: 0, y: -10), controlPoint1: NSPoint(x: 162, y: 109), controlPoint2: NSPoint(x: 63, y: 55))
        leaf.close()
        NSColor(calibratedRed: 0.06, green: 0.55 + Double(index) * 0.015, blue: 0.26, alpha: 1).setFill()
        leaf.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    let panel = NSBezierPath(roundedRect: NSRect(x: 166, y: 93, width: 692, height: 236), xRadius: 65, yRadius: 65)
    NSColor.white.withAlphaComponent(0.94).setFill()
    panel.fill()
    func drawCentered(_ string: String, y: CGFloat, size: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: .heavy),
            .foregroundColor: NSColor(calibratedRed: 0.05, green: 0.38, blue: 0.23, alpha: 1)
        ]
        let a = NSAttributedString(string: string, attributes: attrs)
        let sizeOfText = a.size()
        a.draw(at: NSPoint(x: (side - sizeOfText.width) / 2, y: y))
    }
    drawCentered("N2", y: 194, size: 99)
    drawCentered("của Trung", y: 121, size: 45)
    return true
}
let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
let output = rep.representation(using: .png, properties: [:])!
let path = "N2CuaTrung/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
try output.write(to: URL(fileURLWithPath: path), options: .atomic)
let brandFolder = "N2CuaTrung/Assets.xcassets/BrandLogo.imageset"
try FileManager.default.createDirectory(atPath: brandFolder,
                                        withIntermediateDirectories: true)
let brandPath = brandFolder + "/BrandLogo.png"
try output.write(to: URL(fileURLWithPath: brandPath), options: .atomic)
let widgetFolder = "N2Widget/Assets.xcassets/BrandLogo.imageset"
try FileManager.default.createDirectory(atPath: widgetFolder,
                                        withIntermediateDirectories: true)
let widgetPath = widgetFolder + "/BrandLogo.png"
try output.write(to: URL(fileURLWithPath: widgetPath), options: .atomic)
print("Đã tạo cùng một logo cỏ ba lá cho AppIcon và BrandLogo: \(path), \(brandPath)")