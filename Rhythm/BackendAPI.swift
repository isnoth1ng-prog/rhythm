import Foundation

struct BackendTrack: Identifiable, Decodable, Hashable {
    let id: String
    let title: String
    let artist: String
    let version: String?
    let duration: Double?
    let artwork: URL?
    let source: String
    let sourceURL: URL
    let uploader: String?

    enum CodingKeys: String, CodingKey {
        case id, title, artist, version, duration, artwork, source
        case sourceURL = "source_url"
        case uploader
    }

    var subtitle: String {
        if let version, !version.isEmpty { return "(artist) • (version)" }
        return artist
    }
}

@MainActor
final class RhythmBackend: ObservableObject {
    static let shared = RhythmBackend()

    // Public HTTPS backend URL. The repo includes a Render deployment definition.
    var baseURL = URL(string: "https://rhythm-backend.onrender.com")!

    func search(_ query: String, limit: Int = 20) async throws -> [BackendTrack] {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode([BackendTrack].self, from: data)
    }

    func resolve(_ track: BackendTrack) async throws -> URL {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/resolve"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "url", value: track.sourceURL.absoluteString)]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
        struct ResolveResponse: Decodable { let url: URL }
        return try JSONDecoder().decode(ResolveResponse.self, from: data).url
    }
}
