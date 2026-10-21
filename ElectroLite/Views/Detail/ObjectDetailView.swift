//
//  ObjectDetailView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import WebKit

struct ObjectDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var object: OpenSeaAsset
    @EnvironmentObject var appearance: Appearance
    
    var body: some View {
        let appFont = appearance.getAppFont()
        
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
                            .foregroundStyle(Color(UIColor.secondarySystemBackground))
                            .aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            
            Section(content: {
                VStack(alignment: .leading, spacing: 4) {
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
    }
}

struct WebView: UIViewRepresentable {
    let loadURL: String
    
    func makeUIView(context: Context) -> WKWebView  {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isUserInteractionEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
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
        ObjectDetailView()
    }
}
