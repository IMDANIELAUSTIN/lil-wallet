//
//  MiniPlayer.swift
//  Salt
//
//  Compact Liquid Glass mini player rendered inside the TabView bottom accessory,
//  adapted from AMPlayer-2 with matched-geometry artwork, adaptive inline/expanded
//  accessory layout, and live AVPlayer controls.
//

import SwiftUI

struct MiniPlayer: View {
    var namespace: Namespace.ID? = nil
    var forcedInlineCompact: Bool? = nil

    @EnvironmentObject var playerManager: MediaPlayerManager
    @EnvironmentObject var appearance: Appearance
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement

    private var isInlineCompact: Bool {
        forcedInlineCompact ?? (accessoryPlacement == .inline)
    }

    var body: some View {
        if let item = playerManager.currentItem {
            HStack(spacing: isInlineCompact ? 8 : 11) {
                // Artwork thumbnail (matchedGeometryEffect active only inside the morphing overlay)
                let thumbSize: CGFloat = isInlineCompact ? 28 : 34
                let cornerRadius: CGFloat = isInlineCompact ? 6 : 7
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        PlayerArtworkImage(
                            url: item.artworkURL,
                            cachedImage: playerManager.currentArtworkImage,
                            fallbackSymbol: item.kind.badgeSymbol
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .modifier(OptionalArtworkGeometry(id: "Artwork", namespace: namespace))
                    .frame(width: thumbSize, height: thumbSize)
                    .fixedSize()

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.title)
                        .font(.system(isInlineCompact ? .footnote : .subheadline, design: appearance.getAppFont()).weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !isInlineCompact {
                        Text(item.creator)
                            .font(.system(.caption, design: appearance.getAppFont()))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .transition(.opacity)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

                HStack(spacing: isInlineCompact ? 4 : 10) {
                    Button {
                        OrchardMotion.HapticStyle.light.fire()
                        playerManager.togglePlayPause()
                    } label: {
                        Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: isInlineCompact ? 16 : 18, weight: .semibold))
                            .foregroundStyle(Color.appPrimary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 28, height: 28)
                            .contentShape(.rect)
                    }
                    .buttonStyle(TransportPressButtonStyle())

                    if !isInlineCompact {
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
                                .frame(width: 28, height: 28)
                                .contentShape(.rect)
                        }
                        .buttonStyle(TransportPressButtonStyle())
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .fixedSize()
            }
            .padding(.leading, isInlineCompact ? 10 : 14)
            .padding(.trailing, isInlineCompact ? 8 : 12)
            .animation(.snappy(duration: 0.24), value: isInlineCompact)
        }
    }
}

private struct OptionalArtworkGeometry: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedGeometryEffect(id: id, in: namespace)
        } else {
            content
        }
    }
}
