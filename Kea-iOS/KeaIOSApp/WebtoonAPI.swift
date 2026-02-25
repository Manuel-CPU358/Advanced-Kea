import Foundation

final class WebtoonAPI {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = [
            "User-Agent": KeaHelpers.spoofedUserAgent,
            "Cookie": "pagGDPR=true;"
        ]
        session = URLSession(configuration: config)
    }

    func fetchEpisodes(for info: ToonListEntryInfo) async throws -> ToonListEntry {
        var episodeList: [EpisodeListEntry] = []
        var page = 1

        while true {
            var comp = URLComponents(url: info.url, resolvingAgainstBaseURL: false)!
            var queryItems = comp.queryItems ?? []
            queryItems.removeAll(where: { $0.name == "page" })
            queryItems.append(URLQueryItem(name: "page", value: String(page)))
            comp.queryItems = queryItems

            guard let pageURL = comp.url else { break }
            let html = try await getText(url: pageURL)
            let pageEpisodes = parseEpisodeList(html: html)
            if pageEpisodes.isEmpty { break }

            let filtered = pageEpisodes.filter {
                $0.episodeNo >= info.startDownloadAtEpisode &&
                (info.stopDownloadAtEpisode == nil || $0.episodeNo <= info.stopDownloadAtEpisode!)
            }
            episodeList.append(contentsOf: filtered)

            if !html.contains("paginate") || !html.contains("href=\"#\"") {
                break
            }
            page += 1
        }

        return ToonListEntry(toonInfo: info, episodeList: episodeList.reversed())
    }

    func fetchOfficialImageURLs(episodeURL: URL) async throws -> [URL] {
        let html = try await getText(url: episodeURL)
        return html.captureGroups(pattern: "data-url=\\\"([^\\\"]+)\\\"")
            .compactMap { $0.first }
            .compactMap(URL.init(string:))
    }

    func fetchFanTranslation(episodeNo: Int, titleNo: Int, languageCode: String, teamVersion: String) async throws -> (name: String, team: String, imageURLs: [URL])? {
        let base = "https://global.apis.naver.com/lineWebtoon/ctrans"
        let infoURL = URL(string: "\(base)/translatedEpisodeLanguageInfo_jsonp.json?titleNo=\(titleNo)&episodeNo=\(episodeNo)")!
        let languageJSON = try await getJSON(url: infoURL)

        guard let result = languageJSON["result"] as? [String: Any],
              let languageList = result["languageList"] as? [[String: Any]] else {
            return nil
        }

        let matching = languageList
            .filter {
                (($0["languageCode"] as? String) == languageCode) &&
                (teamVersion == "default" || "\($0["teamVersion"] ?? "")" == teamVersion)
            }
            .sorted { (($0["likeItCount"] as? Int) ?? 0) > (($1["likeItCount"] as? Int) ?? 0) }

        guard let selected = matching.first,
              let selectedTeamVersion = selected["teamVersion"],
              let languageName = selected["languageName"] as? String else {
            return nil
        }

        let detailURL = URL(string: "\(base)/translatedEpisodeDetail_jsonp.json?titleNo=\(titleNo)&episodeNo=\(episodeNo)&languageCode=\(languageCode)&teamVersion=\(selectedTeamVersion)")!
        let detailJSON = try await getJSON(url: detailURL)
        guard let detailResult = detailJSON["result"] as? [String: Any],
              let imageInfo = detailResult["imageInfo"] as? [[String: Any]] else {
            return nil
        }

        let urls = imageInfo
            .sorted { (($0["sortOrder"] as? Int) ?? 0) < (($1["sortOrder"] as? Int) ?? 0) }
            .compactMap { ($0["imageUrl"] as? String).flatMap(URL.init(string:)) }

        return (languageName, selected["teamName"] as? String ?? "", urls)
    }

    func downloadBinary(url: URL, referer: URL?) async throws -> Data {
        var request = URLRequest(url: url)
        if let referer {
            request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private func getText(url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func getJSON(url: URL) async throws -> [String: Any] {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func parseEpisodeList(html: String) -> [EpisodeListEntry] {
        let pattern = #"<li class="_episodeItem"[^>]*data-episode-no="(\d+)"[\s\S]*?<a href="([^"]+)"[\s\S]*?<span class="subj"><span>([^<]+)</span>[\s\S]*?<span class="tx">([^<]+)</span>"#

        return html.captureGroups(pattern: pattern).compactMap { groups in
            guard groups.count == 4,
                  let episodeNo = Int(groups[0]),
                  let url = URL(string: groups[1]) else { return nil }
            return EpisodeListEntry(
                episodeSequence: groups[3],
                episodeNo: episodeNo,
                episodeTitle: groups[2],
                url: url
            )
        }
    }
}

private extension String {
    func captureGroups(pattern: String) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))

        return results.map { result in
            (1..<result.numberOfRanges).compactMap { index in
                let range = result.range(at: index)
                guard let swiftRange = Range(range, in: self) else { return nil }
                return String(self[swiftRange])
            }
        }
    }
}
