import Colorful
import CoverCreator
import EpubBuilder
import Foundation

struct KakuyomuWork {
    var id: String
    var title: String
    var author: String
    var color: Color
    var chapters: [Chapter]

    struct Chapter {
        var title: String
        var episodeKeys: [String]
    }

    enum KakuyomuWorkError: Error {
        case metadataNotFound
        case tableOfContentsNotFound

        case episodeNotFound(episodeKey: String)
        case chapterNotFound(chapterKey: String)
        case episodesInChapterNotFound(chapterKey: String)
    }

    init(fromHTML html: String) throws {
        let regex =
            #/style="background-color:#([0-9A-Fa-f]{6})".*?<a title="([^"]+)" href="\/works\/(\d+)"[^>]*>.*?<\/a>.*?<a href="\/users\/[^"]+"[^>]*>([^<]+)<\/a>/#
        guard let match = html.firstMatch(of: regex) else {
            throw KakuyomuWorkError.metadataNotFound
        }
        self.color = try Color.Hex("#" + String(match.1).lowercased())
        self.title = String(match.2)
        self.id = String(match.3)
        self.author = String(match.4)

        let tocRegex = /"tableOfContents":\[((?:{"__ref":"TableOfContentsChapter:\d+"},?)*)\]/
        let tocChapterRegex = /{"__ref":"TableOfContentsChapter:(\d+)"}/
        func chapterEpisodesRegex(chapterID: String) -> some RegexComponent<(Substring, Substring)>
        {
            try! Regex(
                #""TableOfContentsChapter:\#(chapterID)":{"__typename":"TableOfContentsChapter","id":"\#(chapterID)","episodeUnions":\[((?:{"__ref":"Episode:\d+"},?)*)\],"chapter":{"__ref":"Chapter:\#(chapterID)"}}"#
            )
        }
        let tocEpisodeRegex = /{"__ref":"Episode:(\d+)"}/

        func chapterTitleRegex(chapterID: String) -> some RegexComponent<(Substring, Substring)> {
            try! Regex(
                #""Chapter:\#(chapterID)":{"__typename":"Chapter","id":"\#(chapterID)","level":1,"title":"([^"]*)"}"#
            )
        }

        func episodeTitleRegex(episodeID: String) -> some RegexComponent<(Substring, Substring)> {
            try! Regex(
                #""Episode:\#(episodeID)":{"__typename":"Episode","id":"\#(episodeID)","title":"([^"]*)","publishedAt":"[^"]*"}"#
            )
        }

        guard let toc = html.firstMatch(of: tocRegex)?.1 else {
            throw KakuyomuWorkError.tableOfContentsNotFound
        }
        let chapterIds = toc.matches(of: tocChapterRegex).map { String($0.1) }

        var chapters: [Chapter] = []
        for chapterId in chapterIds {
            guard let match = html.firstMatch(of: chapterTitleRegex(chapterID: chapterId)) else {
                print("The chapter title for \(chapterId) was not found. Possibly is because the chapter is not level 1 and only level 1 chapters are considered in the current implementation. Skipping chapter with ID \(chapterId).")
                continue
            }
            let title = String(match.1)
            guard let episodeMatches = html.firstMatch(of: chapterEpisodesRegex(chapterID: chapterId)) else {
                throw KakuyomuWorkError.episodesInChapterNotFound(chapterKey: "TableOfContentsChapter:\(chapterId)")
            }
            let episodeKeys = episodeMatches.1.matches(of: tocEpisodeRegex).map { String($0.1) }
            chapters.append(Chapter(title: title, episodeKeys: episodeKeys))
        }
        self.chapters = chapters
    }
}

struct KakuyomuEpisode: Codable {
    var title: String
    var lines: [String]

    init(title: String, lines: [String] = []) {
        self.title = title
        self.lines = lines
    }

    enum KakuyomuEpisodeError: Error {
        case failedToFindTitle
    }

    init(fromHTML html: String) throws {
        let titleRegex = /<p class="widget-episodeTitle js-vertical-composition-item">([^<]+)<\/p>/
        guard let titleMatch = html.firstMatch(of: titleRegex) else {
            throw KakuyomuEpisodeError.failedToFindTitle
        }
        title = String(titleMatch.1)

        // let lineRegex = /<p id="p\d+"(?: class="blank")?>(.*?)<\/p>/
        let lineRegex = /<p id="p\d+">(.*?)<\/p>/
        let replacements: [String: String] = [
            "&amp;": "＆",
            "&quot;": "\"",
        ]
        lines = html.matches(of: lineRegex).compactMap { match in
            let line = String(match.1)
            if line.allSatisfy({ [" ", "\t", "　"].contains($0) }) {
                return nil
            } else {
                return replacements.reduce(line) { result, replacement in
                    result.replacingOccurrences(of: replacement.key, with: replacement.value)
                }
            }
        }
    }

    init(fromCache url: URL) throws {
        let jsonData = try Data(contentsOf: url)
        self = try JSONDecoder().decode(KakuyomuEpisode.self, from: jsonData)
    }

    func write(to url: URL) throws {
        let jsonData = try JSONEncoder().encode(self)
        try jsonData.write(to: url)
    }
}
