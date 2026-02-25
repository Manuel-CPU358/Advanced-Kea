import Foundation
import UIKit
import PDFKit

enum ToonExporters {
    static func createBundledFile(saveAs: SaveAsOption, episodeSavePath: URL, downloadedFiles: [DownloadedToonChapterFileInfo]) throws {
        switch saveAs {
        case .pdf:
            try createPDF(outputURL: episodeSavePath.appendingPathExtension("pdf"), downloadedFiles: downloadedFiles)
        case .oneImage:
            try createMergedImage(outputURL: episodeSavePath.appendingPathExtension("png"), downloadedFiles: downloadedFiles)
        case .cbz:
            try createCBZ(outputURL: episodeSavePath.appendingPathExtension("cbz"), downloadedFiles: downloadedFiles)
        case .multipleImages:
            return
        }
    }

    static func toonSavePath(_ info: ToonListEntryInfo) -> String {
        var languageCode = info.toonTranslationLanguageCode == "default" ? "" : info.toonTranslationLanguageCode
        if info.toonTranslationLanguageCode != "default", info.toonTranslationTeamVersion != "default" {
            languageCode += "-\(info.toonTranslationTeamVersion)"
        }
        if !languageCode.isEmpty {
            languageCode = "[\(languageCode)]"
        }
        return "\(languageCode)\(KeaHelpers.sanitizeFileName(info.toonTitleName))[\(String(format: "%06d", info.titleNo))]"
    }

    static func episodeSavePath(_ episode: EpisodeListEntry, suffix: String) -> String {
        "[\(episode.episodeSequence)](\(episode.episodeNo)) \(KeaHelpers.sanitizeFileName(episode.episodeTitle))\(suffix)"
    }

    private static func createPDF(outputURL: URL, downloadedFiles: [DownloadedToonChapterFileInfo]) throws {
        let doc = PDFDocument()
        var index = 0
        for file in downloadedFiles {
            guard let image = UIImage(contentsOfFile: file.filePath.path), let page = PDFPage(image: image) else { continue }
            doc.insert(page, at: index)
            index += 1
        }
        doc.write(to: outputURL)
    }

    private static func createMergedImage(outputURL: URL, downloadedFiles: [DownloadedToonChapterFileInfo]) throws {
        let images = downloadedFiles.compactMap { UIImage(contentsOfFile: $0.filePath.path) }
        guard let first = images.first else { return }
        let totalHeight = images.reduce(CGFloat(0)) { $0 + $1.size.height }
        let maxHeight = min(totalHeight, KeaHelpers.maxSingleImageHeight)
        let width = first.size.width * (maxHeight / totalHeight)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: maxHeight))
        let merged = renderer.image { _ in
            var y: CGFloat = 0
            let ratio = maxHeight / totalHeight
            for image in images {
                let h = image.size.height * ratio
                image.draw(in: CGRect(x: 0, y: y, width: width, height: h))
                y += h
            }
        }
        if let png = merged.pngData() {
            try png.write(to: outputURL)
        }
    }

    private static func createCBZ(outputURL: URL, downloadedFiles: [DownloadedToonChapterFileInfo]) throws {
        let fm = FileManager.default
        let tempFolder = outputURL.deletingPathExtension()
        try? fm.removeItem(at: tempFolder)
        try fm.createDirectory(at: tempFolder, withIntermediateDirectories: true)
        for file in downloadedFiles {
            let destination = tempFolder.appendingPathComponent(file.filePathInArchive)
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: file.filePath, to: destination)
        }

        let zipURL = tempFolder.appendingPathExtension("zip")
        try? fm.removeItem(at: zipURL)
        try fm.zipItem(at: tempFolder, to: zipURL)
        try? fm.removeItem(at: outputURL)
        try fm.moveItem(at: zipURL, to: outputURL)
        try? fm.removeItem(at: tempFolder)
    }
}
