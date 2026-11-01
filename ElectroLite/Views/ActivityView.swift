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
    @State private var searchText: String = {
        if let idx = CommandLine.arguments.firstIndex(of: "-searchQuery"),
           idx + 1 < CommandLine.arguments.count {
            return CommandLine.arguments[idx + 1]
        }
        return ""
    }()
    
    private static let stopWords: Set<String> = [
        "a", "an", "the", "my", "in", "on", "at", "for", "from", "to", "with", "of",
        "and", "or", "all", "show", "find", "transactions", "transaction", "activity"
    ]
    
    private var filteredTransactions: [Transaction] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return wallet.transactions
        }
        
        let queryTokens = trimmed
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "$.")).inverted)
            .filter { !$0.isEmpty && !Self.stopWords.contains($0) }
        
        guard !queryTokens.isEmpty else {
            return wallet.transactions
        }
        
        return wallet.transactions.filter { tx in
            matchesSemanticTokens(queryTokens, for: tx)
        }
    }
    
    private func matchesSemanticTokens(_ tokens: [String], for tx: Transaction) -> Bool {
        let searchableCorpus = buildSemanticCorpus(for: tx)
        return tokens.allSatisfy { token in
            searchableCorpus.contains(token)
        }
    }
    
    private func buildSemanticCorpus(for tx: Transaction) -> String {
        var parts: [String] = []
        
        let typeLower = tx.type.lowercased()
        parts.append(typeLower)
        parts.append(tx.title().lowercased())
        
        // Action / direction semantic synonyms
        switch typeLower {
        case "receive":
            parts.append(contentsOf: ["receive", "received", "receiving", "incoming", "deposit", "deposited", "credit", "in", "earned"])
        case "send":
            parts.append(contentsOf: ["send", "sent", "sending", "outgoing", "payment", "paid", "pay", "transfer", "transferred", "spend", "spent", "withdraw", "withdrawal", "out"])
        case "mint":
            parts.append(contentsOf: ["mint", "minted", "minting", "nft", "collectible"])
        case "trade", "swap":
            parts.append(contentsOf: ["swap", "swapped", "trade", "traded", "exchange", "exchanged", "convert", "converted"])
        default:
            break
        }
        
        // Token symbol, name & asset class
        if let token = tx.token {
            let symbol = token.symbol.lowercased()
            let name = token.name.lowercased()
            parts.append(symbol)
            parts.append(name)
            if ["usdc", "usdt", "dai"].contains(symbol) {
                parts.append(contentsOf: ["stablecoin", "dollar", "usd", "cash"])
            } else if symbol == "eth" {
                parts.append(contentsOf: ["ether", "ethereum", "crypto", "gas"])
            }
        }
        
        // Value & semantic magnitude
        let usdValue = tx.transactionValue()
        let formattedCurrency = wallet.formatCurrency(value: usdValue).lowercased()
        let plainCurrency = formattedCurrency.replacingOccurrences(of: ",", with: "")
        let numericOnly = plainCurrency.replacingOccurrences(of: "$", with: "")
        parts.append(contentsOf: [formattedCurrency, plainCurrency, numericOnly, String(format: "%.0f", usdValue)])
        
        if usdValue >= 500 {
            parts.append(contentsOf: ["large", "high", "big", "major", "expensive"])
        } else if usdValue > 0 {
            parts.append(contentsOf: ["small", "low", "minor"])
        }
        
        // Date & relative time terms
        let date = Date(timeIntervalSince1970: TimeInterval(tx.mined_at))
        let abbreviatedDate = date.formatted(date: .abbreviated, time: .omitted).lowercased()
        let completeDate = date.formatted(date: .complete, time: .omitted).lowercased()
        parts.append(abbreviatedDate)
        parts.append(completeDate)
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            parts.append(contentsOf: ["today", "recent", "latest", "now"])
        } else if calendar.isDateInYesterday(date) {
            parts.append(contentsOf: ["yesterday", "recent"])
        }
        if let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day, abs(daysAgo) <= 7 {
            parts.append(contentsOf: ["week", "recent", "latest"])
        }
        if let monthsAgo = calendar.dateComponents([.month], from: date, to: Date()).month, abs(monthsAgo) == 0 {
            parts.append("month")
        }
        
        // Category, merchant, network, status, addresses & hash
        if let category = wallet.category(for: tx) {
            parts.append(category.rawValue.lowercased())
        }
        parts.append(wallet.merchantName(for: tx).lowercased())
        parts.append(tx.network.lowercased())
        parts.append(tx.status.lowercased())
        parts.append(tx.hash.lowercased())
        if let from = tx.address_from?.lowercased() {
            parts.append(from)
        }
        if let to = tx.address_to?.lowercased() {
            parts.append(to)
        }
        
        return parts.joined(separator: " ")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if wallet.loadingTransactions {
                    VStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if wallet.transactions.isEmpty {
                    VStack {
                        Spacer()
                        Text("No activity")
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: appearance.getAppFont()))
                        Spacer()
                    }
                } else if filteredTransactions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredTransactions) { transaction in
                            ActivityListItem(transaction: transaction)
                                .listRowSeparator(.hidden)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                    }
                }
                
                if #available(iOS 26.0, *) {
                    DefaultToolbarItem(kind: .search, placement: .bottomBar)
                }
            }
        }
        .tint(appearance.getAppColor())
        .fontDesign(appearance.getAppFont())
    }
}

struct ActivityView_Previews: PreviewProvider {
    static var previews: some View {
        ActivityView()
    }
}
