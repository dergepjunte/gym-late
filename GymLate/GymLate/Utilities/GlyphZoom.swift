import SwiftUI
import UIKit

/// Wo und wie weit man in ein Motiv hineinzoomen muss, damit nur noch seine Farbe zu sehen ist.
struct GlyphZoomSpec {
    /// Punkt im Motiv (0...1), der am tiefsten in einer ausgefuellten Flaeche liegt.
    var anchor: UnitPoint
    /// Radius des groessten Kreises, der dort noch ins Motiv passt (in pt).
    var inradius: CGFloat
    /// Farbe an diesem Punkt.
    var color: Color
}

enum GlyphMeasure {
    /// Rendert das Motiv, sucht per Distanztransformation den Punkt mit dem groessten Abstand zum
    /// Rand und liest dort die Farbe. So passt der Zoom fuer Schrift, Hantel und Flamme gleichermassen.
    @MainActor
    static func measure<V: View>(_ view: V) -> GlyphZoomSpec? {
        let renderer = ImageRenderer(content: view.fixedSize())
        let scale: CGFloat = 4
        renderer.scale = scale
        guard let cg = renderer.uiImage?.cgImage else { return nil }
        let w = cg.width, h = cg.height
        guard w > 2, h > 2 else { return nil }
        var px = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        let inf: Float = 1e9
        var d = [Float](repeating: 0, count: w * h)
        for i in 0..<(w * h) where px[i * 4 + 3] > 200 { d[i] = inf }
        @inline(__always) func at(_ x: Int, _ y: Int) -> Float {
            (x < 0 || y < 0 || x >= w || y >= h) ? 0 : d[y * w + x]
        }
        let diag: Float = 1.4142
        for y in 0..<h {
            for x in 0..<w where d[y * w + x] > 0 {
                d[y * w + x] = min(d[y * w + x], at(x - 1, y) + 1, at(x, y - 1) + 1,
                                   at(x - 1, y - 1) + diag, at(x + 1, y - 1) + diag)
            }
        }
        for y in stride(from: h - 1, through: 0, by: -1) {
            for x in stride(from: w - 1, through: 0, by: -1) where d[y * w + x] > 0 {
                d[y * w + x] = min(d[y * w + x], at(x + 1, y) + 1, at(x, y + 1) + 1,
                                   at(x + 1, y + 1) + diag, at(x - 1, y + 1) + diag)
            }
        }
        var best = 0, bestVal: Float = 0
        for i in 0..<(w * h) where d[i] > bestVal { bestVal = d[i]; best = i }
        guard bestVal > 0, bestVal < inf / 2 else { return nil }

        let a = max(Float(px[best * 4 + 3]), 1)
        func channel(_ o: Int) -> Double { Double(min(255, Float(px[best * 4 + o]) * 255 / a)) / 255 }
        let x = best % w, y = best / w
        return GlyphZoomSpec(
            anchor: UnitPoint(x: (CGFloat(x) + 0.5) / CGFloat(w), y: (CGFloat(y) + 0.5) / CGFloat(h)),
            inradius: CGFloat(bestVal) / scale,
            color: Color(red: channel(0), green: channel(1), blue: channel(2)))
    }
}
