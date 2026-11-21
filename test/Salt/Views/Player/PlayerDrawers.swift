//
//  PlayerDrawers.swift
//  Salt
//
//  Bottom utility drawers for Now Playing:
//  - TranscriptLyricsSheet (quote.bubble): Transcript/show notes or song lyrics + chapter jumps
//  - UpNextQueueSheet (list.bullet): Chapters & reorderable Up Next media NFT queue
//

import SwiftUI

// MARK: - Transcript / Lyrics Sheet

struct TranscriptLyricsSheet: View {
    @EnvironmentObject var playerManager: MediaPlayerManager
    @EnvironmentObject var appearance: Appearance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let appFont = appearance.getAppFont()

        NavigationStack {
            ScrollView {
                if let item = playerManager.currentItem {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header Card
                        HStack(spacing: 12) {
                            PlayerArtworkImage(
                                url: item.artworkURL,
                                cachedImage: playerManager.currentArtworkImage,
                                fallbackSymbol: item.kind.badgeSymbol
                            )
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(.headline, design: appFont))
                                    .foregroundStyle(Color.appPrimary)
                                    .lineLimit(2)

                                Text(item.creator)
                                    .font(.system(.subheadline, design: appFont))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }

                        // Chapters quick-jump bar (if available)
                        if !item.chapters.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Chapters")
                                    .font(.system(.caption, design: appFont).weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(item.chapters) { chapter in
                                            Button {
                                                OrchardMotion.HapticStyle.selection.fire()
                                                playerManager.seek(to: chapter.startTime)
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Text(PlayerTimeFormatter.formatElapsed(chapter.startTime))
                                                        .font(.system(.caption2, design: appFont).monospacedDigit())
                                                        .foregroundStyle(.secondary)
                                                    Text(chapter.title)
                                                        .font(.system(.caption, design: appFont).weight(.medium))
                                                        .foregroundStyle(Color.appPrimary)
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        // Transcript or Lyrics Body
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.kind.usesPodcastSkipControls ? "Transcript & Show Notes" : "Lyrics & Liner Notes")
                                .font(.system(.caption, design: appFont).weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            if let text = item.lyricsOrTranscript, !text.isEmpty {
                                Text(text)
                                    .font(.system(.body, design: appFont))
                                    .foregroundStyle(Color.appPrimary)
                                    .lineSpacing(6)
                            } else if let description = item.sourceAsset?.description, !description.isEmpty {
                                Text(description)
                                    .font(.system(.body, design: appFont))
                                    .foregroundStyle(Color.appPrimary)
                                    .lineSpacing(6)
                            } else {
                                Text(item.kind.usesPodcastSkipControls
                                     ? "No transcript is attached to this NFT metadata."
                                     : "No lyrics are attached to this NFT metadata.")
                                    .font(.system(.body, design: appFont))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(playerManager.currentItem?.kind.usesPodcastSkipControls == true ? "Transcript" : "Lyrics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: appFont).weight(.semibold))
                }
            }
        }
        .fontDesign(appFont)
    }
}

// MARK: - Chapters & Up Next Queue Sheet

struct UpNextQueueSheet: View {
    @EnvironmentObject var playerManager: MediaPlayerManager
    @EnvironmentObject var appearance: Appearance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let appFont = appearance.getAppFont()

        NavigationStack {
            List {
                if let current = playerManager.currentItem {
                    // Active Item Section
                    Section("Now Playing") {
                        HStack(spacing: 12) {
                            PlayerArtworkImage(
                                url: current.artworkURL,
                                cachedImage: playerManager.currentArtworkImage,
                                fallbackSymbol: current.kind.badgeSymbol
                            )
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(current.title)
                                    .font(.system(.body, design: appFont).weight(.semibold))
                                    .foregroundStyle(Color.appPrimary)
                                    .lineLimit(1)
                                Text("\(current.creator) · \(current.kind.displayLabel)")
                                    .font(.system(.caption, design: appFont))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 0)

                            Image(systemName: playerManager.isPlaying ? "waveform" : "pause.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(appearance.getAppColor())
                                .symbolEffect(.variableColor.iterative, isActive: playerManager.isPlaying)
                        }
                    }

                    // Chapters Section (for video podcasts / videos with chapters)
                    if !current.chapters.isEmpty {
                        Section("Chapters") {
                            ForEach(current.chapters) { chapter in
                                Button {
                                    OrchardMotion.HapticStyle.selection.fire()
                                    playerManager.seek(to: chapter.startTime)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(chapter.title)
                                            .font(.system(.body, design: appFont))
                                            .foregroundStyle(Color.appPrimary)
                                        Spacer()
                                        Text(PlayerTimeFormatter.formatElapsed(chapter.startTime))
                                            .font(.system(.caption, design: appFont).monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                // Queue Section
                Section("Playing Next") {
                    ForEach(Array(playerManager.queue.enumerated()), id: \.element.id) { index, item in
                        Button {
                            OrchardMotion.HapticStyle.selection.fire()
                            playerManager.jumpToQueueIndex(index)
                        } label: {
                            HStack(spacing: 12) {
                                PlayerArtworkImage(
                                    url: item.artworkURL,
                                    cachedImage: ArtworkPaletteExtractor.shared.cachedImage(for: item.artworkURL),
                                    fallbackSymbol: item.kind.badgeSymbol
                                )
                                .frame(width: 42, height: 42)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(.subheadline, design: appFont).weight(index == playerManager.currentIndex ? .semibold : .regular))
                                        .foregroundStyle(Color.appPrimary)
                                        .lineLimit(1)
                                    Text("\(item.creator) · \(item.kind.displayLabel)")
                                        .font(.system(.caption, design: appFont))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer(minLength: 0)

                                if index == playerManager.currentIndex {
                                    Image(systemName: "checkmark")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(appearance.getAppColor())
                                }
                            }
                        }
                    }
                    .onMove { source, destination in
                        playerManager.moveQueueItems(from: source, to: destination)
                    }
                    .onDelete { offsets in
                        playerManager.removeQueueItems(at: offsets)
                    }
                }
            }
            .navigationTitle("Up Next")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: appFont).weight(.semibold))
                }
            }
        }
        .fontDesign(appFont)
    }
}
