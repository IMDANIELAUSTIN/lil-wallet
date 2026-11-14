//
//  UpcomingFeaturesView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Roadmap overview showcasing upcoming ElectroLite capabilities and Pro early access.
struct UpcomingFeaturesView: View {
    @EnvironmentObject var appearance: Appearance
    @State private var selectedFeature: UpcomingFeatureItem?
    @State private var showingProFeaturesSheet = false

    private let roadmapItems: [UpcomingFeatureItem] = [
        UpcomingFeatureItem(
            id: "icloud-sync",
            title: "iCloud Cross-Device Wallet Sync",
            symbol: "icloud.and.arrow.down.fill",
            accentColor: .teal,
            subtitle: "Keep your tracked addresses and labels synchronized",
            badgeText: "COMING SOON",
            footerDescription: "Encrypted iCloud sync keeps your watched Ethereum addresses, custom labels, and token ordering in sync across iPhone and iPad.",
            highlights: [
                ("lock.icloud.fill", "Private Keychain Sync", "Synchronizes wallet metadata and category tags across your personal Apple devices."),
                ("arrow.triangle.2.circlepath", "Instant Portfolio Ordering", "Restores your custom token layout and merchant notes automatically."),
                ("hand.raised.fill", "Zero Third-Party Servers", "Uses your personal Apple iCloud container with zero external tracking.")
            ]
        ),
        UpcomingFeatureItem(
            id: "multi-chain",
            title: "Multi-Chain & L2 Indexing",
            symbol: "square.stack.3d.up.fill",
            accentColor: .purple,
            subtitle: "Unified balances across Ethereum, Base, Arbitrum & Optimism",
            badgeText: "COMING SOON",
            footerDescription: "Track tokens, activity, and digital objects seamlessly across Ethereum Mainnet and leading Layer 2 networks from one balance header.",
            highlights: [
                ("network", "Layer 2 Rollup Support", "Native visibility into Base, Optimism, and Arbitrum balances and fees."),
                ("bolt.fill", "Live Activity Feed", "Categorized multi-chain history with automatic merchant and fee breakdowns."),
                ("shippingbox.fill", "Cross-Chain Objects", "Collect and view NFTs across supported networks in a single Objects grid.")
            ]
        ),
        UpcomingFeatureItem(
            id: "non-custodial-btc",
            title: "Bitcoin & Cashu eCash Support",
            symbol: "bitcoinsign.circle.fill",
            accentColor: .orange,
            subtitle: "Private bearer eCash alongside Ethereum assets",
            badgeText: "COMING SOON",
            footerDescription: "Combine Chaumian eCash mints with Bitcoin and stablecoins inside ElectroLite for private, instant peer-to-peer transfers.",
            highlights: [
                ("lock.shield.fill", "100% Non-Custodial Keys", "Keys stay inside Apple Secure Enclave on your device—only you control your funds."),
                ("bolt.fill", "Lightning & Cashu Transfers", "Send and receive instant bearer tokens with minimal fees."),
                ("dollarsign.circle.fill", "Unified Portfolio Total", "View ETH, stablecoins, Bitcoin, and eCash together in your home balance.")
            ]
        )
    ]

    var body: some View {
        let appFont = appearance.getAppFont()

        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.appPrimary)
                        .padding(.top, 4)

                    Text("Upcoming Features")
                        .font(.system(.headline, design: appFont, weight: .bold))
                        .foregroundStyle(Color.appPrimary)

                    Text("Pro Subscribers get early access to Beta Features. Beta Features may be unstable so enable them with caution.")
                        .font(.system(.caption, design: appFont))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                ForEach(roadmapItems) { item in
                    Button {
                        selectedFeature = item
                    } label: {
                        HStack {
                            Label(item.title, systemImage: item.symbol)
                                .foregroundStyle(Color.appPrimary)
                            Spacer()
                            Text("Coming Soon")
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.orange.opacity(0.15), in: .capsule)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(Color(.secondarySystemGroupedBackground))

            Section {
                Button {
                    showingProFeaturesSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Support ElectroLite & Unlock Pro")
                    }
                }
                .buttonStyle(PrimaryCapsuleButtonStyle())
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        }
        .navigationTitle("Upcoming Features")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appFont)
        .sheet(item: $selectedFeature) { feature in
            UpcomingFeaturePreviewSheet(feature: feature)
                .environmentObject(appearance)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showingProFeaturesSheet) {
            NavigationStack {
                ProFeaturesView(showsDismissButton: true)
            }
            .environmentObject(appearance)
            .tint(appearance.getAppColor())
            .fontDesign(appFont)
            .presentationDragIndicator(.hidden)
        }
    }
}

private struct UpcomingFeatureItem: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let accentColor: Color
    let subtitle: String
    let badgeText: String
    let footerDescription: String
    let highlights: [(icon: String, title: String, description: String)]
}

private struct UpcomingFeaturePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance
    let feature: UpcomingFeatureItem

    @State private var showingPrivacyPolicySheet = false
    @State private var showingTermsSheet = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            RadialGradient(
                colors: [feature.accentColor.opacity(0.16), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 64))
                        .foregroundStyle(feature.accentColor)
                        .padding(.top, 20)

                    Text(feature.title)
                        .font(.system(.title2, design: appearance.getAppFont(), weight: .bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(feature.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(feature.highlights, id: \.title) { item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.icon)
                                .font(.title3)
                                .foregroundStyle(.primary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                Text(item.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                VStack(spacing: 14) {
                    Text(feature.badgeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.orange.opacity(0.15), in: .capsule)

                    Text(feature.footerDescription)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    HStack(spacing: 16) {
                        Button("Privacy Policy") {
                            showingPrivacyPolicySheet = true
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Button("Terms of Service") {
                            showingTermsSheet = true
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }

                    Button("Dismiss") {
                        dismiss()
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .fontDesign(appearance.getAppFont())
        .sheet(isPresented: $showingPrivacyPolicySheet) {
            PrivacyPolicyView()
                .environmentObject(appearance)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showingTermsSheet) {
            TermsOfServiceView()
                .environmentObject(appearance)
                .presentationDetents([.large])
        }
    }
}
