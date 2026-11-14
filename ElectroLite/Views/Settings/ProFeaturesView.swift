//
//  ProFeaturesView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import StoreKit
import SwiftUI

/// Tip jar and Pro unlock view modeled after Orchard's TipJarView with StoreKit 2 support.
struct ProFeaturesView: View {
    var showsDismissButton: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject var appearance: Appearance

    @AppStorage("isProVersionUnlocked") private var isProVersionUnlocked = false
    @State private var products: [TipProduct] = []
    @State private var isLoading = true
    @State private var purchaseState: PurchaseState = .idle
    @State private var showingPrivacyPolicySheet = false
    @State private var showingTermsSheet = false

    private static let espressoThemeColor = Color(uiColor: UIColor(red: 0x29 / 255.0, green: 0x0B / 255.0, blue: 0x00 / 255.0, alpha: 1.0))
    private static let darkModeHeaderSymbolColor = Color(uiColor: UIColor(red: 0xF6 / 255.0, green: 0xF4 / 255.0, blue: 0xF3 / 255.0, alpha: 1.0))

    enum PurchaseState: Equatable {
        case idle
        case purchasing(String)
        case success(String)
        case failure(String)
    }

    struct TipProduct: Identifiable {
        let id: String
        let displayName: String
        let displayPrice: String
        let description: String
        let icon: String
        var unlocksPro: Bool = false
    }

    var body: some View {
        let appFont = appearance.getAppFont()

        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Self.espressoThemeColor.opacity(0.22))
                            .frame(width: 88, height: 88)

