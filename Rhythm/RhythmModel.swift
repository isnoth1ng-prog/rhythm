import AVFoundation
import SwiftUI

@MainActor
final class RhythmModel: ObservableObject {
    @Published var searchText = ""
    @Published var tracks: [BackendTrack] = []
    @Published var savedIDs: Set<String> = []
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var currentTrack: BackendTrack?
    @Published var isPlaying = false
    @Published var playbackTime: Double = 0
    @Published var duration: Double = 0

    let backend = RhythmBackend.shared
    let player = AVPlayer()
    private let savedKey = "rhythm.saved.ids"
    private var timeObserver: Any?

    init() {
        savedIDs = Set(UserDefaults.standard.stringArray(forKey: savedKey) ?? [])
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            self.playbackTime = time.seconds.isFinite ? max(0, time.seconds) : 0
            if let d = self.player.currentItem?.duration.seconds, d.isFinite {
                self.duration = d
            }
        }
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    deinit {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        NotificationCenter.default.removeObserver(self)
    }

    func search() async {
        let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { tracks = []; return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            tracks = try await backend.search(term)
        } catch {
            errorMessage = "Не удалось выполнить поиск: \(error.localizedDescription)"
        }
    }

    func play(_ track: BackendTrack) async {
        do {
            let streamURL = try await backend.resolve(track)
            let item = AVPlayerItem(url: streamURL)
            player.replaceCurrentItem(with: item)
            currentTrack = track
            duration = track.duration ?? 0
            playbackTime = 0
            player.play()
            isPlaying = true
        } catch {
            errorMessage = "Не удалось запустить трек: \(error.localizedDescription)"
        }
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    func seek(to fraction: Double) {
        guard duration > 0 else { return }
        let value = min(max(fraction, 0), 1)
        player.seek(to: CMTime(seconds: duration * value, preferredTimescale: 600))
    }

    func toggleSaved(_ track: BackendTrack) {
        if savedIDs.contains(track.id) {
            savedIDs.remove(track.id)
        } else {
            savedIDs.insert(track.id)
        }
        UserDefaults.standard.set(Array(savedIDs), forKey: savedKey)
    }

    func skip(seconds: Double) {
        let target = max(0, min(duration, playbackTime + seconds))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
    }
}
