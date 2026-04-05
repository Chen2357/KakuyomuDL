import Foundation
import RegexBuilder
import ArgumentParser
import EpubBuilder
import CoverCreator
@preconcurrency import Colorful

extension Color: @retroactive _SendableMetatype {}
extension Color: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        let arg: String
        if argument.hasPrefix("#") {
            arg = argument
        } else {
            arg = "#" + argument
        }
        if let color = try? Color.Hex(arg) {
            self = color
        } else {
            return nil
        }
    }
}

extension URL: @retroactive _SendableMetatype {}
extension URL: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(fileURLWithPath: argument)
    }
}

extension CacheManager.Mode: ExpressibleByArgument {
    public init?(argument: String) {
        switch argument {
        case "default":
            self = .useCacheOrDownload
        case "download":
            self = .downloadAndUpdateCache
        case "cache":
            self = .onlyUseCache
        case "ignore":
            self = .ignoreCache
        default:
            return nil
        }
    }
}

@main
struct KakuyomuDownloader: AsyncParsableCommand {
// struct KakuyomuDownloader {
    @Argument(help: "The ID of the work to download")
    var id: String

    @Argument(help: "The folder to output the created EPUB file or cover image")
    var output: URL

    @Option(help: "Override the title of the work")
    var title: String? = nil

    @Option(help: "Override the author of the work")
    var author: String? = nil

    @Option(help: "Override the color of the work")
    var color: Color? = nil

    @Option(help: "The number of chapters to be included")
    var chapterCount: Int? = nil

    @Flag(help: "Whether to flatten the chapters into a single level (no subsections)")
    var flat: Bool = false

    @Option(help: "The font size of the title in the cover")
    var titleFontSize: Double = 200.0

    @Flag(help: "Whether to only create the cover without downloading episodes")
    var coverOnly: Bool = false

    @Option(help: "The folder to cache downloaded HTML files")
    var cache: URL? = nil

    @Option(help: "Cache mode: default (use cache if available), download (always download), cache (only use cache), ignore (ignore cache)")
    var cacheMode: CacheManager.Mode? = nil

    @Flag(help: "Whether to print verbose logs")
    var verbose: Bool = false

    mutating func run() async throws {
        let cacheMode = cacheMode ?? (cache != nil ? .useCacheOrDownload : .ignoreCache)
        let cacheManager = CacheManager(cacheDirectory: cache, mode: cacheMode, verbose: verbose)
        var work = try await cacheManager.loadWork(workId: id)
        if let title = title {
            work.title = title
        }
        if let author = author {
            work.author = author
        }
        if let color = color {
            work.color = color
        }

        if !coverOnly {
            let book = try await work.makeBook(cacheManager: cacheManager, chapterCount: chapterCount, flat: flat, titleFontSize: titleFontSize)
            try book.toEpub(builder: FancyVrtlEpubBuilder(
                depth: flat ? .one : .two,
                colophon: [
                    .heading("『\(book.title)』"),
                    .paragraph("\(book.creators.first?.name ?? work.author) 著"),
                    .horizontalRule,
                    .paragraph("2026年3月26日"),
                    .paragraph("""
                    <a href="https://kakuyomu.jp/">カクヨム</a><br /><span style="font-size:0.8em;">「書ける、読める、伝えられる」<br />小説投稿サイト</span>
                    """)
                ]
            ))
            .writeEpub(to: output.appending(component: "\(title ?? work.title).epub"))
        } else {
            let (l, a, b) = work.color.Lab()
            let color = Color.Lab(l: 1 - l, a: a, b: b)
            let coverData = try CoverCreator(title: work.title, author: work.author, workColor: color, titleFontSize: titleFontSize).createCover()
            try coverData.write(to: output.appending(component: "cover.jpg"))
        }
    }
}