//
//  TermsOfServiceView.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Terms of Service & Apple Standard EULA disclosure sheet for Salt.
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance

    private let sections: [(icon: String, title: String, content: String)] = [
        (
            "checkmark.seal.fill",
            "1. Agreement to Terms & Apple EULA",
            """
            By installing or using Salt, you agree to be bound by these Terms of Service and Apple's Standard End User License Agreement (EULA). If you do not agree to these terms, do not install or use the app.
            """
        ),
        (
            "cart.fill",
            "2. In-App Purchases, Tips & Refunds",
            """
            Salt offers optional tips and Pro feature unlocks via Apple StoreKit. Payment is charged directly to your Apple Account upon confirmation of purchase. All billing and refund requests are processed by Apple Support (reportaproblem.apple.com).
            """
        ),
        (
            "network",
            "3. Watch-Only Wallet & Blockchain Data",
            """
            Salt displays portfolio balances, transaction activity, and digital objects sourced from public blockchains and third-party APIs (such as Zerion, OpenSea, and ENS). Market valuations and metadata are provided for informational purposes only and do not constitute financial, investment, or tax advice.
            """
        ),
        (
            "exclamationmark.triangle.fill",
            "4. Disclaimer of Warranties",
            """
            Salt is provided "AS IS" and "AS AVAILABLE" without warranties of any kind, either express or implied. Availability and accuracy of third-party blockchain indexing APIs may vary over time.
            """
        ),
        (
            "building.columns.fill",
            "5. Limitation of Liability & Governing Law",
            """
            To the maximum extent permitted by applicable law, Salt and its contributors shall not be liable for indirect, incidental, special, consequential, or punitive damages resulting from your use of the app. These Terms are governed by the laws of the State of California and the United States of America.
            """
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    SettingsHeaderCard(
                        symbol: "doc.text.fill",
                        symbolColor: Color.appPrimary,
                        title: "Terms of Service & EULA",
                        subtitle: "Effective Date: November 14, 2026",
                        badgeText: "Apple Standard EULA & StoreKit Terms",
                        badgeColor: .blue
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
            .navigationTitle("Terms of Service")
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
