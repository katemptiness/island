import SwiftUI
import AppKit

/// Derives the island's background tint — a deep, muted color shown toward the
/// bottom of the gradient (the top stays black to blend with the notch). Values
/// are kept dim and low-saturation on purpose, so the color reads as a tasteful
/// wash rather than a toy and white text stays legible over it.
enum IslandTint {

    // MARK: Weather

    /// A color for a WMO weather code + day/night. All deliberately dim.
    static func weather(code: Int, isDay: Bool) -> Color {
        switch code {
        case 0, 1:                              // clear / mainly clear
            return isDay ? hsb(210, 0.45, 0.40) : hsb(245, 0.45, 0.30)
        case 2:                                 // partly cloudy
            return isDay ? hsb(208, 0.34, 0.37) : hsb(240, 0.34, 0.27)
        case 3:                                 // overcast
            return hsb(214, 0.16, 0.32)
        case 45, 48:                            // fog
            return hsb(220, 0.08, 0.32)
        case 51, 53, 55, 56, 57:                // drizzle
            return hsb(205, 0.30, 0.34)
        case 61, 63, 65, 66, 67, 80, 81, 82:    // rain / showers
            return hsb(210, 0.40, 0.31)
        case 71, 73, 75, 77, 85, 86:            // snow
            return hsb(205, 0.20, 0.40)
        case 95, 96, 99:                        // thunderstorm
            return hsb(262, 0.36, 0.30)
        default:
            return hsb(214, 0.16, 0.32)
        }
    }

    // MARK: Artwork

    /// The dominant (vibrant-weighted) color of album artwork, muted to fit the
    /// gradient. Returns nil if the image can't be read. Pure Core Graphics, so
    /// it's safe to call off the main thread.
    static func artwork(_ image: NSImage) -> Color? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let side = 16
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: &pixels, width: side, height: side,
                                  bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        // Weight each pixel by how colorful (and not-too-dark) it is, so a vivid
        // accent wins over large dull areas. Fall back to a plain average for
        // (near-)grayscale art where no pixel carries weight.
        var vr = 0.0, vg = 0.0, vb = 0.0, vw = 0.0
        var ar = 0.0, ag = 0.0, ab = 0.0, n = 0.0
        for i in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
            let a = Double(pixels[i + 3]) / 255
            if a < 0.1 { continue }
            let r = Double(pixels[i]) / 255
            let g = Double(pixels[i + 1]) / 255
            let b = Double(pixels[i + 2]) / 255
            ar += r; ag += g; ab += b; n += 1
            let maxc = max(r, g, b), minc = min(r, g, b)
            let sat = maxc <= 0 ? 0 : (maxc - minc) / maxc
            let weight = sat * maxc
            vr += r * weight; vg += g * weight; vb += b * weight; vw += weight
        }
        guard n > 0 else { return nil }

        let r, g, b: Double
        if vw > 0.05 {
            r = vr / vw; g = vg / vw; b = vb / vw
        } else {
            r = ar / n; g = ag / n; b = ab / n
        }
        return muted(NSColor(srgbRed: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1))
    }

    // MARK: Helpers

    private static func hsb(_ hueDegrees: Double, _ saturation: Double, _ brightness: Double) -> Color {
        Color(hue: hueDegrees / 360, saturation: saturation, brightness: brightness)
    }

    /// Pull any color into the island's range: deep, only moderately saturated.
    private static func muted(_ color: NSColor) -> Color {
        guard let c = color.usingColorSpace(.sRGB) else { return Color(color) }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let sat = min(Double(s), 0.72)
        let bright = min(max(Double(b) * 0.65, 0.20), 0.46)
        return Color(hue: Double(h), saturation: sat, brightness: bright)
    }
}
