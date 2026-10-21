//
//  ActivityListItem.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct ActivityListItem: View {
    @EnvironmentObject var appearance: Appearance
    @EnvironmentObject var wallet: Wallet
    let transaction: Transaction
    
    var body: some View {
        let appFont = appearance.getAppFont()
        
        NavigationLink(destination: ActivityDetailView(transaction: transaction), label: {
            HStack(alignment: .center, spacing: 12) {
                AvatarView(text: transaction.token == nil ? transaction.type : transaction.token?.name ?? "", iconURL: transaction.token?.iconURL ?? nil)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(transaction.title())
                            .lineLimit(1)
                            .font(.system(.headline, design: appFont))
                        
                        Spacer()
                        
                        Text("\(wallet.formatCurrency(value: transaction.transactionValue()))")
                            .font(.system(.callout, design: appFont))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(Date(timeIntervalSince1970: TimeInterval(transaction.mined_at)).formatted(date: .abbreviated, time: .omitted))
                        .lineLimit(1)
                        .font(.system(.body, design: appFont))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 10)
        })
    }
}

struct ActivityListItem_Previews: PreviewProvider {
    static var previews: some View {
        ActivityListItem(transaction: Transaction(id: "tx-1", token: nil, value: 0, price: 0, type: "receive", mined_at: 0, hash: "", status: "confirmed", block_number: 0, address_from: nil, address_to: nil, fee: nil))
    }
}
