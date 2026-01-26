//
//  MusicNotchView.swift
//  Notcher
//
//  Content view for MusicNotch module
//

import SwiftUI
import AppKit

struct MusicNotchView: View {
    @ObservedObject var manager: MusicNowPlayingManager
    @ObservedObject var settings: MusicNotchSettings

    private var artworkID: String {
        if let artwork = manager.currentArtwork {
            return "\(manager.currentTitle ?? "")_\(artwork.hashValue)"
        }
        return "placeholder"
    }

    private var artworkCornerRadius: CGFloat {
        switch settings.sizePreset {
        case .small: return 4
        case .medium: return 6
        case .large: return 8
        case .extraLarge: return 10
        }
    }

    private var placeholderIconSize: CGFloat {
        settings.sizePreset.artworkSize * 0.44
    }

    var body: some View {
        HStack(spacing: 8) {
            // Album art
            Group {
                if let artwork = manager.currentArtwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: settings.sizePreset.artworkSize, height: settings.sizePreset.artworkSize)
                        .clipShape(RoundedRectangle(cornerRadius: artworkCornerRadius))
                } else {
                    RoundedRectangle(cornerRadius: artworkCornerRadius)
                        .fill(.white.opacity(0.2))
                        .frame(width: settings.sizePreset.artworkSize, height: settings.sizePreset.artworkSize)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: placeholderIconSize))
                                .foregroundColor(.white.opacity(0.5))
                        }
                }
            }
            .id(artworkID)
            .transition(.opacity)

            // Track info
            Group {
                if let title = manager.currentTitle {
                    VStack(alignment: settings.textAlignment.horizontalAlignment, spacing: 2) {
                        Text(title)
                            .font(.system(size: settings.sizePreset.titleFontSize, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: settings.textAlignment.alignment)

                        if let artist = manager.currentArtist {
                            Text(artist)
                                .font(.system(size: settings.sizePreset.artistFontSize, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: settings.textAlignment.alignment)
                        }
                    }
                } else {
                    Text("Not Playing")
                        .font(.system(size: settings.sizePreset.artistFontSize + 1, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: settings.textAlignment.alignment)
                }
            }
            .id(manager.currentTitle ?? "not_playing")
            .transition(.opacity)

            if settings.textAlignment == .leading {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, settings.sizePreset.horizontalPadding)
        .padding(.top, 0)
        .padding(.bottom, settings.sizePreset.bottomPadding)
        .opacity(manager.isPlaying ? 1.0 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: manager.currentTitle)
        .animation(.easeInOut(duration: 0.3), value: artworkID)
        .animation(.easeInOut(duration: 0.2), value: manager.isPlaying)
    }
}
