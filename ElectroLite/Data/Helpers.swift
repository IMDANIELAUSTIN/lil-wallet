//
//  Helpers.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/29/21.
//

import SwiftUI
import Combine

@MainActor
class Appearance: ObservableObject {
    @AppStorage("appColor") private var appColor = AppColor.monochrome
    @AppStorage("appFont") private var appFont = AppFont.regular
    
    func getAppColor() -> Color {
        appColor.color
    }
    
    func getAppFont() -> Font.Design {
        appFont.font
    }
}

enum AppColor: String, Hashable, CaseIterable, Sendable {
    case monochrome
    case red
    case orange
    case yellow
    case green
    case blue
    case indigo
    case purple
    
    var color: Color {
        switch self {
        case .monochrome:
            return Color.primary
        case .red:
            return Color.red
        case .orange:
            return Color.orange
        case .yellow:
            return Color.yellow
        case .green:
            return Color.green
        case .blue:
            return Color.blue
        case .indigo:
            return Color.indigo
        case .purple:
            return Color.purple
        }
    }
}

enum AppFont: String, Hashable, CaseIterable, Sendable {
    case regular
    case rounded
    case monospaced
    case serif
    
    var font: Font.Design {
        switch self {
        case .regular:
            return Font.Design.default
        case .rounded:
            return Font.Design.rounded
        case .monospaced:
            return Font.Design.monospaced
        case .serif:
            return Font.Design.serif
        }
    }
}

struct ImageView: View {
    let imageUrl: String
    
    init(imageUrl: String) {
        self.imageUrl = imageUrl
    }
    
    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            case .failure:
                Color(UIColor.secondarySystemBackground)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .aspectRatio(1, contentMode: .fill)
            case .empty:
                Color(UIColor.secondarySystemBackground)
                    .aspectRatio(1, contentMode: .fill)
            @unknown default:
                Color(UIColor.secondarySystemBackground)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
    }
}
