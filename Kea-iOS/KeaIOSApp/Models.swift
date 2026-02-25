import Foundation

struct EpisodeListEntry: Identifiable, Hashable {
    let id = UUID()
    let episodeSequence: String
    let episodeNo: Int
    let episodeTitle: String
    let url: URL
}

struct ToonListEntryInfo: Identifiable, Hashable {
    let id = UUID()
    let titleNo: Int
    let toonTitleName: String
    let toonTranslationLanguageCode: String
    let toonTranslationTeamVersion: String
    let startDownloadAtEpisode: Int
    let stopDownloadAtEpisode: Int?
    let url: URL
}

struct ToonListEntry: Identifiable, Hashable {
    let id = UUID()
    let toonInfo: ToonListEntryInfo
    let episodeList: [EpisodeListEntry]
}

struct DownloadedToonChapterFileInfo: Hashable {
    let filePath: URL
    let filePathInArchive: String
}

enum SaveAsOption: String, CaseIterable, Identifiable {
    case pdf = "PDF file"
    case cbz = "CBZ file"
    case multipleImages = "multiple images"
    case oneImage = "one image (may be lower in quality)"

    var id: String { rawValue }

    var bundleExtension: String {
        switch self {
        case .pdf: return "pdf"
        case .cbz: return "cbz"
        case .oneImage: return "png"
        case .multipleImages: return ""
        }
    }

    var isBundle: Bool {
        self != .multipleImages
    }
}
