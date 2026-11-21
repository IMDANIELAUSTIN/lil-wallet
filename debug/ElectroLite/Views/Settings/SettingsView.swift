//
//  SettingsView.swift
//  Salt
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
    @State private var showingSupportCenterSheet = false
    @State private var showingAcknowledgementsSheet = false
    @State private var showingPrivacyPolicySheet = false
    @State private var showingTermsSheet = false

    private var appVersionDisplay: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let buildNumber = info?["CFBundleVersion"] as? String ?? "1"
        return "\(shortVersion) (\(buildNumber))"
    }
    
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
                
                aboutSection(appFont: appFont)
                appInformationSection(appFont: appFont)
                
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
            .sheet(isPresented: $showingSupportCenterSheet) {
                SupportCenterView()
                    .environmentObject(appearance)
                    .tint(appearance.getAppColor())
                    .fontDesign(appFont)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingAcknowledgementsSheet) {
                NavigationStack {
                    AcknowledgementsView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingAcknowledgementsSheet = false
                                }
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appPrimary)
                            }
                        }
                }
                .environmentObject(appearance)
                .tint(appearance.getAppColor())
                .fontDesign(appFont)
                .presentationDetents([.large])
            }
            .sheet(isPresented: $showingPrivacyPolicySheet) {
                PrivacyPolicyView()
                    .environmentObject(appearance)
                    .tint(appearance.getAppColor())
                    .fontDesign(appFont)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showingTermsSheet) {
                TermsOfServiceView()
                    .environmentObject(appearance)
                    .tint(appearance.getAppColor())
                    .fontDesign(appFont)
                    .presentationDetents([.large])
            }
        }
        .tint(appearance.getAppColor())
        .fontDesign(appFont)
        .onChange(of: appFont) {
            appearance.updateNavBarTypography()
        }
    }

    @ViewBuilder
    private func aboutSection(appFont: Font.Design) -> some View {
        Section("About") {
            aboutTopicLink(.cashu, appFont: appFont)
            aboutTopicLink(.nuts, appFont: appFont)
            aboutTopicLink(.bitcoin, appFont: appFont)
            aboutTopicLink(.bitcoinCore, appFont: appFont)
            aboutTopicLink(.stablecoins, appFont: appFont)
        }
    }

    private func aboutTopicLink(_ topic: WalletAboutDetailView.Topic, appFont: Font.Design) -> some View {
        NavigationLink {
            WalletAboutDetailView(topic: topic)
        } label: {
            Text(topic.title)
                .font(.system(.body, design: appFont))
                .foregroundStyle(Color.appPrimary)
        }
    }

    @ViewBuilder
    private func appInformationSection(appFont: Font.Design) -> some View {
        Section("App Information") {
            NavigationLink {
                UpcomingFeaturesView()
            } label: {
                appInfoRowLabel("Upcoming Features", symbol: "star.fill", design: appFont)
            }

            NavigationLink {
                ProFeaturesView()
            } label: {
                appInfoRowLabel("Pro Features", symbol: "heart.fill", design: appFont)
            }

            Button {
                showingSupportCenterSheet = true
            } label: {
                appInfoRowLabel("Support Center", symbol: "questionmark.circle.fill", design: appFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showingAcknowledgementsSheet = true
            } label: {
                appInfoRowLabel("Acknowledgements", symbol: "doc.text.fill", design: appFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showingPrivacyPolicySheet = true
            } label: {
                appInfoRowLabel("Privacy Policy", symbol: "hand.raised.fill", design: appFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                showingTermsSheet = true
            } label: {
                appInfoRowLabel("Terms of Service", symbol: "doc.text.fill", design: appFont)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Text("Version")
                    .font(.system(.body, design: appFont))
                    .foregroundStyle(Color.appPrimary)
                Spacer()
                Text(appVersionDisplay)
                    .font(.system(.body, design: appFont))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func appInfoRowLabel(_ title: String, symbol: String, design: Font.Design) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 24)
            Text(title)
                .font(.system(.body, design: design))
                .foregroundStyle(Color.appPrimary)
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
