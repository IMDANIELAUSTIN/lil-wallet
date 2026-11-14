//
//  WalletAboutDetailView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/14/26.
//

import SwiftUI

/// Educational detail screen explaining cryptographic and digital currency topics linked from Settings.
struct WalletAboutDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appearance: Appearance

    enum Topic: String, Identifiable, CaseIterable {
        case cashu
        case nuts
        case bitcoin
        case bitcoinCore
        case stablecoins
        case ethereum

        var id: String { rawValue }

        var title: String {
            switch self {
            case .cashu: return "Learn about Cashu"
            case .nuts: return "Protocol Specs (NUTs)"
            case .bitcoin: return "Learn about Bitcoin"
            case .bitcoinCore: return "Protocol Specs (Bitcoin Core)"
            case .stablecoins: return "Learn about Stablecoins"
            case .ethereum: return "Learn about Ethereum"
            }
        }

        var summary: String {
            switch self {
            case .cashu:
                return "Cashu is a Chaumian eCash protocol built for Bitcoin. Tokens are blind-signed bearer instruments issued by a mint, allowing private, instant transfers over any transport — including offline peer-to-peer relays."
            case .nuts:
                return "Notation, Usage, and Terminology (NUTs) define the open specifications for Cashu wallets and mints: NUT-00 (Cryptography & Models), NUT-03 (Swaps), NUT-04 (Minting), NUT-05 (Melting), and NUT-07 (Token State Check)."
            case .bitcoin:
                return "Bitcoin is a decentralized peer-to-peer monetary network denominated in satoshis (1 BTC = 100,000,000 sats), enabling borderless settlement without centralized intermediaries."
            case .bitcoinCore:
                return "Bitcoin Core is the reference implementation of the Bitcoin protocol, enforcing consensus rules, block validation, script execution, and peer-to-peer transaction relay."
            case .stablecoins:
                return "Stablecoins are digital bearer or account-based assets pegged to fiat reference currencies, enabling low-volatility settlement alongside Bitcoin, Ethereum, and Chaumian eCash."
            case .ethereum:
                return "Ethereum is a programmable blockchain network supporting Ether (ETH) and ERC-compatible tokens and digital objects, powering decentralized applications alongside your ElectroLite portfolio."
            }
        }
    }

    let topic: Topic
    var showsDoneButton: Bool = false

    var body: some View {
        Form {
            Section {
                Text(topic.summary)
                    .font(.system(.body, design: appearance.getAppFont()))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.vertical, 4)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appearance.getAppFont())
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}
