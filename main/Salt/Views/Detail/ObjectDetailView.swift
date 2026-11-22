//
//  ObjectDetailView.swift
//  Salt
//
//  Redesigned to match Salt's Transaction Details (ActivityDetailView) native
//  inset-grouped card architecture, centered frameless hero header, and
//  high-contrast PrimaryCapsuleButtonStyle CTA buttons.
//

import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#endif

struct ObjectDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance
    @EnvironmentObject var mediaPlayer: MediaPlayerManager
    let object: OpenSeaAsset
    var isPresentedInSheet: Bool = false

    @State private var didCopyTokenID = false
    @State private var didAddToQueue = false

    private func formatContractAddress(_ address: String) -> String {
        guard address.count > 10 else { return address }
        return "\(address.prefix(6))...\(address.suffix(4))"
    }

    private func creatorFieldLabel(for mediaItem: MediaItem?) -> String {
        guard let mediaItem else { return "Creator" }
        switch mediaItem.kind {
        case .videoPodcast, .audioPodcast: return "Host"
        case .video: return "Director"
        case .song: return "Artist"
        }
    }

    var body: some View {
        let appFont = appearance.getAppFont()
        let mediaItem = object.resolvedMediaItem()
        let isAlreadyInPlayer = mediaItem != nil && mediaPlayer.currentItem?.id == mediaItem?.id

        List {
            // MARK: - Frameless Centered Hero Section (matches ActivityDetailView header)
            Section {
                VStack(spacing: 14) {
                    heroArtwork(for: mediaItem)

                    VStack(spacing: 4) {
                        Text(object.name ?? "Untitled")
                            .font(.system(size: 26, weight: .bold, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                            .multilineTextAlignment(.center)

                        if let creator = mediaItem?.creator ?? object.collection_name, !creator.isEmpty {
                            Text(creator)
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        if let subtitleMeta = heroSecondarySubtitle(for: mediaItem) {
                            Text(subtitleMeta)
                                .font(.system(.subheadline, design: appFont))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 8)

                    if let mediaItem {
                        HStack(spacing: 10) {
                            Button {
                                OrchardMotion.HapticStyle.medium.fire()
                                if isPresentedInSheet && isAlreadyInPlayer {
                                    dismiss()
                                } else {
                                    if isPresentedInSheet {
                                        dismiss()
                                    }
                                    mediaPlayer.play(mediaItem, autoExpand: true)
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: (isPresentedInSheet && isAlreadyInPlayer)
                                          ? "arrow.uturn.backward"
                                          : "play.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text((isPresentedInSheet && isAlreadyInPlayer)
                                         ? "Return to Player"
                                         : (mediaItem.kind.isVideoCapable ? "Watch Now" : "Play Now"))
                                        .font(.system(.headline, design: appFont).weight(.semibold))
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())

                            Button {
                                OrchardMotion.HapticStyle.light.fire()
                                mediaPlayer.addToQueue(mediaItem)
                                withAnimation(OrchardMotion.snappy) {
                                    didAddToQueue = true
                                }
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(1.5))
                                    withAnimation(OrchardMotion.snappy) {
                                        didAddToQueue = false
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: didAddToQueue ? "checkmark" : "text.append")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(didAddToQueue ? "Queued" : "Queue")
                                        .font(.system(.subheadline, design: appFont).weight(.semibold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(Color.appPrimary)
                                .padding(.horizontal, 18)
                                .frame(height: 50)
                                .background(
                                    Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.07),
                                    in: Capsule()
                                )
                                .overlay(
                                    Capsule()
                                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.6)
                                )
                            }
                            .buttonStyle(TransportPressButtonStyle())
                            .fixedSize()
                            .layoutPriority(1)
                        }
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            // MARK: - Details Card (mirrors ActivityDetailView Details section)
            Section {
                if let creator = mediaItem?.creator ?? object.creator_name, !creator.isEmpty {
                    detailRow(title: creatorFieldLabel(for: mediaItem), value: creator, appFont: appFont)
                }

                detailRow(
                    title: "Media Type",
                    value: mediaItem?.kind.displayLabel ?? (object.isSVG() ? "Vector Graphic" : "Digital Object"),
                    appFont: appFont
                )

                if let mediaItem, !mediaItem.audioQualityBadge.isEmpty {
                    detailRow(title: "Audio", value: mediaItem.audioQualityBadge, appFont: appFont)
                } else if object.isSVG() {
                    detailRow(title: "Format", value: "SVG", appFont: appFont)
                }

                if let releaseDate = mediaItem?.releaseDateText ?? object.release_date, !releaseDate.isEmpty {
                    detailRow(title: "Released", value: releaseDate, appFont: appFont, monospacedValue: true)
                }
            } header: {
                Text("Details")
                    .textCase(nil)
            }

            // MARK: - About Card
            if let description = object.description, !description.isEmpty {
                Section {
                    Text(description)
                        .font(.system(.body, design: appFont))
                        .foregroundStyle(Color.appPrimary)
                        .lineSpacing(3)
                        .padding(.vertical, 2)
                } header: {
                    Text("About")
                        .textCase(nil)
                }
            }

            // MARK: - Properties Card
            if !object.traits.isEmpty {
                Section {
                    ForEach(object.traits) { trait in
                        HStack {
                            Text(trait.trait_type)
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(Color.appPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(trait.value)
                                .font(.system(.headline, design: appFont))
                                .foregroundStyle(Color.appPrimary)
                                .lineLimit(1)
                        }
                    }
                } header: {
                    Text("Properties")
                        .textCase(nil)
                }
            }

            // MARK: - Chapters Card (Playable Media with Chapters)
            if let mediaItem, !mediaItem.chapters.isEmpty {
                Section {
                    ForEach(mediaItem.chapters) { chapter in
                        Button {
                            OrchardMotion.HapticStyle.selection.fire()
                            if mediaPlayer.currentItem?.id != mediaItem.id {
                                mediaPlayer.play(mediaItem, autoExpand: true)
                            }
                            mediaPlayer.seek(to: chapter.startTime)
                            if isPresentedInSheet {
                                dismiss()
                            }
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.system(.body, design: appFont))
                                    .foregroundStyle(Color.appPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text(PlayerTimeFormatter.formatElapsed(chapter.startTime))
                                    .font(.system(.body, design: appFont).monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Chapters")
                        .textCase(nil)
                }
            }

            // MARK: - Token / On-Chain Card (mirrors ActivityDetailView Token section)
            Section {
                if let collection = object.collection_name, !collection.isEmpty {
                    HStack {
                        Text("Collection")
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                        Spacer()
                        Text(collection)
                            .font(.system(.headline, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                            .lineLimit(1)
                    }
                }

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = "\(object.id)"
                    #endif
                    OrchardMotion.HapticStyle.selection.fire()
                    withAnimation(OrchardMotion.snappy) {
                        didCopyTokenID = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(1.5))
                        withAnimation(OrchardMotion.snappy) {
                            didCopyTokenID = false
                        }
                    }
                } label: {
                    HStack {
                        Text("Token ID")
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                        Spacer()
                        HStack(spacing: 6) {
                            if didCopyTokenID {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                            Text(didCopyTokenID ? "Copied" : "#\(object.id)")
                                .font(.system(.headline, design: appFont).monospacedDigit())
                                .foregroundStyle(didCopyTokenID ? .green : Color.appPrimary)
                        }
                    }
                }
                .buttonStyle(.plain)

                if let standard = object.token_standard, !standard.isEmpty {
                    HStack {
                        Text("Standard")
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                        Spacer()
                        Text(standard)
                            .font(.system(.headline, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                    }
                }

                if let network = object.network, !network.isEmpty {
                    HStack {
                        Text("Network")
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                        Spacer()
                        Text(network)
                            .font(.system(.headline, design: appFont))
                            .foregroundStyle(Color.appPrimary)
                    }
                }

                if let contract = object.contract_address,
                   !contract.isEmpty,
                   let etherscanURL = URL(string: "https://etherscan.io/address/\(contract)") {
                    Link(destination: etherscanURL) {
                        HStack {
                            Text("Contract")
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(Color.appPrimary)
                            Spacer()
                            Text(formatContractAddress(contract))
                                .font(.system(.body, design: appFont).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Token")
                    .textCase(nil)
            }

            // MARK: - Bottom External Links Card (mirrors ActivityDetailView View on Etherscan)
            if let permalinkURL = URL(string: object.permalink) {
                Section {
                    Link(destination: permalinkURL) {
                        HStack {
                            Text("View on OpenSea")
                                .font(.system(.body, design: appFont))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(appearance.getAppColor())

                    ShareLink(item: permalinkURL) {
                        HStack {
                            Text("Share NFT")
                                .font(.system(.body, design: appFont))
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(appearance.getAppColor())
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(object.name ?? "NFT Details")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appFont)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func heroArtwork(for mediaItem: MediaItem?) -> some View {
        let artworkSize: CGFloat = 180
        let cornerRadius: CGFloat = 22
        let shadowColor = Color.black.opacity(colorScheme == .dark ? 0.45 : 0.14)

        Group {
            if object.isSVG() {
                WebView(loadURL: object.image_url)
                    .frame(width: artworkSize, height: artworkSize)
            } else {
                let resolvedURL = MediaURLResolver.resolve(object.image_url)
                PlayerArtworkImage(
                    url: resolvedURL,
                    cachedImage: ArtworkPaletteExtractor.shared.cachedImage(for: resolvedURL),
                    fallbackSymbol: mediaItem?.kind.badgeSymbol ?? "photo"
                )
                .frame(width: artworkSize, height: artworkSize)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.08), lineWidth: 0.75)
        )
        .shadow(color: shadowColor, radius: 18, x: 0, y: 10)
    }

    private func heroSecondarySubtitle(for mediaItem: MediaItem?) -> String? {
        var parts: [String] = []
        if let mediaItem {
            parts.append(mediaItem.kind.displayLabel)
            if let date = mediaItem.releaseDateText, !date.isEmpty {
                parts.append(date)
            } else if !mediaItem.audioQualityBadge.isEmpty {
                parts.append(mediaItem.audioQualityBadge)
            }
        } else {
            if object.isSVG() {
                parts.append("SVG")
            } else {
                parts.append("Digital Object")
            }
            if let standard = object.token_standard, !standard.isEmpty {
                parts.append(standard)
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func detailRow(
        title: String,
        value: String,
        appFont: Font.Design,
        monospacedValue: Bool = false
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(.body, design: appFont))
                .foregroundStyle(Color.appPrimary)
            Spacer()
            if monospacedValue {
                Text(value)
                    .font(.system(.body, design: appFont).monospacedDigit())
                    .foregroundStyle(.secondary)
            } else {
                Text(value)
                    .font(.system(.body, design: appFont))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let loadURL: String

    final class Coordinator {
        var lastLoadedURL: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedURL != loadURL else { return }
        context.coordinator.lastLoadedURL = loadURL

        if loadURL.hasPrefix("data:image/svg+xml") {
            let html = """
            <html>
            <head>
            <meta name="viewport" content="width=device-width, shrink-to-fit=YES">
            <style>html, body { width: 100%; height: 100%; margin: 0; padding: 0; display: flex; align-items: center; justify-content: center; } img { width: 100%; height: 100%; object-fit: contain; }</style>
            </head>
            <body><img src="\(loadURL)" /></body>
            </html>
            """
            uiView.loadHTMLString(html, baseURL: nil)
            return
        }

        guard let url = URL(string: loadURL) else { return }
        Task { @MainActor in
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let contents = String(data: data, encoding: .utf8) {
                let html = contents + "<style>html, body { width: 100%; height: 100%; margin: 0; padding: 0 }</style><meta name=\"viewport\" content=\"width=device-width, shrink-to-fit=YES\">"
                uiView.loadHTMLString(html, baseURL: url)
            } else {
                uiView.load(URLRequest(url: url))
            }
        }
    }
}

struct ObjectDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ObjectDetailView(object: Wallet.demoObjects()[0])
                .environmentObject(Appearance())
                .environmentObject(MediaPlayerManager())
        }
    }
}
