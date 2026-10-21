//
//  ObjectGridItem.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct ObjectGridItem: View {
    @EnvironmentObject var appearance: Appearance
    let object: OpenSeaAsset
    
    var body: some View {
        NavigationLink(destination: ObjectDetailView(object: object), label: {
            if object.isSVG() {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .foregroundStyle(appearance.getAppColor())
                        .aspectRatio(1, contentMode: .fill)
                    
                    Text(object.name ?? "Untitled")
                        .font(.system(.caption, design: appearance.getAppFont()))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(.systemBackground))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(3)
                }
            } else {
                ImageView(imageUrl: object.image_url)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .foregroundStyle(Color(.secondarySystemBackground))
                            .aspectRatio(1, contentMode: .fill)
                    )
            }
        })
    }
}

struct ObjectGridItem_Previews: PreviewProvider {
    static var previews: some View {
        ObjectGridItem(object: Wallet.demoObjects()[0])
    }
}
