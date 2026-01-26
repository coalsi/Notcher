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
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        fetchCurrentTrackInfo()
    }

    @objc private func handleMusicNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }

        let newTitle = userInfo["Name"] as? String
        let newArtist = userInfo["Artist"] as? String
        let newAlbum = userInfo["Album"] as? String
        let playerState = userInfo["Player State"] as? String

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.currentTitle = newTitle
            self.currentArtist = newArtist
            self.currentAlbum = newAlbum
            self.isPlaying = playerState == "Playing"

            if newTitle != self.lastLoadedArtworkTitle, let title = newTitle {
                self.lastLoadedArtworkTitle = title
                Task {
                    await self.loadArtworkForTrack(title: title, artist: newArtist, album: newAlbum)
                }
            }

            if newTitle == nil {
                self.currentArtwork = nil
                self.lastLoadedArtworkTitle = nil
            }
        }
    }

    private func fetchCurrentTrackInfo() {
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                return trackName & "||" & trackArtist & "||" & trackAlbum & "||Playing"
            else if player state is paused then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                return trackName & "||" & trackArtist & "||" & trackAlbum & "||Paused"
            else
                return "||||||Stopped"
            end if
        end tell
        """

        Task {
            if let appleScript = NSAppleScript(source: script) {
                var error: NSDictionary?
                let result = appleScript.executeAndReturnError(&error)

                if error == nil, let output = result.stringValue {
                    let parts = output.components(separatedBy: "||")
                    if parts.count >= 4 {
                        await MainActor.run {
                            let title = parts[0].isEmpty ? nil : parts[0]
                            let artist = parts[1].isEmpty ? nil : parts[1]
                            let album = parts[2].isEmpty ? nil : parts[2]
                            let state = parts[3]

                            self.currentTitle = title
                            self.currentArtist = artist
                            self.currentAlbum = album
                            self.isPlaying = state == "Playing"

                            if let title = title, title != self.lastLoadedArtworkTitle {
                                self.lastLoadedArtworkTitle = title
                                Task {
                                    await self.loadArtworkForTrack(title: title, artist: artist, album: album)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func loadArtworkForTrack(title: String, artist: String?, album: String?) async {
        if let image = await loadArtworkViaAppleScript() {
            await MainActor.run { self.currentArtwork = image }
            return
        }

        if let image = await loadArtworkViaiTunesSearch(title: title, artist: artist, album: album) {
            await MainActor.run { self.currentArtwork = image }
            return
        }

        await MainActor.run { self.currentArtwork = nil }
    }

    private func loadArtworkViaAppleScript() async -> NSImage? {
        let tempPath = NSTemporaryDirectory() + "NotcherMusicArtwork.png"

        let script = """
        tell application "Music"
            try
                set artworkCount to count of artworks of current track
                if artworkCount > 0 then
                    set theArtwork to artwork 1 of current track
                    set artworkData to raw data of theArtwork
                    set theFile to open for access POSIX file "\(tempPath)" with write permission
                    set eof theFile to 0
                    write artworkData to theFile
                    close access theFile
                    return "success"
                else
                    return "no artwork"
                end if
            on error errMsg
                try
                    close access POSIX file "\(tempPath)"
                end try
                return "error: " & errMsg
            end try
        end tell
        """

        guard let appleScript = NSAppleScript(source: script) else { return nil }

        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)

        if error != nil { return nil }

        if result.stringValue == "success" {
            if let image = NSImage(contentsOfFile: tempPath) {
                try? FileManager.default.removeItem(atPath: tempPath)
                return image
            }
        }

        return nil
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
        DistributedNotificationCenter.default().removeObserver(self)
    }

    deinit {
        stopObserving()
    }
}
