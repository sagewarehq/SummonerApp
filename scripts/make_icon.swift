import AppKit
import CoreGraphics

// Draws the Summoner app icon at a given pixel size and writes a PNG.
// All geometry is expressed in 1024-canvas units and scaled by the context.

func drawIcon(in ctx: CGContext, canvas: CGFloat) {
    let s = canvas / 1024.0
    ctx.scaleBy(x: s, y: s)
    let small = canvas <= 64  // simplified rendering for menu-bar/Finder-list sizes

    // --- macOS icon grid: 824x824 squircle centered on 1024 canvas ---
    let rect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: rect, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow (subtle, downward)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 24,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35))
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(red: 0.09, green: 0.07, blue: 0.18, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    // Clip everything else to the squircle
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // --- Background: deep indigo -> violet vertical gradient ---
    let space = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.16, green: 0.10, blue: 0.36, alpha: 1),  // top: violet
        CGColor(red: 0.07, green: 0.05, blue: 0.16, alpha: 1),  // bottom: near-black indigo
    ] as CFArray
    let bg = CGGradient(colorsSpace: space, colors: bgColors, locations: [0, 1])!
    ctx.drawLinearGradient(bg,
                           start: CGPoint(x: 512, y: 924),
                           end: CGPoint(x: 512, y: 100),
                           options: [])

    // Soft radial glow behind the circle
    let glowColors = [
        CGColor(red: 0.55, green: 0.40, blue: 1.0, alpha: 0.55),
        CGColor(red: 0.55, green: 0.40, blue: 1.0, alpha: 0.0),
    ] as CFArray
    let glow = CGGradient(colorsSpace: space, colors: glowColors, locations: [0, 1])!
    ctx.drawRadialGradient(glow,
                           startCenter: CGPoint(x: 512, y: 512), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 512), endRadius: 420,
                           options: [])

    let center = CGPoint(x: 512, y: 512)
    let ringColor = CGColor(red: 0.78, green: 0.66, blue: 1.0, alpha: 1)
    let ringGlow  = CGColor(red: 0.62, green: 0.44, blue: 1.0, alpha: 0.9)

    // Everything ring-related gets a neon glow (much lighter at small sizes)
    ctx.setShadow(offset: .zero, blur: small ? 8 : 26, color: ringGlow)

    // --- Outer summoning ring (skipped at 16px where it's pure noise) ---
    if canvas > 16 {
        ctx.setStrokeColor(ringColor)
        ctx.setLineWidth(small ? 34 : 16)
        ctx.strokeEllipse(in: CGRect(x: center.x - 330, y: center.y - 330, width: 660, height: 660))
    }

    if !small {
        // --- Inner ring ---
        ctx.setLineWidth(8)
        ctx.strokeEllipse(in: CGRect(x: center.x - 258, y: center.y - 258, width: 516, height: 516))

        // --- Rune ticks between the two rings ---
        let tickCount = 24
        for i in 0..<tickCount {
            let a = CGFloat(i) / CGFloat(tickCount) * 2 * .pi
            let long = i % 3 == 0
            let r0: CGFloat = long ? 276 : 286
            let r1: CGFloat = 312
            ctx.setLineWidth(long ? 10 : 6)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: center.x + cos(a) * r0, y: center.y + sin(a) * r0))
            ctx.addLine(to: CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1))
            ctx.strokePath()
        }
    }

    // --- Central glyph: ⌘ ---
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    let glyphSize: CGFloat = canvas <= 16 ? 640 : (small ? 420 : 340)
    let font = NSFont.systemFont(ofSize: glyphSize, weight: small ? .bold : .semibold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(calibratedRed: 0.93, green: 0.89, blue: 1.0, alpha: 1),
    ]
    let glyph = NSAttributedString(string: "\u{2318}", attributes: attrs)
    let size = glyph.size()
    // Optical centering: nudge up slightly since glyph sits on a baseline box
    let origin = CGPoint(x: center.x - size.width / 2,
                         y: center.y - size.height / 2 + 8)
    glyph.draw(at: origin)

    NSGraphicsContext.restoreGraphicsState()
    ctx.restoreGState()  // remove squircle clip
}

func renderPNG(px: Int, to url: URL) {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: px, height: px,
                              bitsPerComponent: 8, bytesPerRow: 0, space: space,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("no context") }
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high
    drawIcon(in: ctx, canvas: CGFloat(px))
    guard let image = ctx.makeImage() else { fatalError("no image") }
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: px, height: px)
    guard let data = rep.representation(using: .png, properties: [:])
    else { fatalError("no png") }
    try! data.write(to: url)
    print("wrote \(url.lastPathComponent) (\(px)px)")
}

let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
for px in [16, 32, 64, 128, 256, 512, 1024] {
    renderPNG(px: px, to: outDir.appendingPathComponent("icon_\(px).png"))
}
