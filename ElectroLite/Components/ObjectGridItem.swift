//
//  ObjectGridItem.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI

struct ObjectGridItem: View {
    @EnvironmentObject var object: OpenSeaAsset
    @EnvironmentObject var appearance: Appearance
    
    var body: some View {
        NavigationLink(destination: ObjectDetailView().environmentObject(object), label: {
            if object.isSVG() {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .foregroundStyle(appearance.getAppColor())
                        .aspectRatio(1, contentMode: .fill)
                    
                    Text(object.name ?? "Untitled")
                        .font(.system(.caption, design: appearance.getAppFont()))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(UIColor.systemBackground))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .lineLimit(3)
                }
            } else {
                ImageView(imageUrl: object.image_url)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .foregroundStyle(Color(UIColor.secondarySystemBackground))
                            .aspectRatio(1, contentMode: .fill)
                    )
            }
        })
    }
}

struct ObjectGridItem_Previews: PreviewProvider {
    static var previews: some View {
        ObjectGridItem()
    }
}
