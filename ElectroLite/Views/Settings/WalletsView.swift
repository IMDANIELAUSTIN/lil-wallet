//
//  WalletsView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

struct WalletsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WalletAddress.name, ascending: true)],
        animation: .default)
    private var wallets: FetchedResults<WalletAddress>
    @AppStorage("currentWalletAddress") private var currentWalletAddress: String = ""
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @State private var walletToDelete: WalletAddress?
    @State private var showDeleteWalletAlert = false
    
    var body: some View {
        let appFont = appearance.getAppFont()
        
        ZStack {
            if wallets.count == 0 {
                VStack {
                    Spacer()
                    Text("No wallets")
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: appearance.getAppFont()))
                    Spacer()
                }
            } else {
                List {
                    Section {
                        ForEach(wallets, id: \.objectID) { savedWallet in
                            Button(action: { setCurrentWalletAddress(address: savedWallet.address ?? "") }, label: {
                                Label {
                                    HStack {
                                        Text(savedWallet.name ?? "Wallet")
                                            .foregroundStyle(.primary)
                                            .font(.system(.body, design: appFont))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(wallet.formatAddress(address: savedWallet.address ?? ""))
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } icon: {
                                    Image(systemName: "checkmark")
                                        .font(.headline)
                                        .opacity(currentWalletAddress == savedWallet.address ? 1 : 0)
                                }
                            })
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button {
                                    walletToDelete = savedWallet
                                    showDeleteWalletAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
        }
        .alert("Delete Wallet?", isPresented: $showDeleteWalletAlert) {
            Button("Delete", role: .destructive) {
                if let target = walletToDelete {
                    deleteWallet(target)
                }
                walletToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                walletToDelete = nil
            }
        } message: {
            Text("Continuing with this action is permanent and irreversible. Please continue with care.")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    AddWalletView()
                        .environmentObject(wallet)
                        .environment(\.managedObjectContext, viewContext)
                } label: {
                    Text("Add")
                        .font(.system(.headline, design: appFont))
                }
            }
        }
        .navigationTitle("Wallets")
        .fontDesign(appFont)
    }
    
    func setCurrentWalletAddress(address: String) {
        let existingCurrentWalletAddress = self.currentWalletAddress
        if existingCurrentWalletAddress != address {
            self.currentWalletAddress = address
            self.wallet.reload(reset: true, refresh: false)
        }
    }

    private func deleteWallet(_ target: WalletAddress) {
        let deletedAddress = target.address
        withAnimation {
            viewContext.delete(target)

            do {
                try viewContext.save()
                if deletedAddress == currentWalletAddress {
                    let remaining = wallets.first(where: { $0.objectID != target.objectID })
                    currentWalletAddress = remaining?.address ?? ""
                    wallet.reload(reset: true, refresh: false)
                }
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct EditWalletsView_Previews: PreviewProvider {
    static var previews: some View {
        WalletsView()
    }
}
