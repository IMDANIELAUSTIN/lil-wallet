//
//  ActivityView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct ActivityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @State var loading = true
    @State var loadingError = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if wallet.loadingTransactions {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if wallet.transactions.count == 0 {
                    VStack {
                        Spacer()
                        Text("No activity")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: appearance.getAppFont()))
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(wallet.transactions, id: \.id) { transaction in
                            ActivityListItem()
                                .environmentObject(appearance)
                                .environmentObject(transaction)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                }
            }
        }
        .tint(appearance.getAppColor())
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
