//
//  SettingsView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Binding var showSettingsView: Bool
    @AppStorage("currentWalletAddress") private var currentWalletAddress: String = ""
    @AppStorage("openSeaAPIKey") private var openSeaAPIKey: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("appColor") private var appColor = AppColor.monochrome
    @AppStorage("appFont") private var appFont = AppFont.rounded
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WalletAddress.createdAt, ascending: true)],
        animation: .default)
    private var wallets: FetchedResults<WalletAddress>
    @State private var showAddWalletSheet = CommandLine.arguments.contains("-openAddWalletSheet")
    @State private var walletToDelete: WalletAddress?
    @State private var showDeleteWalletAlert = CommandLine.arguments.contains("-openDeleteWalletAlert")
    
    var body: some View {
        let appFont = appearance.getAppFont()
        
        NavigationStack {
            Form {
                Section(content: {
                    if wallets.isEmpty {
                        NavigationLink {
                            WalletsView()
                                .environmentObject(wallet)
                                .environment(\.managedObjectContext, viewContext)
                        } label: {
                            HStack {
                                Text("Wallet #1")
                                    .font(.system(.body, design: appFont))
                                Spacer()
                                if currentWalletAddress != "" {
                                    Text(wallet.formatAddress(address: currentWalletAddress))
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        ForEach(Array(wallets.enumerated()), id: \.element.objectID) { index, savedWallet in
                            NavigationLink {
                                WalletsView()
                                    .environmentObject(wallet)
                                    .environment(\.managedObjectContext, viewContext)
                            } label: {
                                HStack {
                                    Text("Wallet #\(index + 1)")
                                        .font(.system(.body, design: appFont))
                                    Spacer()
                                    if let address = savedWallet.address, !address.isEmpty {
                                        Text(wallet.formatAddress(address: address))
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
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
                }, header: {
                    Text("Wallets")
                })
                
                Section(content: {
                    Picker(selection: $appColor, label: Text("Color").font(.system(.body, design: appFont))) {
                        ForEach(Array(AppColor.allCases), id: \.self) {
                            Text($0.rawValue.capitalized)
                                .font(.system(.body, design: appFont))
                                .foregroundStyle($0 == .monochrome ? Color.primary : $0.color)
                        }
                    }
                    
                    Picker(selection: $appFont, label: Text("Font").font(.system(.body, design: appFont))) {
                        ForEach(Array(AppFont.allCases), id: \.self) {
                            Text($0.rawValue.capitalized)
                                .font(.system(.body, design: $0.font))
                        }
                    }
                }, header: {
                    Text("Appearance")
                })
                
                Section(content: {
                    SecureField("Optional OpenSea v2 API Key", text: $openSeaAPIKey)
                        .font(.system(.body, design: appFont))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                }, header: {
                    Text("NFT API")
                }, footer: {
                    Text("Uses demo objects automatically when no API key is configured.")
                })
                
                Section {
                    NavigationLink {
                        List {
                            Section(content: {
                                Link("Zerion", destination: URL(string: "https://docs.zerion.io")!)
                                Link("OpenSea", destination: URL(string: "https://docs.opensea.io")!)
                            }, header: { Text("Data") })
                            
                            Section(content: {
                                Link("Daniel Lee Austin", destination: URL(string: "https://twitter.com/imdanielaustin")!)
                            }, header: { Text("Contributors") })
                        }
                    } label: {
                        Text("About")
                            .font(.system(.body, design: appFont))
                    }
                }
                
                Section {
                    HStack {
                        Spacer()
                        Image("SettingsLogo")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
                .listRowBackground(
                    colorScheme == .light ?
                        Color(.secondarySystemBackground) :
                        Color(.systemBackground)
                )
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done", action: { self.showSettingsView = false })
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddWalletSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .alert("Delete Wallet?", isPresented: $showDeleteWalletAlert) {
                Button("Delete", role: .destructive) {
                    if let target = walletToDelete ?? wallets.first {
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
            .sheet(isPresented: $showAddWalletSheet) {
                NavigationStack {
                    AddWalletView(showsDismissButton: true)
                        .environmentObject(wallet)
                        .environmentObject(appearance)
                        .environment(\.managedObjectContext, viewContext)
                }
                .tint(appearance.getAppColor())
                .fontDesign(appFont)
                .foregroundStyle(Color.appPrimary)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .tint(appearance.getAppColor())
        .fontDesign(appFont)
        .onChange(of: appFont) {
            appearance.updateNavBarTypography()
        }
    }
    
    private func deleteWallet(_ walletToDelete: WalletAddress) {
        let deletedAddress = walletToDelete.address
        withAnimation {
            viewContext.delete(walletToDelete)
            do {
                try viewContext.save()
                if deletedAddress == currentWalletAddress {
                    let remaining = wallets.first(where: { $0.objectID != walletToDelete.objectID })
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

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showSettingsView: .constant(true))
    }
}
