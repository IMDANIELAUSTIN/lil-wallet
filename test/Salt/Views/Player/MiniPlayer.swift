//
//  MiniPlayer.swift
//  Salt
//
//  Compact Liquid Glass mini player rendered inside the TabView bottom accessory,
//  adapted from AMPlayer-2 with matched-geometry artwork and live AVPlayer controls.
//

import SwiftUI

struct MiniPlayer: View {
    var namespace: Namespace.ID
    @EnvironmentObject var playerManager: MediaPlayerManager
    @EnvironmentObject var appearance: Appearance

    var body: some View {
        if let item = playerManager.currentItem {
            HStack(spacing: 11) {
                // Matched-geometry artwork thumbnail (16:9 cropped cleanly into rounded square)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        PlayerArtworkImage(
                            url: item.artworkURL,
                            cachedImage: playerManager.currentArtworkImage,
                            fallbackSymbol: item.kind.badgeSymbol
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .matchedGeometryEffect(id: "Artwork", in: namespace)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(.subheadline, design: appearance.getAppFont()).weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                        .lineLimit(1)

                    Text(item.creator)
                        .font(.system(.caption, design: appearance.getAppFont()))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 14) {
                    Button {
                        OrchardMotion.HapticStyle.light.fire()
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.appPrimary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(TransportPressButtonStyle())

                    Button {
                        OrchardMotion.HapticStyle.light.fire()
                        if item.kind.usesPodcastSkipControls {
                            playerManager.skipForward(30)
                        } else {
                            playerManager.nextTrack()
                        }
                    } label: {
                        Image(systemName: item.kind.usesPodcastSkipControls ? "goforward.30" : "forward.fill")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(TransportPressButtonStyle())
                }
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
        }
    }
}
