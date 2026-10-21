//
//  SettingsView.swift
//  lil wallet
//
//  Created by Jordan Singer on 11/28/21.
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
    @AppStorage("appFont") private var appFont = AppFont.regular
    
    var body: some View {
        let appFont = appearance.getAppFont()
        
        NavigationStack {
            Form {
                Section(content: {
                    NavigationLink {
                        WalletsView()
                            .environmentObject(wallet)
                            .environment(\.managedObjectContext, viewContext)
                    } label: {
                        HStack {
                            Text("Wallets")
                                .font(.system(.body, design: appFont))
                            Spacer()
                            if currentWalletAddress != "" {
                                Text(wallet.formatAddress(address: currentWalletAddress))
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                })
                
                Section {
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
                }
                
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
                                Link("Jordan Singer", destination: URL(string: "https://twitter.com/jsngr")!)
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
                        Image(systemName: "square.on.circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Color(UIColor.tertiaryLabel))
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
                .listRowBackground(
                    colorScheme == .light ?
                        Color(UIColor.secondarySystemBackground) :
                        Color(UIColor.systemBackground)
                )
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done", action: { self.showSettingsView = false })
                }
            }
        }
        .tint(appearance.getAppColor())
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(showSettingsView: .constant(true))
    }
}
