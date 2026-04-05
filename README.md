# KakuyomuDL

KakuyomuDL is a Swift command-line tool for downloading and converting Kakuyomu works.

This README focuses on the `CoverGenerator` module, especially the vertical Japanese cover-title rendering pipeline.

## Tech Stack

- Language: Swift (Swift Package Manager project)
- Text rendering: CoreText (`CTFramesetter`, `CTLine`, `CTRun`)
- 2D drawing: CoreGraphics (`CGContext`, `CGPath`, `CGImage`)
- Image decode/encode: ImageIO (`CGImageSource`, `CGImageDestination`)
- Output format: JPEG (`UTType.jpeg`)

## Where The Logic Lives

- Main implementation: `Sources/CoverGenerator/CoverGenerator.swift`
- Public entry point: `generateCover(title:)`
- Rendering entry points:
  - `addVerticalJapaneseText(to:text:style:)` (recommended)
  - `addVerticalJapaneseText(to:text:font:fontSize:)` (compat wrapper)

## High-Level Rendering Flow

1. Load base image
- `generateCover(title:)` loads `cover.jpg` from package resources.

2. Decode image and create drawing context
- `getCGImage(from:)` decodes input bytes into `CGImage`.
- `createDrawingContext(for:)` creates a destination `CGContext` and draws the base image into it.

3. Build style + font
- `VerticalTextStyle` controls typography and layout knobs.
- `resolveVerticalFontName(from:fallbackPostScriptName:)` resolves a usable installed font.

4. Normalize vertical punctuation
- `normalizeVerticalPunctuation(_:map:)` replaces horizontal punctuation with vertical forms (for example `！` to `︕`).

5. Segment text by explicit line breaks
- Input text is split on `\n`.
- Each segment is rendered as a distinct logical block.

6. Auto-wrap within each segment
- `createSegmentDrawOps(...)` creates a CoreText frame with fixed height and enough width to allow wrapping into additional vertical columns.

7. Extract glyph seeds per line
- `extractLineGlyphSeeds(...)` reads glyph paths and positions from CoreText runs.
- Punctuation centering is adjusted here (horizontal centering for selected punctuation glyphs).

8. Apply overlap tuning
- `applyVerticalOverlap(...)` compacts spacing for characters like small kana and brackets.
- Overlap amount is style-driven and clamped by minimum safe advance to avoid hard collisions.

9. Compose segment blocks right-to-left
- Segment draw ops are shifted so the first segment is rightmost and later segments move left.

10. Global centering
- Bounds of all draw ops are accumulated.
- A final global offset centers the full rendered block both horizontally and vertically.

11. Draw and encode
- All glyph paths are drawn into the context.
- Result is encoded as JPEG via `encodeJPEG(from:)`.

## Why This Is Structured This Way

The module separates concerns to keep behavior tunable without touching low-level rendering code:

- Image IO isolated from layout logic
- Font resolution isolated from text shaping
- Line extraction isolated from spacing heuristics
- Encoding isolated from drawing

This makes it easier to test and customize one layer at a time.

## Customization Guide

Use `VerticalTextStyle.defaultCover` and override only what you need.

Typical knobs:

- Typography:
  - `fontStack`
  - `fallbackPostScriptName`
  - `fontSize`
  - `textColor`

- Layout:
  - `columnWidthMultiplier`
  - `columnGapMultiplier`
  - `verticalMargin`

- Spacing behavior:
  - `smallKanaBaseOverlap`
  - `openingBracketBaseOverlap`
  - `closingBracketBaseOverlap`
  - `minAdvanceMultiplier`

- Context-sensitive tuning:
  - `smallKanaTuning`
  - `openingBracketTuning`
  - `closingBracketTuning`
  - `bracketNeighborTuning`
  - `smallKanaNeighborTuning`

- Punctuation behavior:
  - `punctuationNormalization`
  - `punctuationCenteringSet`

Example pattern:

```swift
var style = VerticalTextStyle.defaultCover
style.fontSize = 180
style.columnGapMultiplier = 0.28
style.smallKanaBaseOverlap = 0.35

let output = try addVerticalJapaneseText(to: coverData, text: title, style: style)
```

## Notes

- The renderer is optimized for vertical Japanese title text, not general rich text.
- Some visual differences can still appear across fonts because glyph metrics differ by typeface.
- Build warnings about ImageMagick target version are unrelated to this text-rendering pipeline.
