//
//  CoinsView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CoinsView: View {
    @State private var showActivityView = CommandLine.arguments.contains("-openActivity")
    @State private var showSettingsView = CommandLine.arguments.contains("-openSettings")
    @State private var showAddWalletView = false
    @State private var draggedToken: Token?
    @State private var selectedToken: Token?
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WalletAddress.name, ascending: true)],
        animation: .default)
    private var wallets: FetchedResults<WalletAddress>
    
    private var balanceHeader: some View {
        HStack {
            Spacer()
            Text(wallet.formatCurrency(value: wallet.value))
                .font(appearance.getBalanceFont(size: 34, weight: .bold))
                .foregroundStyle(Color.appPrimary)
                .multilineTextAlignment(.center)
            Spacer()
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(.subheadline, design: appearance.getAppFont()).weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                if wallet.loadingTokens {
                    VStack {
                        balanceHeader
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if wallets.count == 0 {
                    VStack {
                        balanceHeader
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        Spacer()
                        Text("No wallets")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: appearance.getAppFont()))
                        Button(action: { showAddWalletView = true }, label: {
                            Text("Add wallet")
                                .font(.system(.headline, design: appearance.getAppFont()))
                        })
                        .buttonStyle(.bordered)
                        .sheet(isPresented: $showAddWalletView) {
                            NavigationStack { AddWalletView() }
                                .environmentObject(wallet)
                                .environmentObject(appearance)
                                .tint(appearance.getAppColor())
                        }
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            balanceHeader
                                .padding(.top, 8)
                                .padding(.bottom, 4)
                            
                            // Portfolio Section
                            VStack(alignment: .leading, spacing: 6) {
                                sectionHeader("Portfolio")
                                
                                if wallet.tokens.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text("No crypto")
                                            .foregroundStyle(.secondary)
                                            .font(.system(.body, design: appearance.getAppFont()))
                                            .padding(.vertical, 20)
                                        Spacer()
                                    }
                                } else {
                                    VStack(spacing: 2) {
                                        ForEach(wallet.tokens) { token in
                                            CryptoListItem(
                                                token: token,
                                                onSelect: { selectedToken = token }
                                            )
                                            .onDrag {
                                                self.draggedToken = token
                                                return NSItemProvider(object: token.id as NSString)
                                            }
                                            .onDrop(
                                                of: [UTType.text],
                                                delegate: PortfolioDropDelegate(
                                                    targetToken: token,
                                                    wallet: wallet,
                                                    draggedToken: $draggedToken
                                                )
                                            )
                                        }
                                    }
                                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.82), value: wallet.tokens)
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // Gallery Section
                            VStack(alignment: .leading, spacing: 12) {
                                sectionHeader("Gallery")
                                
                                if wallet.loadingObjects {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding(.vertical, 24)
                                        Spacer()
                                    }
                                } else if wallet.objects.isEmpty {
                                    HStack {
                                        Spacer()
                                        Text("No objects")
                                            .foregroundStyle(.secondary)
                                            .font(.system(.body, design: appearance.getAppFont()))
                                            .padding(.vertical, 24)
                                        Spacer()
                                    }
                                } else {
                                    LazyVGrid(columns: [
                                        GridItem(.flexible(minimum: 40), spacing: 12),
                                        GridItem(.flexible(minimum: 40), spacing: 12)
                                    ], spacing: 12) {
                                        ForEach(wallet.objects) { object in
                                            ObjectGridItem(object: object)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        self.wallet.reload(reset: false, refresh: true)
                    }
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $selectedToken) { token in
                CryptoDetailView(token: token)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showActivityView.toggle() }, label: { Image(systemName: "text.page").font(.headline) })
                        .sheet(isPresented: $showActivityView) {
                            ActivityView()
                                .environmentObject(wallet)
                                .environmentObject(appearance)
                        }
                }
                
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsView.toggle() }, label: { Image(systemName: "gear").font(.headline) })
                        .sheet(isPresented: $showSettingsView) {
                            SettingsView(showSettingsView: $showSettingsView)
                                .environmentObject(wallet)
                                .environmentObject(appearance)
                                .environment(\.managedObjectContext, viewContext)
                        }
                }
            }
        }
    }
}

struct CryptoView_Previews: PreviewProvider {
    static var previews: some View {
        CoinsView()
    }
}

private struct PortfolioDropDelegate: DropDelegate {
    let targetToken: Token
    let wallet: Wallet
    @Binding var draggedToken: Token?
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggedToken = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedToken, draggedToken.id != targetToken.id else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
            wallet.reorderToken(dragged: draggedToken, target: targetToken)
        }
    }
}
