//
//  Helpers.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/29/21.
//

import SwiftUI
import Combine
import CoreText

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
    
    func getBalanceFont(size: CGFloat = 34, weight: UIFont.Weight = .bold) -> Font {
        let baseFont = UIFont.systemFont(ofSize: size, weight: weight)
        let descriptor = baseFont.fontDescriptor.withDesign(getUIFontDesign()) ?? baseFont.fontDescriptor
        
        let featureSettings: [[UIFontDescriptor.FeatureKey: Any]] = [
            [UIFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String): "cv09",
             UIFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureValue as String): 1],
            [UIFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureTag as String): "cv10",
             UIFontDescriptor.FeatureKey(rawValue: kCTFontOpenTypeFeatureValue as String): 1]
        ]
        
        let variantDescriptor = descriptor.addingAttributes([
            .featureSettings: featureSettings
        ])
        
        let uiFont = UIFont(descriptor: variantDescriptor, size: size)
        return Font(uiFont)
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
        navBarAppearance.titleTextAttributes = [
            .font: roundedTitleFont,
            .foregroundColor: UIColor.appPrimary
        ]
        navBarAppearance.largeTitleTextAttributes = [
            .font: roundedLargeTitleFont,
            .foregroundColor: UIColor.appPrimary
        ]
        
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

extension UIColor {
    static let appPrimary = UIColor { traitCollection in
        switch traitCollection.userInterfaceStyle {
        case .dark:
            return UIColor(red: 0xF6 / 255.0, green: 0xF5 / 255.0, blue: 0xF3 / 255.0, alpha: 1.0)
        default:
            return UIColor(red: 0x29 / 255.0, green: 0x0B / 255.0, blue: 0x00 / 255.0, alpha: 1.0)
        }
    }
}

extension Color {
    static let appPrimary = Color(uiColor: .appPrimary)
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
            return Color.appPrimary
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
                Color(.secondarySystemGroupedBackground)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                    .aspectRatio(1, contentMode: .fill)
            case .empty:
                Color(.secondarySystemGroupedBackground)
                    .aspectRatio(1, contentMode: .fill)
            @unknown default:
                Color(.secondarySystemGroupedBackground)
                    .aspectRatio(1, contentMode: .fill)
            }
        }
    }
}
