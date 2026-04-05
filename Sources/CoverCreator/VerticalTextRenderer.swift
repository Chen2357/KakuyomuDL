import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

public struct _VerticalTextStyle {
    public var fontName: String
    public var fontSize: CGFloat
    public var foregroundColor: CGColor

    public var columnWidthMultiplier: CGFloat
    public var columnSpacingMultiplier: CGFloat
    public var availableHeight: CGFloat

    // public var punctuationCenteringSet: Set<Character>

    public static var `default`: _VerticalTextStyle {
        _VerticalTextStyle(
            fontName: "Hiragino Mincho ProN",
            fontSize: 200,
            foregroundColor: CGColor(gray: 1, alpha: 1),
            columnWidthMultiplier: 1.6,
            columnSpacingMultiplier: 0.35,
            availableHeight: 2000,
            // punctuationCenteringSet: []
            // ["！", "？", "︕", "︖"]
        )
    }
}

struct Glyph {
    let path: CGPath
    let x: CGFloat
    let y: CGFloat

    var boundingBox: CGRect {
        path.boundingBox.offsetBy(dx: x, dy: y)
    }
}

class VerticalTextRenderer {
    let style: _VerticalTextStyle

    let columnWidth: CGFloat
    let columnSpacing: CGFloat
    let font: CTFont

    var foregroundColor: CGColor { style.foregroundColor }
    var availableHeight: CGFloat { style.availableHeight }

    private(set) var glyphs: [Glyph] = []
    private(set) var boundingBox: CGRect = .null
    private(set) var currentRightEdgeX: CGFloat = 0

    init(style: _VerticalTextStyle) {
        self.style = style
        self.columnWidth = style.fontSize * style.columnWidthMultiplier
        self.columnSpacing = style.fontSize * style.columnSpacingMultiplier
        self.font = CTFontCreateWithName(style.fontName as CFString, style.fontSize, nil)
    }
}

extension VerticalTextRenderer {
    func createAttributedString(_ text: String) -> NSAttributedString {
        .init(
            string: text,
            attributes: [
                .init(kCTFontAttributeName as String): font,
                .init(kCTForegroundColorAttributeName as String): foregroundColor,
                .init(kCTVerticalFormsAttributeName as String): true,
                .init(kCTBaselineClassAttributeName as String): kCTBaselineClassIdeographicCentered,
            ])
    }

    func createFrame(text: String) -> CTFrame {
        let attributedText = createAttributedString(text)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)

        let frameWidth = columnWidth + CGFloat(text.count) * (columnWidth + columnSpacing)
        let framePath = CGPath(
            rect: CGRect(x: currentRightEdgeX, y: 0, width: frameWidth, height: availableHeight), transform: nil)

        let frameAttributes =
            [
                kCTFrameProgressionAttributeName as String: CTFrameProgression.rightToLeft.rawValue
            ] as CFDictionary

        return CTFramesetterCreateFrame(
            framesetter, CFRange(location: 0, length: attributedText.length), framePath,
            frameAttributes)
    }

    func append(text: String) {
        let nsText = text as NSString
        let frame = createFrame(text: text)
        let lines = frame.lines
        let lineOrigins = frame.lineOrigins
        for (line, origin) in zip(lines, lineOrigins) {
            let runs = CTLineGetGlyphRuns(line) as! [CTRun]
            for run in runs {
                append(run: run, origin: origin, nsText: nsText)
            }
        }
    }

    func append(run: CTRun, origin: CGPoint, nsText: NSString) {
        let glyphCount = run.glyphCount
        guard glyphCount > 0 else { return }

        let lineGlyphs = run.glyphs
        let positions = run.positions
        // let stringIndices = run.stringIndices

        for i in 0..<glyphCount {
            guard let glyphPath = CTFontCreatePathForGlyph(font, lineGlyphs[i], nil) else {
                continue
            }

            // let glyphBounds = glyphPath.boundingBox
            let glyphX = origin.x + positions[i].x
            let glyphY = origin.y + positions[i].y

            // if stringIndices[i] >= 0,
            //     stringIndices[i] < nsText.length,
            //     let character = nsText.substring(
            //         with: nsText.rangeOfComposedCharacterSequence(at: stringIndices[i])
            //     ).first,
            //     style.punctuationCenteringSet.contains(character)
            // {
            //     glyphX = origin.x - glyphBounds.midX
            // } else {
            //     glyphX = origin.x + positions[i].x
            // }

            let glyph = Glyph(path: glyphPath, x: glyphX, y: glyphY)
            glyphs.append(glyph)
            boundingBox = boundingBox.union(glyph.boundingBox)
        }

        currentRightEdgeX -= columnWidth + columnSpacing
    }
}

extension CGContext {
    func draw(_ glyph: Glyph, at position: CGPoint) {
        saveGState()
        translateBy(x: position.x + glyph.x, y: position.y + glyph.y)
        addPath(glyph.path)
        fillPath()
        restoreGState()
    }

    func draw(_ verticalText: VerticalTextRenderer, at position: CGPoint) {
        self.setFillColor(verticalText.foregroundColor)
        for glyph in verticalText.glyphs {
            draw(glyph, at: position)
        }
    }
}