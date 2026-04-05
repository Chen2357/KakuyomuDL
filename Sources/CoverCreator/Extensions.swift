import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers
import Colorful

extension CGImage {
    static func from(data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    func createDrawingContext() -> CGContext? {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo) else {
            return nil
        }

        context.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

        return context
    }

    func toJPEGData() -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, self, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }
}

extension CTFrame {
    var lines: [CTLine] {
        CTFrameGetLines(self) as! [CTLine]
    }

    var lineOrigins: [CGPoint] {
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(self, CFRange(location: 0, length: 0), &origins)
        return origins
    }
}

extension CTRun {
    var glyphCount: Int {
        CTRunGetGlyphCount(self)
    }

    var glyphs: [CGGlyph] {
        var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
        CTRunGetGlyphs(self, CFRange(location: 0, length: 0), &glyphs)
        return glyphs
    }

    var positions: [CGPoint] {
        var positions = [CGPoint](repeating: .zero, count: glyphCount)
        CTRunGetPositions(self, CFRange(location: 0, length: 0), &positions)
        return positions
    }

    var stringIndices: [CFIndex] {
        var indices = [CFIndex](repeating: 0, count: glyphCount)
        CTRunGetStringIndices(self, CFRange(location: 0, length: 0), &indices)
        return indices
    }
}

extension Color {
    var cgColor: CGColor {
        let (r, g, b) = self.Values()
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }
}