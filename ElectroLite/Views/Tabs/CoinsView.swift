//
//  CoinsView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

struct CoinsView: View {
    @State private var showActivityView = false
    @State private var showSettingsView = false
    @State private var showAddWalletView = false
    @State var loading = true
    @State var loadingError = false
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WalletAddress.name, ascending: true)],
        animation: .default)
    private var wallets: FetchedResults<WalletAddress>
    
    var body: some View {
        NavigationStack {
            ZStack {
                if wallet.loadingTokens {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if wallets.count == 0 {
                    VStack {
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
                } else if wallet.tokens.count == 0 && !wallet.loadingTokens {
                    VStack {
                        Spacer()
                        Text("No crypto")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: appearance.getAppFont()))
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sortedTokens(), id: \.id) { token in
                            CryptoListItem()
                                .environmentObject(token)
                                .environmentObject(appearance)
                                .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable {
                        self.wallet.reload(reset: false, refresh: true)
                    }
                }
            }
            .navigationTitle(wallet.formatCurrency(value: wallet.value))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showActivityView.toggle() }, label: { Image(systemName: "clock").font(.headline) })
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
    
    func sortedTokens() -> [Token] {
        return wallet.tokens.sorted(by: {
            $0.name.lowercased() < $1.name.lowercased()
        })
    }
}

struct CryptoView_Previews: PreviewProvider {
    static var previews: some View {
        CoinsView()
    }
}
