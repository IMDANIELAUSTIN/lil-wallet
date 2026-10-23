//
//  CryptoListItem.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct CryptoListItem: View {
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    let token: Token
    
    var body: some View {
        let appFont = appearance.getAppFont()
        
        NavigationLink(destination: CryptoDetailView(token: token), label: {
            HStack(alignment: .center, spacing: 12) {
                AvatarView(text: token.name, iconURL: token.iconURL)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(token.name == "" ? "Untitled" : token.name)
                            .lineLimit(1)
                            .font(.system(.headline, design: appFont))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(token.percentChange())
                            .font(.system(.callout, design: appFont))
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("\(wallet.formatCurrency(value: token.value()))")
                        .font(.system(.body, design: appFont))
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold, design: appFont))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        })
        .buttonStyle(.plain)
    }
}

struct CurrencyListItem_Previews: PreviewProvider {
    static var previews: some View {
        CryptoListItem(token: Token(id: "eth", name: "Ethereum", symbol: "ETH", quantity: "1000000000000000000", price: Price(value: 2650, relative_change: 2.45), iconURL: nil))
    }
}
