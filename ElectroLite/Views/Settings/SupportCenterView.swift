//
//  SupportCenterView.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Help and FAQ sheet tailored to Salt wallet management, objects, and appearance settings.
struct SupportCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance

    private let faqItems: [(question: String, answer: String)] = [
        (
            "How do I add or switch Ethereum wallets?",
            "Open Settings and tap the + button (or open Wallets) to enter any 0x Ethereum address or .eth ENS name. Tap any saved wallet inside Wallets to switch your active portfolio view."
        ),
        (
            "How do portfolio tokens and live activity update?",
            "Salt streams token balances, pricing, and transaction activity via Zerion. Pull to refresh on Home or Objects anytime to reload balances and recent transfers."
        ),
        (
            "Why do I see demo NFTs in Objects?",
            "When no OpenSea v2 API key is configured under Settings ▸ NFT API, Salt automatically displays sample digital objects. Paste your own OpenSea v2 API key to load your wallet's live collectibles."
        ),
        (
            "Does Salt store private keys or seed phrases?",
            "No. Salt operates as a read-only watch wallet using public Ethereum addresses and ENS names stored locally on your device. Private keys and seed phrases are never requested or stored."
        ),
        (
            "How can I customize appearance or remove a wallet?",
            "Choose your preferred accent Color and Font design (Regular, Rounded, Monospaced, or Serif) in Settings ▸ Appearance. Swipe left on any wallet row in Settings or Wallets to delete it."
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeaderCard(
                        symbol: "questionmark.circle.fill",
                        symbolColor: .blue,
                        title: "Support Center",
                        subtitle: "Help, Documentation & FAQs",
                        badgeText: "Wallet & Digital Objects Guide",
                        badgeColor: .blue
                    )

                    ForEach(faqItems, id: \.question) { item in
                        SettingsFAQCard(question: item.question, answer: item.answer)
                    }

                    Spacer(minLength: 24)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Support Center")
            .navigationBarTitleDisplayMode(.inline)
            .fontDesign(appearance.getAppFont())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appPrimary)
                }
            }
        }
    }
}
