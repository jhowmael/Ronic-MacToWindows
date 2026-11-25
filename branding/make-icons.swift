// Generates the Ronic MacToWindows logo: an "R" passing through a conversion portal,
// leaving the silver (macOS) and arriving at the blue (Windows), with motion streaks.
//
//   swift branding/make-icons.swift [output-folder]
//
// Output: logo-<N>.png for N in 16…1024 (rounded square, transparent background).
// Use ./branding/make-icons.sh to also build AppIcon.icns.
import AppKit
import CoreText
import Foundation

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "branding/out")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

/// Vector path of a letter (SF Pro Rounded Black, like Ronic Mirror).
func glyphPath(_ char: String, size: CGFloat) -> CGPath {
    let font = CTFontCreateWithName("SFProRounded-Black" as CFString, size, nil)
    let fallback = NSFont.systemFont(ofSize: size, weight: .black) as CTFont
    let useFont = (CTFontCopyPostScriptName(font) as String).contains("Rounded") ? font : fallback
    var unichars = Array(char.utf16)
    var glyphs = [CGGlyph](repeating: 0, count: unichars.count)
    CTFontGetGlyphsForCharacters(useFont, &unichars, &glyphs, unichars.count)
    return CTFontCreatePathForGlyph(useFont, glyphs[0], nil)!
}

func render(size px: Int) -> Data {
    let s = CGFloat(px)
    let cs = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    let small = px <= 32   // small sizes: less detail, thicker strokes
    let tiny = px <= 24    // 16–24 px: no streaks, bigger centered letter

    // ---- Letter and portal geometry ----
    let glyph = glyphPath("R", size: s * (tiny ? 0.66 : 0.54))
    let gb = glyph.boundingBoxOfPath
    let letterX = s * (tiny ? 0.5 : 0.545) - gb.width / 2 - gb.minX        // R slightly to the right: room for the streaks
    let letterY = (s - gb.height) / 2 - gb.minY
    var t = CGAffineTransform(translationX: letterX, y: letterY)
    let letter = glyph.copy(using: &t)!
    let lb = letter.boundingBoxOfPath
    let portalX = lb.minX + lb.width * 0.52                 // the portal cuts the R just past its middle

    // ---- Background: rounded square, silver → Windows blue (horizontal, in the direction of motion) ----
    let inset = s * 0.04
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = rect.width * 0.225
    let bg = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.saveGState()
    ctx.addPath(bg)
    ctx.clip()

    let p = portalX / s
    let bgGradient = CGGradient(colorsSpace: cs,
                                colors: [color(0xF4F6F9), color(0xD3D8DF), color(0xA9B2BE),
                                         color(0x2E8CF0), color(0x0078D4), color(0x004E9A)] as CFArray,
                                locations: [0, 0.22, p - 0.06, p + 0.04, 0.78, 1])!
    ctx.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: s * 0.55), end: CGPoint(x: s, y: s * 0.45), options: [])

    // Soft shine at the top (glass effect, same as the rest of the Ronic family).
    let shine = CGGradient(colorsSpace: cs, colors: [color(0xFFFFFF, 0.30), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(shine, startCenter: CGPoint(x: s * 0.3, y: s * 0.95), startRadius: 0,
                           endCenter: CGPoint(x: s * 0.3, y: s * 0.95), endRadius: s * 0.75, options: [])

    // ---- Motion streaks (the R comes in fast from the left) ----
    let streaks: [(y: CGFloat, length: CGFloat, thick: CGFloat, alpha: CGFloat)] = tiny ? [] : small
        ? [(0.62, 0.20, 0.045, 0.75), (0.40, 0.14, 0.045, 0.55)]
        : [(0.80, 0.16, 0.022, 0.45), (0.64, 0.30, 0.030, 0.85), (0.48, 0.20, 0.026, 0.65),
           (0.32, 0.26, 0.030, 0.75), (0.17, 0.12, 0.022, 0.40)]
    for st in streaks {
        let h = s * st.thick
        let y = lb.minY + lb.height * st.y - h / 2
        let endX = lb.minX - s * 0.025
        let startX = endX - s * st.length
        guard startX > rect.minX else { continue }
        let r = CGRect(x: startX, y: y, width: endX - startX, height: h)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
        ctx.clip()
        let fade = CGGradient(colorsSpace: cs, colors: [color(0x5A6573, 0), color(0x5A6573, st.alpha)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(fade, start: CGPoint(x: startX, y: 0), end: CGPoint(x: endX, y: 0), options: [])
        ctx.restoreGState()
    }

    // ---- The R: metallic graphite before the portal (macOS), white after it (Windows) ----
    // Soft shadow under the whole letter.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: color(0x0A1A33, 0.35))
    ctx.addPath(letter)
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.restoreGState()

    // "Mac" half: graphite with a metallic sheen.
    ctx.saveGState()
    ctx.addPath(letter)
    ctx.clip()
    ctx.clip(to: CGRect(x: 0, y: 0, width: portalX, height: s))
    let metal = CGGradient(colorsSpace: cs,
                           colors: [color(0x8A94A3), color(0x4B5563), color(0x2D333D)] as CFArray,
                           locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(metal, start: CGPoint(x: 0, y: lb.maxY), end: CGPoint(x: 0, y: lb.minY), options: [])
    ctx.restoreGState()

    // "Windows" half: pure white (already filled by the shadow pass) + a light blue tint at the portal edge.
    ctx.saveGState()
    ctx.addPath(letter)
    ctx.clip()
    ctx.clip(to: CGRect(x: portalX, y: 0, width: s - portalX, height: s))
    let tint = CGGradient(colorsSpace: cs, colors: [color(0xBFE3FF, 0.9), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(tint, start: CGPoint(x: portalX, y: 0), end: CGPoint(x: portalX + lb.width * 0.35, y: 0), options: [])
    ctx.restoreGState()

    // ---- Conversion portal: glowing vertical line with a halo that fades at both ends ----
    let top = lb.maxY + s * 0.085, bottom = lb.minY - s * 0.085
    let glowW = s * (small ? 0.09 : 0.07)
    ctx.saveGState()
    ctx.clip(to: CGRect(x: portalX - glowW / 2, y: bottom, width: glowW, height: top - bottom))
    let halo = CGGradient(colorsSpace: cs, colors: [color(0x7FD3FF, 0), color(0x9BDCFF, 0.55), color(0x7FD3FF, 0)] as CFArray,
                          locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(halo, start: CGPoint(x: portalX - glowW / 2, y: 0), end: CGPoint(x: portalX + glowW / 2, y: 0), options: [])
    ctx.restoreGState()

    let lineW = max(1, s * (small ? 0.03 : 0.014))
    ctx.saveGState()
    ctx.clip(to: CGRect(x: portalX - lineW / 2, y: bottom, width: lineW, height: top - bottom))
    let core = CGGradient(colorsSpace: cs, colors: [color(0xFFFFFF, 0), color(0xFFFFFF, 1), color(0xFFFFFF, 0)] as CFArray,
                          locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(core, start: CGPoint(x: 0, y: bottom), end: CGPoint(x: 0, y: top), options: [])
    ctx.restoreGState()

    ctx.restoreGState()

    let image = ctx.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 20, 24, 32, 40, 48, 64, 128, 180, 256, 512, 1024] {
    let url = outDir.appendingPathComponent("logo-\(size).png")
    try render(size: size).write(to: url)
}
print("Icons generated in \(outDir.path)")
