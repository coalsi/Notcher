//
//  MusicNowPlayingManager.swift
//  Notcher
//
//  Manages Apple Music now playing information
//

import MusicKit
import AppKit
import Combine

final class MusicNowPlayingManager: ObservableObject {
    @Published private(set) var isAuthorized = false
    @Published private(set) var authorizationError: String?
    @Published private(set) var currentTitle: String?
    @Published private(set) var currentArtist: String?
    @Published private(set) var currentAlbum: String?
    @Published private(set) var currentArtwork: NSImage?
    @Published private(set) var isPlaying = false

    private var lastLoadedArtworkTitle: String?
    private var cancellables = Set<AnyCancellable>()
    private var artworkTask: Task<Void, Never>?

    var hasNowPlaying: Bool { currentTitle != nil }

    func requestAuthorization() async {
        let status = await MusicAuthorization.request()
        switch status {
        case .authorized:
            isAuthorized = true
            authorizationError = nil
            startObserving()
        case .denied:
            authorizationError = "Music access denied"
        case .restricted:
            authorizationError = "Music access restricted"
        case .notDetermined:
            authorizationError = "Music access not determined"
        @unknown default:
            authorizationError = "Unknown authorization status"
        }
    }

    private func startObserving() {
        DistributedNotificationCenter.default()
            .publisher(for: NSNotification.Name("com.apple.Music.playerInfo"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleMusicNotification(notification)
            }
            .store(in: &cancellables)
    }

    private func handleMusicNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let newTitle = userInfo["Name"] as? String
        let newArtist = userInfo["Artist"] as? String
        let newAlbum = userInfo["Album"] as? String
        let playerState = userInfo["Player State"] as? String

        currentTitle = newTitle
        currentArtist = newArtist
        currentAlbum = newAlbum
        isPlaying = playerState == "Playing"

        if newTitle != lastLoadedArtworkTitle, let title = newTitle {
            lastLoadedArtworkTitle = title
            artworkTask?.cancel()
            artworkTask = Task {
                await loadArtworkForTrack(title: title, artist: newArtist, album: newAlbum)
            }
        }

        if newTitle == nil {
            currentArtwork = nil
            lastLoadedArtworkTitle = nil
        }
    }

    private func loadArtworkForTrack(title: String, artist: String?, album: String?) async {
        // Try MusicKit catalog search first
        if let image = await loadArtworkViaMusicKit(title: title, artist: artist) {
            await MainActor.run { self.currentArtwork = image }
            return
        }

        // Fall back to iTunes Search API
        if let image = await loadArtworkViaiTunesSearch(title: title, artist: artist, album: album) {
            await MainActor.run { self.currentArtwork = image }
            return
        }

        await MainActor.run { self.currentArtwork = nil }
    }

    private func loadArtworkViaMusicKit(title: String, artist: String?) async -> NSImage? {
        var request = MusicCatalogSearchRequest(term: artist != nil ? "\(title) \(artist!)" : title, types: [Song.self])
        request.limit = 5

        do {
            let response = try await request.response()
            // Find best match
            let match = response.songs.first { song in
                song.title.lowercased() == title.lowercased()
            } ?? response.songs.first

            guard let song = match, let artwork = song.artwork else { return nil }

            let url = artwork.url(width: 600, height: 600)
            guard let url = url else { return nil }

            let (data, _) = try await URLSession.shared.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    private func loadArtworkViaiTunesSearch(title: String, artist: String?, album: String?) async -> NSImage? {
        var searchTerm = title
        if let artist = artist {
            searchTerm += " \(artist)"
        }

        guard let encoded = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&media=music&entity=song&limit=5") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  !results.isEmpty else {
                return nil
            }

            let matchingResult = results.first { result in
                guard let trackName = result["trackName"] as? String else { return false }
                return trackName.lowercased() == title.lowercased()
            } ?? results.first

            guard let result = matchingResult,
                  let artworkUrlString = result["artworkUrl100"] as? String else {
                return nil
            }

            let highResUrl = artworkUrlString.replacingOccurrences(of: "100x100", with: "600x600")

            guard let artworkURL = URL(string: highResUrl) else { return nil }

            let (imageData, _) = try await URLSession.shared.data(from: artworkURL)
            return NSImage(data: imageData)
        } catch {
            return nil
        }
    }

    func stopObserving() {
        cancellables.removeAll()
        artworkTask?.cancel()
        artworkTask = nil
    }

    deinit {
        artworkTask?.cancel()
    }
}
