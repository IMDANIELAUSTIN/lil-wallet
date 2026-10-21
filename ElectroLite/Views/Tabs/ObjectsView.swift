//
//  ObjectsView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

struct ObjectsView: View {
    @State private var showActivityView = false
    @State private var showSettingsView = false
    @State private var showAddWalletView = false
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
                if wallet.loadingObjects {
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
                                .font(.headline)
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
                } else if wallet.objects.count == 0 && !wallet.loadingObjects {
                    VStack {
                        Spacer()
                        Text("No objects")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: appearance.getAppFont()))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.flexible(minimum: 40)),
                            GridItem(.flexible(minimum: 40))
                        ]) {
                            ForEach(wallet.objects, id: \.id) { object in
                                ObjectGridItem()
                                    .environmentObject(object)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        self.wallet.reload(reset: false, refresh: true)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Objects")
            .navigationBarTitleDisplayMode(.inline)
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
}

struct ObjectsView_Previews: PreviewProvider {
    static var previews: some View {
        ObjectsView()
    }
}
