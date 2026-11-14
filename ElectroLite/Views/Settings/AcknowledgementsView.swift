//
//  AcknowledgementsView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Attributions view preserving ElectroLite's Data & Contributor credits alongside open-source frameworks.
struct AcknowledgementsView: View {
    @EnvironmentObject var appearance: Appearance

    private struct CreditItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let badge: String
        let badgeColor: Color
        let description: String
        let attributionNote: String
        let linkLabel: String
        let linkURL: String
    }

    private let dataProviders: [CreditItem] = [
        CreditItem(
            id: "zerion",
            title: "Zerion",
            subtitle: "Portfolio & Transaction Stream API",
            badge: "Data Provider",
            badgeColor: .blue,
            description: "Real-time Ethereum token balances, historical pricing, and live address transaction feeds powering ElectroLite's Home and Activity screens.",
            attributionNote: "Zerion Developer Documentation.",
            linkLabel: "Docs",
            linkURL: "https://docs.zerion.io"
        ),
        CreditItem(
            id: "opensea",
            title: "OpenSea",
            subtitle: "NFT & Digital Objects API v2",
            badge: "Data Provider",
            badgeColor: .indigo,
            description: "On-chain collectible metadata, artwork resolution, and trait indexing for ElectroLite's Objects gallery.",
            attributionNote: "OpenSea Developer Documentation.",
            linkLabel: "Docs",
            linkURL: "https://docs.opensea.io"
        ),
        CreditItem(
            id: "ens",
            title: "Ethereum Name Service (ENS)",
            subtitle: "Decentralized Domain Resolution",
            badge: "Open Standard",
            badgeColor: .teal,
            description: "Human-readable .eth name resolution mapping readable handles to Ethereum wallet addresses.",
            attributionNote: "Open ENS protocol specification.",
            linkLabel: "Website",
            linkURL: "https://ens.domains"
        )
    ]

    private let openSourceLibraries: [CreditItem] = [
        CreditItem(
            id: "socketio",
            title: "Socket.IO Client Swift",
            subtitle: "Socket.IO Contributors",
            badge: "MIT License",
            badgeColor: .green,
            description: "Real-time bidirectional event-based WebSocket client powering live Zerion portfolio and activity updates.",
            attributionNote: "Open-source Swift package.",
            linkLabel: "License",
            linkURL: "https://github.com/socketio/socket.io-client-swift"
        ),
        CreditItem(
            id: "starscream",
            title: "Starscream",
            subtitle: "Dalton Cherry",
            badge: "Apache 2.0",
            badgeColor: .orange,
            description: "Conforming WebSocket client library in Swift supporting RFC 6455 transport.",
            attributionNote: "Apache License 2.0.",
            linkLabel: "License",
            linkURL: "https://github.com/daltoniam/Starscream"
        ),
        CreditItem(
            id: "open-protocols",
            title: "Bitcoin, Cashu & Ethereum Specs",
            subtitle: "Open Protocol Communities",
            badge: "Open Standards",
            badgeColor: .purple,
            description: "Public specifications including Cashu NUTs, Bitcoin Core consensus documentation, and Ethereum ERC token standards.",
            attributionNote: "Public open-source specifications.",
            linkLabel: "Cashu",
            linkURL: "https://cashu.space"
        )
    ]

    private let contributors: [CreditItem] = [
        CreditItem(
            id: "daniel-austin",
            title: "Daniel Lee Austin",
            subtitle: "Creator & Lead Engineer",
            badge: "Contributor",
            badgeColor: .mint,
            description: "Designed and built ElectroLite for fast, minimalist tracking of digital currencies and on-chain objects on iOS.",
            attributionNote: "@imdanielaustin",
            linkLabel: "Profile",
            linkURL: "https://twitter.com/imdanielaustin"
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsHeaderCard(
                    symbol: "checkmark.seal.fill",
                    symbolColor: .blue,
                    title: "Acknowledgements & Credits",
                    subtitle: "Data Providers • Open Source • Contributors"
                )

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                        Text("Local-First & Zero Tracking Commitment")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.appPrimary)
                    }

                    Text("ElectroLite runs locally on your device with zero third-party analytics or ad tracking SDKs, connecting only to the blockchain data APIs required to display your wallets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                creditSection(title: "DATA & MARKET INFRASTRUCTURE", items: dataProviders)
                creditSection(title: "OPEN-SOURCE LIBRARIES & PROTOCOLS", items: openSourceLibraries)
                creditSection(title: "CONTRIBUTORS", items: contributors)

                Spacer(minLength: 24)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Acknowledgements")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appearance.getAppFont())
    }

    @ViewBuilder
    private func creditSection(title: String, items: [CreditItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(items) { item in
                SettingsAttributionCard(
                    title: item.title,
                    subtitle: item.subtitle,
                    badge: item.badge,
                    badgeColor: item.badgeColor,
                    description: item.description,
                    attributionNote: item.attributionNote,
                    linkLabel: item.linkLabel,
                    linkURL: item.linkURL
                )
            }
        }
    }
}
