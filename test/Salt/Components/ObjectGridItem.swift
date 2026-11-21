//
//  ObjectGridItem.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct ObjectGridItem: View {
    @EnvironmentObject var appearance: Appearance
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var mediaPlayer: MediaPlayerManager
    @State private var showDetailSheet = false
    let object: OpenSeaAsset

    var body: some View {
        if let mediaItem = object.resolvedMediaItem() {
            let isCurrent = mediaPlayer.currentItem?.id == mediaItem.id
            let isActivelyPlaying = isCurrent && mediaPlayer.isPlaying

            // Option B: Tapping a playable media NFT launches directly into the expanded Now Playing view
            Button {
                OrchardMotion.HapticStyle.light.fire()
                mediaPlayer.play(mediaItem, queue: wallet.playableMediaItems, autoExpand: true)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    artworkContent

                    // Subtle bottom scrim + title/media badge so playable NFTs stand out cleanly
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .allowsHitTesting(false)

                    HStack(alignment: .bottom, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(mediaItem.title)
                                .font(.system(size: 12, weight: .semibold, design: appearance.getAppFont()))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(mediaItem.kind.displayLabel)
                                .font(.system(size: 10, weight: .medium, design: appearance.getAppFont()))
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 4)

                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.6)
                                )
                            Image(systemName: isActivelyPlaying ? "waveform" : mediaItem.kind.badgeSymbol)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .symbolEffect(.variableColor.iterative, isActive: isActivelyPlaying)
                        }
                    }
                    .padding(10)
                }
                .aspectRatio(1, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            isCurrent ? appearance.getAppColor().opacity(0.85) : Color.clear,
                            lineWidth: isCurrent ? 2 : 0
                        )
                )
            }
            .buttonStyle(TransportPressButtonStyle())
            .contextMenu {
                Button {
                    mediaPlayer.play(mediaItem, queue: wallet.playableMediaItems, autoExpand: true)
                } label: {
                    Label("Play Now", systemImage: "play.fill")
                }

                Button {
                    mediaPlayer.playNext(mediaItem)
                } label: {
                    Label("Play Next", systemImage: "text.insert")
                }

                Button {
                    mediaPlayer.addToQueue(mediaItem)
                } label: {
                    Label("Add to Queue", systemImage: "text.append")
                }

                Divider()

                Button {
                    showDetailSheet = true
                } label: {
                    Label("View NFT Details", systemImage: "info.circle")
                }
            }
            .sheet(isPresented: $showDetailSheet) {
                NavigationStack {
                    ObjectDetailView(object: object, isPresentedInSheet: true)
                        .environmentObject(appearance)
                        .environmentObject(mediaPlayer)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showDetailSheet = false }
                                    .font(.system(.body, design: appearance.getAppFont()).weight(.semibold))
                            }
                        }
                }
                .tint(appearance.getAppColor())
                .fontDesign(appearance.getAppFont())
                .presentationDragIndicator(.visible)
            }
        } else {
            NavigationLink(destination: ObjectDetailView(object: object)) {
                artworkContent
            }
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if object.isSVG() {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .foregroundStyle(appearance.getAppColor())
                    .aspectRatio(1, contentMode: .fill)

                Text(object.name ?? "Untitled")
                    .font(.system(.caption, design: appearance.getAppFont()))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(.systemBackground))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .lineLimit(3)
            }
        } else {
            ImageView(imageUrl: object.image_url)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .foregroundStyle(Color(.secondarySystemGroupedBackground))
                        .aspectRatio(1, contentMode: .fill)
                )
        }
    }
}

struct ObjectGridItem_Previews: PreviewProvider {
    static var previews: some View {
        ObjectGridItem(object: Wallet.demoObjects()[0])
            .environmentObject(Appearance())
            .environmentObject(Wallet())
            .environmentObject(MediaPlayerManager())
    }
}
