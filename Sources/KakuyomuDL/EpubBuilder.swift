import EpubBuilder
import Foundation
import Colorful
import CoverCreator

extension KakuyomuWork {
    func makeBook(cacheManager: CacheManager, chapterCount: Int? = nil, flat: Bool, titleFontSize: Double, invertColor: Bool = true) async throws
        -> Book
    {
        let chapters = chapterCount.map { self.chapters.prefix($0) } ?? self.chapters[...]
        let workId = self.id
        let cacheManager = cacheManager

        func loadEpisodesInOrder(_ episodeKeys: [String]) async throws -> [KakuyomuEpisode] {
            var payloads = Array<KakuyomuEpisode?>(repeating: nil, count: episodeKeys.count)
            try await withThrowingTaskGroup(of: (Int, KakuyomuEpisode).self) { group in
                for (index, episodeKey) in episodeKeys.enumerated() {
                    group.addTask { [cacheManager, workId, episodeKey, index] in
                        let episode = try await cacheManager.loadEpisode(workId: workId, episodeId: episodeKey)
                        return (index, episode)
                    }
                }

                for try await (index, episode) in group {
                    payloads[index] = episode
                }
            }

            return payloads.map {
                precondition($0 != nil, "Missing episode payload while restoring order")
                return $0!
            }
        }

        var sections: [BookSection] = []
        if flat {
            sections.reserveCapacity(chapters.reduce(0, {$0 + $1.episodeKeys.count}))

            let episodeKeys = chapters.flatMap(\.episodeKeys)
            let episodes = try await loadEpisodesInOrder(episodeKeys)

            for episode in episodes {
                sections.append(
                    BookSection(
                        title: episode.title,
                        content: episode.lines.map(ContentBlock.paragraph)))
            }
        } else {
            sections.reserveCapacity(chapters.count)
            for chapter in chapters {
                let episodes = try await loadEpisodesInOrder(chapter.episodeKeys)
                var subsections: [BookSection] = []
                subsections.reserveCapacity(episodes.count)
                for episode in episodes {
                    subsections.append(
                        BookSection(
                            title: episode.title,
                            content: episode.lines.map(ContentBlock.paragraph)))
                }
                sections.append(BookSection(title: chapter.title, content: [], subsections: subsections))
            }
        }

        let color: Color
        if invertColor {
            let (l, a, b) = self.color.Lab()
            color = Color.Lab(l: 1 - l, a: a, b: b)
        } else {
            color = self.color
        }

        let coverData = try CoverCreator(
            title: title, author: author, workColor: color, titleFontSize: titleFontSize
        ).createCover()

        var book = Book(
            title: title,
            creators: [.init(name: author, role: .author)],
            language: "ja",
            sections: sections,
            images: [.init(name: "cover.jpg", data: coverData, mediaType: .jpeg)],
            coverImageName: "cover.jpg")
        book.applySpecialTransformation(id: self.id)
        return book
    }
}
