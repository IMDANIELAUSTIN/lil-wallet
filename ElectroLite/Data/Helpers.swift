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
    @AppStorage("appFont") private var appFont = AppFont.rounded
    private var lastAppliedFont: AppFont?
    
    init() {
        updateNavBarTypography()
    }
    
    func getAppColor() -> Color {
        appColor.color
    }
    
    func getAppFont() -> Font.Design {
        appFont.font
    }
    
    func updateNavBarTypography() {
        guard lastAppliedFont != appFont else { return }
        lastAppliedFont = appFont
        
        let titleFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
        let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        
        let descriptor = titleFont.fontDescriptor.withDesign(getUIFontDesign()) ?? titleFont.fontDescriptor
        let largeDescriptor = largeTitleFont.fontDescriptor.withDesign(getUIFontDesign()) ?? largeTitleFont.fontDescriptor
        
        let roundedTitleFont = UIFont(descriptor: descriptor, size: 17)
        let roundedLargeTitleFont = UIFont(descriptor: largeDescriptor, size: 34)
        
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.titleTextAttributes = [.font: roundedTitleFont]
        navBarAppearance.largeTitleTextAttributes = [.font: roundedLargeTitleFont]
        
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }
    
    private func getUIFontDesign() -> UIFontDescriptor.SystemDesign {
        switch appFont {
        case .regular:
            return .default
        case .rounded:
            return .rounded
        case .monospaced:
            return .monospaced
        case .serif:
            return .serif
        }
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
        AsyncImage(
            url: URL(string: imageUrl),
            transaction: SwiftUI.Transaction(animation: .easeInOut(duration: 0.15))
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
            case .failure:
                Color(.secondarySystemBackground)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .aspectRatio(1, contentMode: .fill)
            case .empty:
                Color(.secondarySystemBackground)
                    .aspectRatio(1, contentMode: .fill)
            @unknown default:
                Color(.secondarySystemBackground)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
    }
}
