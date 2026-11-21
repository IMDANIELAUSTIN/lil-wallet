//
//  PrivacyPolicyView.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Privacy policy sheet matching Salt's PrivacyInfo.xcprivacy declarations and local storage model.
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance

    private let sections: [(icon: String, title: String, content: String)] = [
        (
            "lock.shield.fill",
            "1. Privacy-First & Zero Tracking (CCPA / GDPR)",
            """
            Salt is built as a privacy-first, local-first wallet viewer. We do NOT collect, harvest, sell, or share your personal information, saved wallet addresses, portfolio balances, or usage habits with advertisers or data brokers.
            """
        ),
        (
            "internaldrive.fill",
            "2. On-Device Storage & Preferences",
            """
            Your saved Ethereum wallet addresses, display labels, custom token order, transaction tags, appearance settings, and optional OpenSea v2 API key are stored locally on your device using Core Data and UserDefaults.
            """
        ),
        (
            "network",
            "3. Public Blockchain & API Requests",
            """
            To fetch token balances, transaction activity, digital objects, and .eth ENS resolutions, Salt sends only the requested public wallet address or ENS handle directly from your device to Zerion, OpenSea, or ENS endpoints. No private keys or seed phrases are ever transmitted or stored.
            """
        ),
        (
            "creditcard.fill",
            "4. In-App Purchases & StoreKit Privacy",
            """
            Optional tips and Salt Pro upgrades are processed directly by Apple Inc. through the App Store (StoreKit). Salt never receives or stores your payment card details or billing address.
            """
        ),
        (
            "person.badge.shield.checkmark.fill",
            "5. Your Data Controls",
            """
            You remain in full control of your local Salt data at all times:
            • View or switch saved wallets in Settings ▸ Wallets.
            • Delete any saved wallet address via swipe-to-delete.
            • Clear or replace your optional OpenSea v2 API key anytime in Settings ▸ NFT API.
            """
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeaderCard(
                        symbol: "hand.raised.shield.fill",
                        symbolColor: Color.appPrimary,
                        title: "Salt Privacy Policy",
                        subtitle: "Effective Date: November 14, 2026",
                        badgeText: "Local-First & Zero Data Tracking Guarantee",
                        badgeColor: .green
                    )

                    ForEach(sections, id: \.title) { section in
                        SettingsDetailCard(
                            icon: section.icon,
                            title: section.title,
                            content: section.content
                        )
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Privacy Policy")
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
