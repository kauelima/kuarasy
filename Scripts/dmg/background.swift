// Draws the background of the DMG window: a sky that runs from day on the left,
// where Kuarasy sits, to night on the right, where the Applications shortcut sits.
// The day side has a few faint clouds, the night side has stars.
//
// Writes background.png (1x) and background@2x.png next to this file:
//   swift Scripts/dmg/background.swift
//
// The window size and icon positions must match Scripts/dmg/settings.py.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let width = 640.0, height = 400.0
let appIcon = CGPoint(x: 160, y: 185)          // icon centres, top-left origin
let applicationsIcon = CGPoint(x: 480, y: 185)
let iconSize = 128.0

// MARK: - Colour

struct RGB { var r, g, b: Double }

func hex(_ v: UInt32) -> RGB {
    RGB(r: Double((v >> 16) & 0xFF) / 255, g: Double((v >> 8) & 0xFF) / 255, b: Double(v & 0xFF) / 255)
}

func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
    RGB(r: a.r + (b.r - a.r) * t, g: a.g + (b.g - a.g) * t, b: a.b + (b.b - a.b) * t)
}

func smooth(_ t: Double) -> Double {
    let t = min(max(t, 0), 1)
    return t * t * (3 - 2 * t)
}

/// The colour at `x` (0...1) along evenly spaced stops, on a Catmull-Rom curve so
/// the sky changes smoothly instead of flattening out at each stop.
func sample(_ stops: [RGB], _ x: Double) -> RGB {
    let p = min(max(x, 0), 1) * Double(stops.count - 1)
    let i = min(Int(p), stops.count - 2), t = p - Double(i)
    let c0 = stops[max(i - 1, 0)], c1 = stops[i], c2 = stops[i + 1], c3 = stops[min(i + 2, stops.count - 1)]
    func curve(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
        let v = 0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
        return min(max(v, 0), 1)
    }
    return RGB(r: curve(c0.r, c1.r, c2.r, c3.r), g: curve(c0.g, c1.g, c2.g, c3.g), b: curve(c0.b, c1.b, c2.b, c3.b))
}

// Left to right: day, Kuarasy, sunset, Applications, night.
//
// Finder draws icon labels black in Light mode and white in Dark mode, whatever
// the background. Behind each label the sky stays a mid tone so both can be read:
// a rich blue under "Kuarasy", a dusky violet horizon under "Applications".
let zenith = [hex(0x2B6FBC), hex(0x3A80CA), hex(0x6E68A8), hex(0x272A5E), hex(0x0B112E)]
let horizon = [hex(0x3D88D0), hex(0x4A8FD2), hex(0xD9958C), hex(0x8E7AB8), hex(0x4E4A88)]

/// How far down the sky blends from zenith to horizon colour.
func horizonAmount(_ y: Double) -> Double { smooth((y / height - 0.1) / 0.75) }

/// 0 in full day, 1 in full night.
func nightAmount(_ x: Double) -> Double { smooth((x / width - 0.5) / 0.35) }

// Small seeded generator, so the stars land in the same place every run.
struct Random {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}

// MARK: - Drawing

func render(scale: Double) -> CGImage {
    let pw = Int(width * scale), ph = Int(height * scale)
    let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: pw * 4,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Sky, pixel by pixel. Row 0 of the buffer is the top of the image.
    // A little noise keeps the gradient from banding.
    let pixels = ctx.data!.bindMemory(to: UInt8.self, capacity: pw * ph * 4)
    var noise = Random(state: 7)
    for py in 0..<ph {
        let y = (Double(py) + 0.5) / scale
        let v = horizonAmount(y)
        for px in 0..<pw {
            let x = (Double(px) + 0.5) / scale
            let c = mix(sample(zenith, x / width), sample(horizon, x / width), v)
            let i = (py * pw + px) * 4
            for (k, channel) in [c.r, c.g, c.b].enumerated() {
                let dithered = channel * 255 + noise.next() - 0.5
                pixels[i + k] = UInt8(min(max(dithered.rounded(), 0), 255))
            }
            pixels[i + 3] = 255
        }
    }

    // From here on, draw in points with a top-left origin.
    ctx.translateBy(x: 0, y: CGFloat(ph))
    ctx.scaleBy(x: scale, y: -scale)

    // Clouds: flat white shapes at low opacity. Each is drawn in its own layer
    // so overlapping puffs don't stack up into brighter patches.
    func cloud(centerX cx: Double, baseY by: Double, width w: Double, opacity: Double) {
        let path = CGMutablePath()
        let baseHeight = w * 0.2
        path.addRoundedRect(in: CGRect(x: cx - w / 2, y: by - baseHeight, width: w, height: baseHeight),
                            cornerWidth: baseHeight / 2, cornerHeight: baseHeight / 2)
        for (dx, dy, r) in [(-0.22, -0.18, 0.17), (0.0, -0.26, 0.23), (0.23, -0.17, 0.15)] {
            path.addEllipse(in: CGRect(x: cx + dx * w - r * w, y: by + dy * w - r * w, width: 2 * r * w, height: 2 * r * w))
        }
        ctx.saveGState()
        ctx.setAlpha(opacity)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.addPath(path)
        ctx.fillPath()
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }
    cloud(centerX: 92, baseY: 92, width: 120, opacity: 0.22)
    cloud(centerX: 240, baseY: 62, width: 72, opacity: 0.15)
    cloud(centerX: 62, baseY: 356, width: 84, opacity: 0.14)

    // Stars: dots that thicken towards the right and fade towards the horizon,
    // kept clear of the Applications icon and its label.
    let keepClear = CGRect(x: applicationsIcon.x - iconSize / 2 - 24, y: applicationsIcon.y - iconSize / 2 - 16,
                           width: iconSize + 48, height: iconSize + 64)
    var random = Random(state: 2024)
    for _ in 0..<420 {
        let x = width * (0.5 + 0.5 * random.next())
        let y = height * 0.8 * random.next()
        let size = random.next(), brightness = random.next(), keep = random.next()
        let visibility = nightAmount(x) * (1 - smooth((y / height - 0.5) / 0.3))
        guard keep < visibility * 0.5, !keepClear.contains(CGPoint(x: x, y: y)) else { continue }
        let radius = 0.45 + 0.85 * size * size
        let alpha = (0.35 + 0.6 * brightness) * visibility
        if radius > 1.05 {
            // The biggest stars get a faint glow.
            ctx.setFillColor(CGColor(gray: 1, alpha: alpha * 0.12))
            ctx.fillEllipse(in: CGRect(x: x - radius * 3, y: y - radius * 3, width: radius * 6, height: radius * 6))
        }
        ctx.setFillColor(CGColor(gray: 1, alpha: alpha))
        ctx.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
    }

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL, dpi: Double) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    let properties = [kCGImagePropertyDPIWidth: dpi, kCGImagePropertyDPIHeight: dpi] as CFDictionary
    CGImageDestinationAddImage(dest, image, properties)
    guard CGImageDestinationFinalize(dest) else { fatalError("Couldn't write \(url.path)") }
    print("Wrote \(url.path)")
}

let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
write(render(scale: 1), to: folder.appendingPathComponent("background.png"), dpi: 72)
write(render(scale: 2), to: folder.appendingPathComponent("background@2x.png"), dpi: 144)
