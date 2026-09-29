import Foundation

struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let start: TimeInterval
    let text: String
}

struct LyricsResult {
    let lines: [LyricLine]
    let synced: Bool
}

enum LyricsService {
    static func fetch(title: String, artist: String, duration: TimeInterval?) async -> LyricsResult {
        var components = URLComponents(string: "https://lrclib.net/api/get")
        components?.queryItems = [
            URLQueryItem(name: "track_name", value: title),
            URLQueryItem(name: "artist_name", value: artist)
        ]
        guard let url = components?.url else { return LyricsResult(lines: [], synced: false) }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return LyricsResult(lines: [], synced: false)
            }
            let payload = try JSONDecoder().decode(LRCLIBResponse.self, from: data)

            if let synced = payload.syncedLyrics {
                return LyricsResult(lines: parseLRC(synced), synced: true)
            }
            if let plain = payload.plainLyrics {
                return LyricsResult(lines: plain.components(separatedBy: .newlines).filter { !$0.isEmpty }.map {
                    LyricLine(start: 0, text: $0)
                }, synced: false)
            }
        } catch { }
        return LyricsResult(lines: [], synced: false)
    }

    private static func parseLRC(_ text: String) -> [LyricLine] {
        text.components(separatedBy: .newlines).compactMap { raw in
            let pattern = #"\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let ns = raw as NSString
            guard let match = regex.firstMatch(in: raw, range: NSRange(location: 0, length: ns.length)),
                  match.numberOfRanges == 4,
                  let minutes = Double(ns.substring(with: match.range(at: 1))),
                  let seconds = Double(ns.substring(with: match.range(at: 2))) else { return nil }
            let lyric = ns.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
            guard !lyric.isEmpty else { return nil }
            return LyricLine(start: minutes * 60 + seconds, text: lyric)
        }
    }

    private struct LRCLIBResponse: Decodable {
        let plainLyrics: String?
        let syncedLyrics: String?
    }
}
