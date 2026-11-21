//
//  ExpandedPlayer.swift
//  Salt
//
//  Full-screen Now Playing surface faithfully implementing both Salt mockups:
//  - 16:9 Video & Video Podcast Now Playing (edge-to-edge video, date/title/host,
//    Star + More menu, Turn Video Off/On toggle, -15s / Play-Pause / +30s)
//  - Music Now Playing (1:1 inset rounded artwork, title/artist, Star + Share,
//    Stereo/Lossless badge, Previous / Play-Pause / Next)
//  - Dynamic subtle artwork-colored ambient gradient in Light & Dark Mode
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ExpandedPlayer: View {
    var size: CGSize
    var safeArea: EdgeInsets
    var namespace: Namespace.ID
    @Binding var config: PlayerContainerConfig
    var dismissAction: () -> Void = {}

    @EnvironmentObject var playerManager: MediaPlayerManager
    @EnvironmentObject var appearance: Appearance
    @Environment(\.colorScheme) private var colorScheme

    @State private var fadeIn: Bool = false
    @State private var showVideoOverlayControls: Bool = false
    @State private var overlayHideTask: Task<Void, Never>?
    @State private var showTranscriptSheet: Bool = false
    @State private var showQueueSheet: Bool = false
    @State private var inspectedAsset: OpenSeaAsset?

    var body: some View {
        let appFont = appearance.getAppFont()

        Group {
            if let item = playerManager.currentItem {
                VStack(spacing: 0) {
                    // Top Grabber
                    grabberHandle
                        .padding(.top, max(safeArea.top, 16) + 6)
                        .padding(.bottom, 12)
                        .animation(config.animation.speed(2)) {
                            $0.opacity(config.expandPlayer ? 1 : 0)
                        }
                        .opacity(fadeIn ? 1 : 0)

                    Spacer(minLength: 6)

                    // Hero Media Canvas (16:9 Full-Bleed Video OR 1:1 Inset Rounded Artwork)
                    mediaStage(for: item)

                    Spacer(minLength: 16)

                    // Lower Controls Stack
                    controlsStack(for: item, appFont: appFont)
                        .frame(maxWidth: 460)
                        .animation(config.animation.speed(2)) {
                            $0.opacity(config.expandPlayer ? 1 : 0)
                        }
                        .opacity(fadeIn ? 1 : 0)
                }
                .padding(.bottom, max(safeArea.bottom, 12) + 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    ArtworkAmbientBackground(palette: playerManager.ambientPalette)
                }
                .onAppear {
                    withAnimation(config.animation.delay(0.08)) {
                        fadeIn = true
                    }
                }
                .sheet(isPresented: $showTranscriptSheet) {
                    TranscriptLyricsSheet()
                        .environmentObject(playerManager)
                        .environmentObject(appearance)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $showQueueSheet) {
                    UpNextQueueSheet()
                        .environmentObject(playerManager)
                        .environmentObject(appearance)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
                .sheet(item: $inspectedAsset) { asset in
                    NavigationStack {
                        ObjectDetailView(object: asset, isPresentedInSheet: true)
                            .environmentObject(appearance)
                            .environmentObject(playerManager)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { inspectedAsset = nil }
                                        .font(.system(.body, design: appFont).weight(.semibold))
                                }
                            }
                    }
                    .tint(appearance.getAppColor())
                    .fontDesign(appFont)
                }
                .fullScreenCover(isPresented: $playerManager.showFullscreenVideo) {
                    FullscreenVideoPlayerView(player: playerManager.player)
                        .ignoresSafeArea()
                }
            }
        }
        .fontDesign(appFont)
    }

    // MARK: - Top Grabber

    private var grabberHandle: some View {
        Button {
            OrchardMotion.HapticStyle.light.fire()
            dismissAction()
        } label: {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.34 : 0.20))
                .frame(width: 48, height: 4.5)
                .padding(.vertical, 6)
                .padding(.horizontal, 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Minimize Now Playing")
    }

    // MARK: - Hero Media Stage

    @ViewBuilder
    private func mediaStage(for item: MediaItem) -> some View {
        let shadowColor = Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16)

        if playerManager.isShowingVideoCanvas {
            // 16:9 Full-Bleed Edge-to-Edge Video Canvas (Mockup 1)
            let videoWidth = size.width
            let videoHeight = videoWidth * (9.0 / 16.0)

            ZStack {
                // Poster artwork underneath while stream loads first frame
                PlayerArtworkImage(
                    url: item.artworkURL,
                    cachedImage: playerManager.currentArtworkImage,
                    fallbackSymbol: item.kind.badgeSymbol
                )
                .frame(width: videoWidth, height: videoHeight)
                .clipped()

                VideoPlayerLayerView(
                    player: playerManager.player,
                    videoGravity: .resizeAspect,
                    onAttachPiPController: { controller in
                        playerManager.pipController = controller
                    }
                )
                .frame(width: videoWidth, height: videoHeight)

                if playerManager.isBuffering {
                    ProgressView()
                        .tint(.white)
                        .padding(12)
                        .background(.ultraThinMaterial, in: Circle())
                }

                if let errorText = playerManager.playbackError {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                        Text(errorText)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 24)
                }

                // Subtle auto-hiding overlay controls on tap (PiP + Fullscreen)
                if showVideoOverlayControls {
                    VStack {
                        HStack {
                            Spacer()
                            if playerManager.canStartPiP {
                                Button {
                                    OrchardMotion.HapticStyle.light.fire()
                                    playerManager.togglePictureInPicture()
                                } label: {
                                    Image(systemName: "pip.enter")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 34, height: 34)
                                        .background(.black.opacity(0.45), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                OrchardMotion.HapticStyle.light.fire()
                                playerManager.showFullscreenVideo = true
                            } label: {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(.black.opacity(0.45), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: videoWidth, height: videoHeight)
            .clipped()
            .matchedGeometryEffect(id: "Artwork", in: namespace)
            .shadow(color: shadowColor, radius: 22, x: 0, y: 12)
            .contentShape(Rectangle())
            .onTapGesture {
                toggleVideoOverlay()
            }
        } else {
            // 1:1 Inset Rounded Square Artwork (Mockup 2 & Video-Off Audio Mode)
            let maxSide = min(size.width - 56, max(240, size.height * 0.42))
            let artworkSize = min(maxSide, 360)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay {
                    PlayerArtworkImage(
                        url: item.artworkURL,
                        cachedImage: playerManager.currentArtworkImage,
                        fallbackSymbol: item.kind.badgeSymbol
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.10 : 0.06), lineWidth: 0.75)
                )
                .matchedGeometryEffect(id: "Artwork", in: namespace)
                .frame(width: artworkSize, height: artworkSize)
                .scaleEffect(playerManager.isPlaying ? 1.0 : 0.93)
                .shadow(
                    color: shadowColor,
                    radius: playerManager.isPlaying ? 26 : 14,
                    x: 0,
                    y: playerManager.isPlaying ? 14 : 7
                )
                .animation(.spring(response: 0.42, dampingFraction: 0.78), value: playerManager.isPlaying)
        }
    }

    private func toggleVideoOverlay() {
        overlayHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            showVideoOverlayControls.toggle()
        }
        if showVideoOverlayControls {
            overlayHideTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(3.5))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    showVideoOverlayControls = false
                }
            }
        }
    }

    // MARK: - Lower Controls Stack

    @ViewBuilder
    private func controlsStack(for item: MediaItem, appFont: Font.Design) -> some View {
        VStack(spacing: 18) {
            // 1. Metadata + Favorite / (More or Share)
            metadataRow(for: item, appFont: appFont)
                .padding(.horizontal, 26)

            // 2. Scrubber + Time & Center Mode Pill
            VStack(spacing: 4) {
                CapsuleScrubber(
                    progress: playerManager.progress,
                    onScrubBegan: { playerManager.beginScrubbing(at: $0) },
                    onScrubChanged: { playerManager.updateScrubbing(to: $0) },
                    onScrubEnded: { playerManager.endScrubbing(at: $0) }
                )

                timeAndModeBadgeRow(for: item, appFont: appFont)
            }
            .padding(.horizontal, 26)

            // 3. Primary Transport Controls
            transportControlsRow(for: item)
                .padding(.horizontal, 34)
                .padding(.vertical, 6)

            // 4. Volume Slider
            CapsuleVolumeSlider(volume: $playerManager.volume) { newVolume in
                playerManager.setVolume(newVolume)
            }
            .padding(.horizontal, 26)

            // 5. Bottom Utility Bar (Transcript/Lyrics · AirPlay · Queue)
            bottomUtilityRow(for: item)
                .padding(.horizontal, 40)
                .padding(.top, 2)
        }
        .compositingGroup()
    }

    // MARK: - Metadata Row

    @ViewBuilder
    private func metadataRow(for item: MediaItem, appFont: Font.Design) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                if let asset = item.sourceAsset {
                    OrchardMotion.HapticStyle.selection.fire()
                    inspectedAsset = asset
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if item.kind.showsReleaseDate, let dateText = item.releaseDateText, !dateText.isEmpty {
                        Text(dateText)
                            .font(.system(size: 12.5, weight: .regular, design: appFont).monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(item.title)
                        .font(.system(size: 20, weight: .bold, design: appFont))
                        .foregroundStyle(Color.appPrimary)
                        .lineLimit(1)

                    Text(item.creator)
                        .font(.system(size: 15, weight: .regular, design: appFont))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                let isFav = playerManager.isFavorite(item)
                Button {
                    OrchardMotion.HapticStyle.light.fire()
                    withAnimation(OrchardMotion.snappy) {
                        playerManager.toggleFavorite(for: item)
                    }
                } label: {
                    CircularGlassIconLabel(
                        systemName: isFav ? "star.fill" : "star",
                        isActive: isFav,
                        activeColor: appearance.getAppColor()
                    )
                }
                .buttonStyle(TransportPressButtonStyle())
                .accessibilityLabel(isFav ? "Remove from Favorites" : "Add to Favorites")

                if item.kind.usesPodcastSkipControls {
                    // Mockup 1: More (...) Menu for Videos & Video Podcasts
                    Menu {
                        Menu("Playback Speed (\(formattedRate(playerManager.playbackRate)))") {
                            ForEach(MediaPlayerManager.supportedRates, id: \.self) { rate in
                                Button {
                                    playerManager.setPlaybackRate(rate)
                                } label: {
                                    if abs(playerManager.playbackRate - rate) < 0.01 {
                                        Label(formattedRate(rate), systemImage: "checkmark")
                                    } else {
                                        Text(formattedRate(rate))
                                    }
                                }
                            }
                        }

                        if item.kind.isVideoCapable {
                            Button {
                                playerManager.toggleVideoOutput()
                            } label: {
                                Label(
                                    playerManager.isVideoEnabled ? "Turn Video Off" : "Turn Video On",
                                    systemImage: playerManager.isVideoEnabled ? "tv.slash" : "tv"
                                )
                            }

                            if playerManager.canStartPiP {
                                Button {
                                    playerManager.togglePictureInPicture()
                                } label: {
                                    Label("Picture in Picture", systemImage: "pip.enter")
                                }
                            }

                            Button {
                                playerManager.showFullscreenVideo = true
                            } label: {
                                Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                            }
                        }

                        Divider()

                        if let asset = item.sourceAsset {
                            Button {
                                inspectedAsset = asset
                            } label: {
                                Label("View NFT Details", systemImage: "info.circle")
                            }
                        }

                        if let shareURL = item.permalinkURL ?? Optional(item.streamURL) {
                            ShareLink(item: shareURL) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }

                        Divider()

                        Button(role: .destructive) {
                            dismissAction()
                            playerManager.stopAndDismiss()
                        } label: {
                            Label("Close Player", systemImage: "xmark.circle")
                        }
                    } label: {
                        CircularGlassIconLabel(systemName: "ellipsis")
                    }
                    .accessibilityLabel("More Options")
                } else {
                    // Mockup 2: Direct Share button for Music
                    ShareLink(item: item.permalinkURL ?? item.streamURL) {
                        CircularGlassIconLabel(systemName: "square.and.arrow.up")
                    }
                    .buttonStyle(TransportPressButtonStyle())
                    .contextMenu {
                        if let asset = item.sourceAsset {
                            Button {
                                inspectedAsset = asset
                            } label: {
                                Label("View NFT Details", systemImage: "info.circle")
                            }
                        }

                        Button(role: .destructive) {
                            dismissAction()
                            playerManager.stopAndDismiss()
                        } label: {
                            Label("Close Player", systemImage: "xmark.circle")
                        }
                    }
                    .accessibilityLabel("Share Song")
                }
            }
        }
    }

    // MARK: - Time & Center Mode Pill

    @ViewBuilder
    private func timeAndModeBadgeRow(for item: MediaItem, appFont: Font.Design) -> some View {
        let pillFill = Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)

        ZStack {
            HStack {
                Text(PlayerTimeFormatter.formatElapsed(playerManager.displayedTime))
                    .font(.system(size: 12, weight: .medium, design: appFont).monospacedDigit())
                    .foregroundStyle(Color.appPrimary.opacity(0.72))

                Spacer()

                Text(PlayerTimeFormatter.formatRemaining(
                    playerManager.remainingTime,
                    forceLongFormat: item.kind.usesPodcastSkipControls
                ))
                .font(.system(size: 12, weight: .medium, design: appFont).monospacedDigit())
                .foregroundStyle(Color.appPrimary.opacity(0.72))
            }

            if item.kind.isVideoCapable {
                Button {
                    OrchardMotion.HapticStyle.selection.fire()
                    playerManager.toggleVideoOutput()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: playerManager.isVideoEnabled ? "tv.slash" : "tv")
                            .font(.system(size: 11, weight: .medium))
                        Text(playerManager.isVideoEnabled ? "Turn Video Off" : "Turn Video On")
                            .font(.system(size: 11.5, weight: .medium, design: appFont))
                    }
                    .foregroundStyle(Color.appPrimary.opacity(0.70))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(pillFill, in: Capsule())
                }
                .buttonStyle(TransportPressButtonStyle())
                .accessibilityLabel(playerManager.isVideoEnabled ? "Turn Video Off" : "Turn Video On")
            } else {
                Text(item.audioQualityBadge)
                    .font(.system(size: 11.5, weight: .medium, design: appFont))
                    .foregroundStyle(Color.appPrimary.opacity(0.78))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(pillFill, in: Capsule())
            }
        }
    }

    // MARK: - Transport Controls Row

    @ViewBuilder
    private func transportControlsRow(for item: MediaItem) -> some View {
        HStack {
            Button {
                OrchardMotion.HapticStyle.light.fire()
                if item.kind.usesPodcastSkipControls {
                    playerManager.skipBackward(15)
                } else {
                    playerManager.previousTrack()
                }
            } label: {
                Image(systemName: item.kind.usesPodcastSkipControls ? "gobackward.15" : "backward.fill")
                    .font(.system(size: item.kind.usesPodcastSkipControls ? 31 : 29, weight: .regular))
                    .foregroundStyle(Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TransportPressButtonStyle())
            .accessibilityLabel(item.kind.usesPodcastSkipControls ? "Skip Back 15 Seconds" : "Previous Track")

            Button {
                OrchardMotion.HapticStyle.medium.fire()
                playerManager.togglePlayPause()
            } label: {
                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(Color.appPrimary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TransportPressButtonStyle())
            .accessibilityLabel(playerManager.isPlaying ? "Pause" : "Play")

            Button {
                OrchardMotion.HapticStyle.light.fire()
                if item.kind.usesPodcastSkipControls {
                    playerManager.skipForward(30)
                } else {
                    playerManager.nextTrack()
                }
            } label: {
                Image(systemName: item.kind.usesPodcastSkipControls ? "goforward.30" : "forward.fill")
                    .font(.system(size: item.kind.usesPodcastSkipControls ? 31 : 29, weight: .regular))
                    .foregroundStyle(Color.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TransportPressButtonStyle())
            .accessibilityLabel(item.kind.usesPodcastSkipControls ? "Skip Forward 30 Seconds" : "Next Track")
        }
    }

    // MARK: - Bottom Utility Row

    @ViewBuilder
    private func bottomUtilityRow(for item: MediaItem) -> some View {
        let iconColor = Color.appPrimary.opacity(0.68)
        let uiTint = UIColor.appPrimary.withAlphaComponent(0.68)
        let uiActiveTint = UIColor(appearance.getAppColor())

        HStack {
            Button {
                OrchardMotion.HapticStyle.selection.fire()
                showTranscriptSheet = true
            } label: {
                Image(systemName: "quote.bubble")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(showTranscriptSheet ? appearance.getAppColor() : iconColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TransportPressButtonStyle())
            .accessibilityLabel(item.kind.usesPodcastSkipControls ? "Transcript" : "Lyrics")

            AirPlayRoutePickerView(
                tintColor: uiTint,
                activeTintColor: uiActiveTint,
                prioritizesVideoDevices: item.kind.isVideoCapable
            )
            .frame(width: 34, height: 34)
            .frame(maxWidth: .infinity)
            .accessibilityLabel("AirPlay")

            Button {
                OrchardMotion.HapticStyle.selection.fire()
                showQueueSheet = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(showQueueSheet ? appearance.getAppColor() : iconColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(TransportPressButtonStyle())
            .accessibilityLabel("Up Next Queue")
        }
    }

    private func formattedRate(_ rate: Float) -> String {
        if rate == floor(rate) {
            return "\(Int(rate))x"
        }
        return String(format: "%gx", rate)
    }
}
