//
//  ActivityDetailView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct ActivityDetailView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var appearance: Appearance
    @EnvironmentObject var wallet: Wallet
    let transaction: Transaction
    
    @State private var showEditMerchantAlert = false
    @State private var merchantNameInput = ""
    
    var body: some View {
        let appFont = appearance.getAppFont()
        let selectedCategory = wallet.category(for: transaction)
        
        List {
            Section(content: {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Text("\(wallet.formatCurrency(value: transaction.transactionValue()))")
                            .font(.system(size: 50, weight: .bold, design: appFont))
                            .multilineTextAlignment(.center)
                        
                        Button {
                            merchantNameInput = wallet.merchantName(for: transaction)
                            showEditMerchantAlert = true
                        } label: {
                            Text(wallet.merchantName(for: transaction))
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .buttonStyle(.plain)
                        
                        Text(Date(timeIntervalSince1970: TimeInterval(transaction.mined_at)).formatted(date: .long, time: .shortened))
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                    Spacer()
                }
                .padding(.vertical, 20)
            })
            .listRowBackground(
                colorScheme == .light ?
                    Color(.secondarySystemBackground) :
                    Color(.systemBackground)
            )
            
            Section(content: {
                if let address_from = transaction.address_from,
                   let fromURL = URL(string: "https://etherscan.io/address/\(address_from)") {
                    Link(destination: fromURL, label: {
                        HStack {
                            Text("From")
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(wallet.formatAddress(address: address_from))
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.secondary)
                        }
                    })
                }
                
                if let address_to = transaction.address_to,
                   let toURL = URL(string: "https://etherscan.io/address/\(address_to)") {
                    Link(destination: toURL, label: {
                        HStack {
                            Text("To")
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(wallet.formatAddress(address: address_to))
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.secondary)
                        }
                    })
                }
            }, header: {
                Text("Details")
                    .textCase(nil)
            })
            
            Section(content: {
                VStack(spacing: 6) {
                    HStack {
                        Text("Status")
                            .font(.system(.headline, design: appFont))
                        Spacer()
                        Text(transaction.status.capitalized)
                            .font(.system(.headline, design: appFont))
                    }
                    
                    HStack {
                        Text("Transaction Type")
                            .font(.system(.body, design: appFont))
                        Spacer()
                        Text(transaction.type.capitalized)
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                
                VStack(spacing: 6) {
                    HStack {
                        Text("Subtotal")
                            .font(.system(.headline, design: appFont))
                        Spacer()
                        Text(wallet.formatCurrency(value: transaction.transactionValue()))
                            .font(.system(.headline, design: appFont))
                    }
                    
                    HStack {
                        Text("Fee")
                            .font(.system(.body, design: appFont))
                        Spacer()
                        Text(wallet.formatCurrency(value: transaction.fee?.feePrice() ?? 0))
                            .font(.system(.body, design: appFont))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                
                HStack {
                    Text("Full Total")
                        .font(.system(.headline, design: appFont))
                    Spacer()
                    Text(wallet.formatCurrency(value: transaction.fullTotalValue()))
                        .font(.system(.headline, design: appFont))
                }
                .padding(.vertical, 2)
            })
            
            if let token = transaction.token {
                Section(content: {
                    HStack {
                        Text("Coin")
                            .font(.system(.body, design: appFont))
                            .lineLimit(1)
                        Spacer()
                        Text(token.symbol.uppercased())
                            .font(.system(.headline, design: appFont))
                    }
                    
                    HStack {
                        Text("Network")
                            .font(.system(.body, design: appFont))
                            .lineLimit(1)
                        Spacer()
                        Text(transaction.network)
                            .font(.system(.headline, design: appFont))
                    }
                    
                    if let transactionPrice = transaction.price {
                        HStack {
                            Text("Price")
                                .font(.system(.body, design: appFont))
                            Spacer()
                            Text(wallet.formatCurrency(value: transactionPrice))
                                .font(.system(.headline, design: appFont))
                        }
                    }
                }, header: {
                    Text("Token")
                        .textCase(nil)
                })
            }
            
            Section {
                HStack {
                    Text("Category")
                        .font(.system(.body, design: appFont))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    if let selectedCategory {
                        HStack(spacing: 8) {
                            Image(uiImage: selectedCategory.badgeIcon(size: 22))
                            Text(selectedCategory.rawValue)
                                .font(.system(.body, design: appFont))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 13, weight: .semibold, design: appFont))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
                .overlay {
                    CategoryMenuButton(
                        selectedCategory: selectedCategory,
                        onSelect: { category in
                            wallet.setCategory(category, for: transaction)
                        }
                    )
                }
            }

            if let txURL = URL(string: "https://etherscan.io/tx/\(transaction.hash)") {
                Section {
                    Link(destination: txURL, label: {
                        Text("View on Etherscan")
                            .font(.system(.body, design: appFont))
                    })
                }
                .foregroundStyle(appearance.getAppColor())
            }
        }
        .navigationTitle(transaction.title())
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appFont)
        .alert("Name of Business", isPresented: $showEditMerchantAlert) {
            TextField("Name of Business", text: $merchantNameInput)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                wallet.setMerchantName(merchantNameInput, for: transaction)
            }
        }
    }
}

private struct CategoryMenuButton: UIViewRepresentable {
    let selectedCategory: TransactionCategory?
    let onSelect: (TransactionCategory) -> Void
    
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = .clear
        button.showsMenuAsPrimaryAction = true
        button.menu = buildMenu()
        return button
    }
    
    func updateUIView(_ uiView: UIButton, context: Context) {
        uiView.menu = buildMenu()
    }
    
    private func buildMenu() -> UIMenu {
        let actions = TransactionCategory.allCases.map { category in
            UIAction(
                title: category.rawValue,
                image: category.menuIcon,
                state: selectedCategory == category ? .on : .off
            ) { _ in
                onSelect(category)
            }
        }
        return UIMenu(title: "", children: actions)
    }
}

struct ActivityDetailView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityDetailView(transaction: Transaction(id: "tx-1", token: nil, value: 0, price: 0, type: "receive", mined_at: 0, hash: "", status: "confirmed", block_number: 0, address_from: nil, address_to: nil, fee: nil))
    }
}
