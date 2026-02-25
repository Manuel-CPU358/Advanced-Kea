import Foundation
import UIKit

enum KeaHelpers {
    static let maxSingleImageHeight: CGFloat = 30_000
    static let spoofedUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/109.0"

    static func getFileExtension(from url: URL) -> String {
        let ext = url.pathExtension
        return ext.isEmpty ? "jpg" : ext
    }

    static func sanitizeFileName(_ text: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return text.components(separatedBy: invalid).joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func removeQueryItem(named key: String, from url: URL) -> URL {
        guard var comp = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        comp.queryItems = comp.queryItems?.filter { $0.name != key }
        return comp.url ?? url
    }

    static func isValidWebtoonListURL(_ string: String) -> Bool {
        guard let url = URL(string: string),
              let host = url.host,
              host.contains("webtoons.com"),
              url.path.contains("/list") else {
            return false
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "title_no" }) ?? false
    }

    static func drawNotFoundImage(imageNumber: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
            UIColor.systemRed.setFill()
            UIBezierPath(roundedRect: CGRect(x: 5, y: 5, width: 390, height: 190), cornerRadius: 25).fill()
            let text = "Image \(String(format: "%05d", imageNumber)) not found!"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 30),
                .foregroundColor: UIColor.white
            ]
            text.draw(in: CGRect(x: 10, y: 70, width: 380, height: 80), withAttributes: attributes)
        }
    }

    static func drawUnofficialWarning(languageName: String, teamName: String?) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200))
        return renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 200))

            UIColor.systemGreen.setStroke()
            let badge = UIBezierPath(roundedRect: CGRect(x: 50, y: 10, width: 300, height: 40), cornerRadius: 20)
            badge.lineWidth = 5
            badge.stroke()

            let header: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 30),
                .foregroundColor: UIColor.systemGreen
            ]
            "Unofficial".draw(in: CGRect(x: 95, y: 12, width: 220, height: 35), withAttributes: header)

            let teamText = (teamName?.isEmpty == false) ? " - \(teamName!)" : ""
            let body = "This is translated in \(languageName) by WEBTOON fans\(teamText)"
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 20),
                .foregroundColor: UIColor.white
            ]
            body.draw(in: CGRect(x: 12, y: 65, width: 375, height: 120), withAttributes: bodyAttributes)
        }
    }
}
