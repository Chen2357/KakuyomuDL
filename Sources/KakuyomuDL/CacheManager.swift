import Foundation

actor CacheManager {
    let cacheDirectory: URL?
    var mode: Mode
    var verbose: Bool

    enum Mode {
        case useCacheOrDownload
        case downloadAndUpdateCache
        case onlyUseCache
        case ignoreCache
    }

    init(cacheDirectory: URL?, mode: Mode = .useCacheOrDownload, verbose: Bool = false) {
        self.cacheDirectory = cacheDirectory
        self.mode = mode
        self.verbose = verbose
    }

    func printIfVerbose(_ message: String) {
        if verbose {
            print(message)
        }
    }

    enum CacheError: Error {
        case cacheDirectoryNotSet
        case episodeNotInCache(workId: String, episodeId: String)
    }

    func loadWork(workId: String) async throws -> KakuyomuWork {
        printIfVerbose("Loading work \(workId)")
        switch mode {
        case .useCacheOrDownload:
            let workCacheURL = try workCacheURL(workId: workId)
            if let html = try? String(contentsOf: workCacheURL, encoding: .utf8) {
                let work = try KakuyomuWork(fromHTML: html)
                printIfVerbose("Loaded work \(work.title) (\(workId)) from cache")
                return work
            } else {
                let work = try await downloadWork(workId: workId, cache: true)
                printIfVerbose("Downloaded work \(work.title) (\(workId)) and updated cache")
                return work
            }

        case .downloadAndUpdateCache:
            let work = try await downloadWork(workId: workId, cache: true)
            printIfVerbose("Downloaded work \(work.title) (\(workId)) and updated cache")
            return work

        case .onlyUseCache:
            let workCacheURL = try workCacheURL(workId: workId)
            let html = try String(contentsOf: workCacheURL, encoding: .utf8)
            let work = try KakuyomuWork(fromHTML: html)
            printIfVerbose("Loaded work \(work.title) (\(workId)) from cache")
            return work

        case .ignoreCache:
            let work = try await downloadWork(workId: workId, cache: false)
            printIfVerbose("Downloaded work \(work.title) (\(workId)) without updating cache")
            return work
        }
    }

    func downloadWork(workId: String, cache: Bool) async throws -> KakuyomuWork {
        let url = URL(string: "https://kakuyomu.jp/works/\(workId)")!
        let session = URLSession(configuration: .default)
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        if cache {
            let workCacheURL = try workCacheURL(workId: workId)
            try html.write(to: workCacheURL, atomically: true, encoding: .utf8)
        }
        return try KakuyomuWork(fromHTML: html)
    }

    func loadEpisode(workId: String, episodeId: String) async throws -> KakuyomuEpisode {
        printIfVerbose("Loading episode \(workId)-\(episodeId)")
        switch mode {
        case .useCacheOrDownload:
            let episodeCacheURL = try episodeCacheURL(workId: workId, episodeId: episodeId)
            if let episodeHTML = try? String(contentsOf: episodeCacheURL, encoding: .utf8) {
                let episode = try KakuyomuEpisode(fromHTML: episodeHTML)
                printIfVerbose("Loaded episode \(episode.title) (\(workId)-\(episodeId)) from cache")
                return episode
            } else {
                let episode = try await downloadEpisode(workId: workId, episodeId: episodeId, cache: true)
                printIfVerbose("Downloaded episode \(episode.title) (\(workId)-\(episodeId)) and updated cache")
                return episode
            }

        case .downloadAndUpdateCache:
            let episode = try await downloadEpisode(workId: workId, episodeId: episodeId, cache: true)
            printIfVerbose("Downloaded episode \(episode.title) (\(workId)-\(episodeId)) and updated cache")
            return episode

        case .onlyUseCache:
            let episodeCacheURL = try episodeCacheURL(workId: workId, episodeId: episodeId)
            let episodeHTML = try String(contentsOf: episodeCacheURL, encoding: .utf8)
            let episode = try KakuyomuEpisode(fromHTML: episodeHTML)
            printIfVerbose("Loaded episode \(episode.title) (\(workId)-\(episodeId)) from cache")
            return episode

        case .ignoreCache:
            let episode = try await downloadEpisode(workId: workId, episodeId: episodeId, cache: false)
            printIfVerbose("Downloaded episode \(episode.title) (\(workId)-\(episodeId)) without updating cache")
            return episode
        }
    }

    func downloadEpisode(workId: String, episodeId: String, cache: Bool) async throws -> KakuyomuEpisode {
        let url = URL(string: "https://kakuyomu.jp/works/\(workId)/episodes/\(episodeId)")!
        let session = URLSession(configuration: .default)
        let (data, _) = try await session.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        if cache {
            let episodeCacheURL = try episodeCacheURL(workId: workId, episodeId: episodeId)
            try html.write(to: episodeCacheURL, atomically: true, encoding: .utf8)
        }
        return try KakuyomuEpisode(fromHTML: html)
    }

    func workCacheURL(workId: String) throws -> URL {
        guard let cacheDirectory = cacheDirectory else {
            throw CacheError.cacheDirectoryNotSet
        }
        return cacheDirectory.appending(component: "\(workId).html")
    }

    func episodeCacheURL(workId: String, episodeId: String) throws -> URL {
        guard let cacheDirectory = cacheDirectory else {
            throw CacheError.cacheDirectoryNotSet
        }
        return cacheDirectory.appending(component: "\(workId)-\(episodeId).html")
    }
}