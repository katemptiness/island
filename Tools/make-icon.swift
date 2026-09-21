// Draws Island's app icon and writes Resources/Island.icns.
//
// The icon quotes the app itself: a black island hanging from the top edge of a
// blue "screen", with the warm now-playing glow spilling out around it. Every
// measurement is a fraction of the canvas, so each icon size is drawn from
// scratch rather than downscaled.
//
// Usage: swift Tools/make-icon.swift   (run from the repo root)

import AppKit
import CoreGraphics
import CoreImage

// MARK: - Shape

/// Apple-style squircle: a superellipse rather than a plain rounded rect.
func squircle(in rect: CGRect, n: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    let steps = 1440
    for i in 0...steps {
        let t = CGFloat(i) / CGFloat(steps) * 2 * .pi
        let ct = cos(t), st = sin(t)
        let x = rect.midX + a * pow(abs(ct), 2 / n) * (ct < 0 ? -1 : 1)
        let y = rect.midY + b * pow(abs(st), 2 / n) * (st < 0 ? -1 : 1)
        i == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
    }
    path.closeSubpath()
    return path
}

// MARK: - Palette

let space = CGColorSpaceCreateDeviceRGB()
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}

let screenTop    = rgb(0.31, 0.60, 0.84)   // lit desktop near the notch
let screenBottom = rgb(0.07, 0.20, 0.36)   // deeper blue toward the bottom
let glowColor    = rgb(0.84, 0.88, 0.47)   // the warm halo from the artwork tint

// MARK: - Drawing

/// The glow is drawn as the island's silhouette, spread outward and blurred, so
/// it hugs the shape instead of pooling in the middle.
func glowLayer(size: CGFloat, island: CGRect, radius: CGFloat) -> CGImage {
    let px = Int(size)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // At Spotlight/Finder sizes a hairline halo disappears, so widen it a little
    // there — the same optical compensation a hand-drawn icon set would use.
    let boost: CGFloat = size <= 64 ? 1.7 : 1.0
    let spread = size * 0.020 * boost
    let halo = island.insetBy(dx: -spread, dy: -spread)
    ctx.addPath(CGPath(roundedRect: halo,
                       cornerWidth: radius + spread, cornerHeight: radius + spread,
                       transform: nil))
    ctx.setFillColor(glowColor)
    ctx.fillPath()

    let blurred = CIImage(cgImage: ctx.makeImage()!)
        .applyingGaussianBlur(sigma: Double(size * 0.032 * boost))
    return CIContext().createCGImage(blurred,
                                     from: CGRect(x: 0, y: 0, width: size, height: size))!
}


func drawIcon(size: CGFloat) -> CGImage {
    let px = Int(size)
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high

    // Apple's grid leaves the art at ~82% of the canvas, with room for a shadow.
    let inset = size * 0.086
    let plate = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let shape = squircle(in: plate)

    // Soft drop shadow under the plate.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.012),
                  blur: size * 0.03, color: rgb(0, 0, 0, 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(rgb(0, 0, 0, 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()

    // The screen behind the island.
    let screen = CGGradient(colorsSpace: space,
                            colors: [screenTop, screenBottom] as CFArray,
                            locations: [0, 1])!
    ctx.drawLinearGradient(screen,
                           start: CGPoint(x: plate.midX, y: plate.maxY),
                           end: CGPoint(x: plate.midX, y: plate.minY),
                           options: [])

    // Island geometry: it hangs from the top edge, so its upper corners are
    // clipped away by the plate exactly like the real notch.
    let islandW = plate.width * 0.62
    let visible = plate.height * 0.17
    let radius = visible * 0.5
    let island = CGRect(x: plate.midX - islandW / 2,
                        y: plate.maxY - visible,
                        width: islandW,
                        height: visible + radius)   // overflow past the top edge

    // The halo: the island's own silhouette, grown a little and blurred, exactly
    // like MusicGlow does on screen.
    ctx.draw(glowLayer(size: size, island: island, radius: radius),
             in: CGRect(x: 0, y: 0, width: size, height: size))

    // The island itself.
    ctx.addPath(CGPath(roundedRect: island, cornerWidth: radius, cornerHeight: radius,
                       transform: nil))
    ctx.setFillColor(rgb(0, 0, 0, 1))
    ctx.fillPath()

    // Hairline highlight along the top edge, the way glass catches light.
    ctx.addPath(shape)
    ctx.setStrokeColor(rgb(1, 1, 1, 0.18))
    ctx.setLineWidth(size * 0.006)
    ctx.strokePath()

    ctx.restoreGState()
    return ctx.makeImage()!
}

// MARK: - Output

func write(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)
    else { fatalError("cannot write \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("cannot finalize \(url.path)") }
}

let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent("Resources/Island.iconset")
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)

// point size → the two files Apple expects for it
for point in [16, 32, 128, 256, 512] {
    write(drawIcon(size: CGFloat(point)),
          to: iconset.appendingPathComponent("icon_\(point)x\(point).png"))
    write(drawIcon(size: CGFloat(point * 2)),
          to: iconset.appendingPathComponent("icon_\(point)x\(point)@2x.png"))
}

let icns = root.appendingPathComponent("Resources/Island.icns")
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }

try? fm.removeItem(at: iconset)   // the .icns is the artifact worth keeping
print("✅ Wrote \(icns.path)")