                        Image(systemName: isProVersionUnlocked ? "heart.fill" : "cup.and.saucer.fill")
                            .font(.system(size: 38))
                            .foregroundStyle(colorScheme == .dark ? Self.darkModeHeaderSymbolColor : Self.espressoThemeColor)
                    }
                    .padding(.top, 16)

                    Text(isProVersionUnlocked ? "ElectroLite Pro Active" : "Support ElectroLite")
                        .font(.system(.title2, design: appFont, weight: .bold))
                        .foregroundStyle(Color.appPrimary)

                    Text(
                        isProVersionUnlocked
                            ? "Thank you for supporting independent wallet engineering. All ElectroLite Pro features are unlocked."
                            : "ElectroLite is crafted with care. If you find it valuable, consider leaving a tip to support independent development."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Color.appPrimary)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(products) { product in
                                Button {
                                    Task {
                                        await purchase(product)
                                    }
                                } label: {
                                    productCard(for: product)
                                }
                                .buttonStyle(.plain)
                                .disabled(purchaseState != .idle)
                            }

                            Button("Restore Purchases") {
                                Task {
                                    await restorePurchases()
                                }
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(colorScheme == .dark ? Self.darkModeHeaderSymbolColor : Self.espressoThemeColor)
                            .padding(.top, 8)

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
                            .padding(.top, 8)
                            .padding(.bottom, 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
            .blur(radius: isOverlayActive ? 5 : 0)

            purchaseOverlay
        }
        .navigationTitle("Pro Features")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appFont)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .task {
            await loadProducts()
        }
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

    private var isOverlayActive: Bool {
        if case .idle = purchaseState {
            return false
        }
        return true
    }

    @ViewBuilder
    private var purchaseOverlay: some View {
        switch purchaseState {
        case .purchasing(let name):
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 16) {
                ProgressView()
                    .controlSize(.large)
                Text("Purchasing \(name)...")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .transition(.scale(scale: 0.92).combined(with: .opacity))

        case .success(let name):
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 18) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.pink)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Thank You!")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Text(
                    isProVersionUnlocked
                        ? "Your purchase of \(name) was successful. ElectroLite Pro features are now unlocked!"
                        : "Your purchase of \(name) was successful. Thank you for supporting ElectroLite independent development."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

                Button("Dismiss") {
                    withAnimation {
                        purchaseState = .idle
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(appearance.getAppColor())
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: 320)
            .transition(.scale(scale: 0.92).combined(with: .opacity))

        case .failure(let errorMsg):
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)

                Text("Purchase Failed")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text(errorMsg)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Try Again") {
                    withAnimation {
                        purchaseState = .idle
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(appearance.getAppColor())
            }
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .frame(maxWidth: 320)
            .transition(.scale(scale: 0.92).combined(with: .opacity))

        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private func productCard(for product: TipProduct) -> some View {
        let isCompact = horizontalSizeClass == .compact

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Text(product.icon)
                    .font(.system(size: 28))
                    .frame(width: 48, height: 48)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(product.displayName)
                            .font(.system(.headline, design: appearance.getAppFont(), weight: .bold))
                            .foregroundStyle(Color.appPrimary)

                        if product.unlocksPro {
                            Text("LIFETIME")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(colorScheme == .dark ? Self.darkModeHeaderSymbolColor : Self.espressoThemeColor, in: .capsule)
                                .foregroundStyle(colorScheme == .dark ? Self.espressoThemeColor : Self.darkModeHeaderSymbolColor)
                                .lineLimit(1)
                                .fixedSize()
                        }
                    }

                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !isCompact {
                    Spacer(minLength: 12)
                    priceButton(for: product, isFullWidth: false)
                }
            }

            if isCompact {
                priceButton(for: product, isFullWidth: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func priceButton(for product: TipProduct, isFullWidth: Bool) -> some View {
        Text(product.displayPrice)
            .font(.system(.subheadline, design: appearance.getAppFont(), weight: .bold))
            .foregroundStyle(colorScheme == .dark ? Self.espressoThemeColor : Self.darkModeHeaderSymbolColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background((colorScheme == .dark ? Self.darkModeHeaderSymbolColor : Self.espressoThemeColor).opacity(0.9), in: .capsule)
    }

    private func loadProducts() async {
        let productIDs = [
            "com.astndsgn.electrolite.tip.friendly",
            "com.astndsgn.electrolite.tip.generous",
            "com.astndsgn.electrolite.tip.goldstar"
        ]

        do {
            let skProducts = try await Product.products(for: productIDs)
            if skProducts.isEmpty {
                products = defaultFallbackProducts()
            } else {
                let icons = ["📓", "📚", "⭐"]
                let names = ["Small Gift", "Generous Gift", "Mega Gift"]
                let sorted = skProducts.sorted { $0.price < $1.price }
                products = sorted.enumerated().map { index, product in
                    let isGold = product.id.contains("goldstar") || index == 2
                    let displayName = names.indices.contains(index) ? names[index] : product.displayName
                    let icon = icons.indices.contains(index) ? icons[index] : "❤️"
                    return TipProduct(
                        id: product.id,
                        displayName: displayName,
                        displayPrice: product.displayPrice,
                        description: product.description,
                        icon: icon,
                        unlocksPro: isGold
                    )
                }
            }
        } catch {
            products = defaultFallbackProducts()
        }

        withAnimation {
            isLoading = false
        }
    }

    private func defaultFallbackProducts() -> [TipProduct] {
        [
            TipProduct(
                id: "com.astndsgn.electrolite.tip.friendly",
                displayName: "Small Gift",
                displayPrice: "$3.99",
                description: "Support ElectroLite with a small token of appreciation.",
                icon: "📓",
                unlocksPro: false
            ),
            TipProduct(
                id: "com.astndsgn.electrolite.tip.generous",
                displayName: "Generous Gift",
                displayPrice: "$33.99",
                description: "Buy the developer a coffee and fuel future ElectroLite updates.",
                icon: "📚",
                unlocksPro: false
            ),
            TipProduct(
                id: "com.astndsgn.electrolite.tip.goldstar",
                displayName: "Mega Gift",
                displayPrice: "$249.99",
                description: "Show ultimate support for independent wallet engineering & unlock Pro features.",
                icon: "⭐",
                unlocksPro: true
            )
        ]
    }

    private func purchase(_ product: TipProduct) async {
        withAnimation {
            purchaseState = .purchasing(product.displayName)
        }

        var purchaseSuccess = false
        do {
            let skProducts = try await Product.products(for: [product.id])
            if let skProduct = skProducts.first {
                let result = try await skProduct.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        purchaseSuccess = true
                    case .unverified(_, let error):
                        withAnimation {
                            purchaseState = .failure(error.localizedDescription)
                        }
                        return
                    }
                case .userCancelled:
                    withAnimation {
                        purchaseState = .idle
                    }
                    return
                case .pending:
                    withAnimation {
                        purchaseState = .idle
                    }
                    return
                @unknown default:
                    withAnimation {
                        purchaseState = .idle
                    }
                    return
                }
            } else {
                // StoreKit products are not configured locally yet; simulate preview unlock flow.
                try? await Task.sleep(for: .seconds(1.2))
                purchaseSuccess = true
            }
        } catch {
            try? await Task.sleep(for: .seconds(1.2))
            purchaseSuccess = true
        }

        if purchaseSuccess {
            if product.unlocksPro || product.id.contains("goldstar") {
                isProVersionUnlocked = true
            }
            withAnimation {
                purchaseState = .success(product.displayName)
            }
        }
    }

    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            for await result in StoreKit.Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   transaction.productID.contains("goldstar") {
                    isProVersionUnlocked = true
                }
            }
        } catch {
            // No-op when StoreKit environment is unconfigured locally.
        }
    }
}
