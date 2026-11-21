//
//  ObjectDetailView.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import WebKit

struct ObjectDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance
    @EnvironmentObject var mediaPlayer: MediaPlayerManager
    let object: OpenSeaAsset
    var isPresentedInSheet: Bool = false

    var body: some View {
        let appFont = appearance.getAppFont()
        let mediaItem = object.resolvedMediaItem()

        List {
            Group {
                if object.isSVG() {
                    WebView(loadURL: object.image_url)
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    AsyncImage(url: URL(string: object.image_url)) { image in
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Rectangle()
                            .foregroundStyle(Color(.secondarySystemBackground))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)

            if let mediaItem {
                Section {
                    HStack(spacing: 12) {
                        Button {
                            OrchardMotion.HapticStyle.medium.fire()
                            if isPresentedInSheet {
                                dismiss()
                            }
                            mediaPlayer.play(mediaItem, autoExpand: true)
                        } label: {
                            Label(
                                mediaItem.kind.isVideoCapable ? "Watch Now" : "Play Now",
                                systemImage: "play.fill"
                            )
                            .font(.system(.headline, design: appFont))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(appearance.getAppColor())

                        Button {
                            OrchardMotion.HapticStyle.light.fire()
                            mediaPlayer.addToQueue(mediaItem)
                        } label: {
                            Label("Queue", systemImage: "text.append")
                                .font(.system(.subheadline, design: appFont).weight(.semibold))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 6)
                        }
                        .buttonStyle(.bordered)
                        .tint(appearance.getAppColor())
                    }
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                }
            }

            Section(content: {
                VStack(alignment: .leading, spacing: 6) {
                    if let mediaItem {
                        HStack(spacing: 6) {
                            Label(mediaItem.kind.displayLabel, systemImage: mediaItem.kind.badgeSymbol)
                                .font(.system(.caption, design: appFont).weight(.semibold))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemFill), in: Capsule())

                            if !mediaItem.audioQualityBadge.isEmpty {
                                Text(mediaItem.audioQualityBadge)
                                    .font(.system(.caption, design: appFont).weight(.medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color(.tertiarySystemFill), in: Capsule())
                            }
                        }
                        .padding(.bottom, 2)
                    }

                    Text(object.name ?? "Untitled")
                        .font(.system(.headline, design: appFont))

                    if let description = object.description {
                        Text(description)
                            .font(.system(.body, design: appFont))
                    }
                }
                .listRowSeparator(.hidden)
            }, header: {
                Text("About")
            })

            if object.traits.count > 0 {
                Section(content: {
                    ForEach(object.traits) { trait in
                        HStack {
                            Text(trait.trait_type.capitalized)
                                .font(.system(.body, design: appFont))
                                .lineLimit(1)
                            Spacer()
                            Text(trait.value.capitalized)
                                .font(.system(.headline, design: appFont))
                                .lineLimit(1)
                        }
                    }
                    .listRowSeparator(.hidden)
                }, header: {
                    Text("Properties")
                })
            }

            if let permalinkURL = URL(string: object.permalink) {
                Section(content: {
                    Group {
                        Link(destination: permalinkURL, label: {
                            Text("View on OpenSea")
                                .font(.system(.body, design: appFont))
                        })
                    }
                    .font(.system(.body, design: appFont))
                    .foregroundStyle(appearance.getAppColor())
                    .listRowSeparator(.hidden)
                }, header: {
                    Text("Options")
                })
            }
        }
        .listStyle(.inset)
        .navigationTitle(object.name ?? "Untitled")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appFont)
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
        ObjectDetailView(object: Wallet.demoObjects()[0])
            .environmentObject(Appearance())
            .environmentObject(MediaPlayerManager())
    }
}
