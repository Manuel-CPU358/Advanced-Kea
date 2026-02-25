import Foundation
import UIKit

@MainActor
final class MainViewModel: ObservableObject {
    @Published var urlInput = ""
    @Published var queue: [ToonListEntryInfo] = []
    @Published var saveAs: SaveAsOption = .pdf
    @Published var highestQuality = false
    @Published var cartoonFolders = true
    @Published var chapterFolders = false
    @Published var skipDownloadedChapters = false
    @Published var progress: Double = 0
    @Published var processInfo = "Idle"
    @Published var saveFolder: URL?
    @Published var isDownloading = false

    private let api = WebtoonAPI()

    func addToQueue() {
        let lines = urlInput
            .split(whereSeparator: \ .isNewline)
            .map(String.init)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        for line in lines where KeaHelpers.isValidWebtoonListURL(line) {
            guard let parsed = parseQueueLine(line), !queue.contains(where: { isSameToon($0, parsed) }) else { continue }
            queue.append(parsed)
        }
        urlInput = ""
    }

    func removeSelected(at offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }

    func removeAll() {
        queue.removeAll()
    }

    func startDownload() async {
        guard !isDownloading else { return }
        guard let saveFolder else {
            processInfo = "Please select a save folder"
            return
        }

        isDownloading = true
        defer { isDownloading = false }

        do {
            let toons = try await withThrowingTaskGroup(of: ToonListEntry.self) { group in
                for item in queue {
                    group.addTask { try await self.api.fetchEpisodes(for: item) }
                }
                var fetched: [ToonListEntry] = []
                for try await toon in group {
                    fetched.append(toon)
                }
                return fetched
            }

            var done: Double = 0
            let total = Double(max(1, toons.reduce(0) { $0 + $1.episodeList.count }))

            for toon in toons {
                try await downloadComic(toon, baseFolder: saveFolder)
                done += Double(toon.episodeList.count)
                progress = done / total
            }

            processInfo = "Done"
        } catch {
            processInfo = "Failed: \(error.localizedDescription)"
        }
    }

    private func parseQueueLine(_ line: String) -> ToonListEntryInfo? {
        guard let url = URL(string: line),
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let titleNoString = comps.queryItems?.first(where: { $0.name == "title_no" })?.value,
              let titleNo = Int(titleNoString) else {
            return nil
        }

        let titleName = url.pathComponents.dropLast().last ?? "Unknown"
        let language = comps.queryItems?.first(where: { $0.name == "language" })?.value ?? "default"
        let team = comps.queryItems?.first(where: { $0.name == "teamVersion" })?.value ?? "default"

        return ToonListEntryInfo(
            titleNo: titleNo,
            toonTitleName: titleName,
            toonTranslationLanguageCode: language,
            toonTranslationTeamVersion: team,
            startDownloadAtEpisode: 1,
            stopDownloadAtEpisode: nil,
            url: url
        )
    }

    private func isSameToon(_ lhs: ToonListEntryInfo, _ rhs: ToonListEntryInfo) -> Bool {
        lhs.titleNo == rhs.titleNo &&
        lhs.toonTitleName == rhs.toonTitleName &&
        lhs.toonTranslationLanguageCode == rhs.toonTranslationLanguageCode &&
        lhs.toonTranslationTeamVersion == rhs.toonTranslationTeamVersion
    }

    private func downloadComic(_ toon: ToonListEntry, baseFolder: URL) async throws {
        let fm = FileManager.default
        var comicFolder = baseFolder.appendingPathComponent(ToonExporters.toonSavePath(toon.toonInfo), isDirectory: true)
        if !cartoonFolders { comicFolder = baseFolder }
        try fm.createDirectory(at: comicFolder, withIntermediateDirectories: true)

        let suffix = (highestQuality && toon.toonInfo.toonTranslationLanguageCode == "default") ? "[HQ]" : ""

        for (index, episode) in toon.episodeList.enumerated() {
            processInfo = "Downloading \(toon.toonInfo.toonTitleName) ch.\(episode.episodeNo)"

            let episodeName = ToonExporters.episodeSavePath(episode, suffix: suffix)
            let archiveBase = comicFolder.appendingPathComponent(episodeName)

            if skipDownloadedChapters && saveAs.isBundle {
                let existing = archiveBase.appendingPathExtension(saveAs.bundleExtension)
                if fm.fileExists(atPath: existing.path) { continue }
            }

            var episodeFolder = comicFolder
            var createdEpisodeFolder = false
            if chapterFolders || saveAs.isBundle {
                episodeFolder = comicFolder.appendingPathComponent(episodeName, isDirectory: true)
                try fm.createDirectory(at: episodeFolder, withIntermediateDirectories: true)
                createdEpisodeFolder = true
            }

            var downloaded: [DownloadedToonChapterFileInfo] = []
            var imageIndex = 0

            let imageURLs: [URL]
            if toon.toonInfo.toonTranslationLanguageCode == "default" {
                imageURLs = try await api.fetchOfficialImageURLs(episodeURL: episode.url)
            } else if let fan = try await api.fetchFanTranslation(
                episodeNo: episode.episodeNo,
                titleNo: toon.toonInfo.titleNo,
                languageCode: toon.toonInfo.toonTranslationLanguageCode,
                teamVersion: toon.toonInfo.toonTranslationTeamVersion
            ) {
                let warning = KeaHelpers.drawUnofficialWarning(languageName: fan.name, teamName: fan.team)
                let warningName = String(format: "%05d.jpg", imageIndex)
                let warningURL = episodeFolder.appendingPathComponent(warningName)
                if let jpeg = warning.jpegData(compressionQuality: 0.9) {
                    try jpeg.write(to: warningURL)
                    downloaded.append(.init(filePath: warningURL, filePathInArchive: warningName))
                    imageIndex += 1
                }
                imageURLs = fan.imageURLs
            } else {
                imageURLs = []
            }

            for imageURL in imageURLs {
                var finalURL = imageURL
                if highestQuality && toon.toonInfo.toonTranslationLanguageCode == "default" {
                    finalURL = KeaHelpers.removeQueryItem(named: "type", from: imageURL)
                }

                let ext = KeaHelpers.getFileExtension(from: finalURL)
                let imageName = String(format: "%05d.%@", imageIndex, ext)
                let fileURL = episodeFolder.appendingPathComponent(imageName)

                do {
                    let data = try await api.downloadBinary(url: finalURL, referer: episode.url)
                    try data.write(to: fileURL)
                } catch {
                    let fallback = KeaHelpers.drawNotFoundImage(imageNumber: imageIndex)
                    let fallbackURL = episodeFolder.appendingPathComponent("\(String(format: "%05d", imageIndex))_failed.png")
                    if let png = fallback.pngData() { try png.write(to: fallbackURL) }
                    downloaded.append(.init(filePath: fallbackURL, filePathInArchive: fallbackURL.lastPathComponent))
                    imageIndex += 1
                    continue
                }

                downloaded.append(.init(filePath: fileURL, filePathInArchive: imageName))
                imageIndex += 1
            }

            if saveAs.isBundle {
                try ToonExporters.createBundledFile(saveAs: saveAs, episodeSavePath: archiveBase, downloadedFiles: downloaded)
                if createdEpisodeFolder { try? fm.removeItem(at: episodeFolder) }
            }

            progress = Double(index + 1) / Double(max(1, toon.episodeList.count))
        }
    }
}
