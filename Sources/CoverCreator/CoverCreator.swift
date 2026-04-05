import CoreGraphics
import Foundation
import Colorful

public enum CoverCreationError: Error {
    case invalidImageData
    case failedToCreateContext
    case cannotMakeImageFromContext
    case failedToEncodeJPEG
}

func drawJPEG(data: Data, using drawing: (CGContext) throws -> Void) throws -> Data {
    guard let image = CGImage.from(data: data) else {
        throw CoverCreationError.invalidImageData
    }
    guard let context = image.createDrawingContext() else {
        throw CoverCreationError.failedToCreateContext
    }

    try drawing(context)

    guard let outputImage = context.makeImage() else {
        throw CoverCreationError.cannotMakeImageFromContext
    }

    guard let output = outputImage.toJPEGData() else {
        throw CoverCreationError.failedToEncodeJPEG
    }
    return output
}

public class CoverCreator {
    public let background: Data
    public let title: String
    public let author: String
    public let workColor: Color
    public let titleFontSize: Double

    public init(title: String, author: String, workColor: Color, titleFontSize: Double = 200) {
        let coverURL = Bundle.module.url(forResource: "cover", withExtension: "jpg")!
        let coverData = try! Data(contentsOf: coverURL)

        self.background = coverData
        self.title = title
        self.author = author
        self.workColor = workColor
        self.titleFontSize = titleFontSize
    }

    public init(background: Data, title: String, author: String, workColor: Color, titleFontSize: Double = 200) {
        self.background = background
        self.title = title
        self.author = author
        self.workColor = workColor
        self.titleFontSize = titleFontSize
    }

    public func createCover() throws -> Data {
        var titleStyle = _VerticalTextStyle.default
        titleStyle.fontSize = titleFontSize

        let authorStyle = _VerticalTextStyle(
            fontName: "Hiragino Mincho ProN", fontSize: 125,
            foregroundColor: CGColor(gray: 1, alpha: 1),
            columnWidthMultiplier: 1.0, columnSpacingMultiplier: 1.0, availableHeight: 1800)

        return try drawJPEG(data: background) {
            context in
            let titleRenderer = VerticalTextRenderer(style: titleStyle)
            titleRenderer.append(text: title)
            let titleOrigin = CGPoint(
                x: (CGFloat(context.width) - titleRenderer.boundingBox.width) / 2 - titleRenderer.boundingBox.minX,
                y: (CGFloat(context.height) - titleRenderer.boundingBox.height) / 2 - titleRenderer.boundingBox.minY
            )
            context.draw(
                titleRenderer,
                at: titleOrigin)

            let workBox = CGRect(
                x: titleOrigin.x + titleRenderer.boundingBox.maxX + 80,
                y: titleOrigin.y + titleRenderer.boundingBox.maxY - 200,
                width: 30,
                height: 200
            )
            context.setFillColor(workColor.cgColor)
            context.fill(workBox)

            let authorRenderer = VerticalTextRenderer(style: authorStyle)
            authorRenderer.append(text: author)
            let authorOrigin = CGPoint(
                x: 125 - authorRenderer.boundingBox.minX,
                y: 125 - authorRenderer.boundingBox.minY)
            context.draw(
                authorRenderer,
                at: authorOrigin)

            let lineX = authorOrigin.x + authorRenderer.boundingBox.maxX + 80
            context.setStrokeColor(CGColor(gray: 0.5, alpha: 0.5))
            context.setLineWidth(3)
            context.move(to: CGPoint(x: lineX, y: 100))
            context.addLine(to: CGPoint(x: lineX, y: CGFloat(context.height) - 100))
            context.strokePath()
        }
    }
}
