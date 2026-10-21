//
//  ContentView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @State var activeTab = 0
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @State private var timeRemaining = 3
    
    var body: some View {
        ZStack {
            if showLaunchScreen() {
                // loading view
                VStack {
                    Spacer()
                    Text(Image(systemName: "square.on.circle"))
                        .font(.system(size: 56, weight: .medium, design: .rounded))
                        .foregroundStyle(appearance.getAppColor())
                    Spacer()
                }
            } else {
                TabView(selection: $activeTab) {
                    CoinsView()
                        .environmentObject(wallet)
                        .environment(\.managedObjectContext, viewContext)
                        .tabItem {
                            Image(systemName: activeTab == 0 ? "banknote.fill" : "banknote")
                                .font(.system(size: 20, design: .rounded))
                                .environment(\.symbolVariants, activeTab == 0 ? .fill : .none)
                            Text("Money")
                        }
                        .tag(0)
                    
                    ObjectsView()
                        .environment(\.managedObjectContext, viewContext)
                        .tabItem {
                            Image(systemName: activeTab == 1 ? "shippingbox.fill" : "shippingbox")
                                .font(.system(size: 20, design: .rounded))
                                .environment(\.symbolVariants, activeTab == 1 ? .fill : .none)
                            Text("Objects")
                        }
                        .tag(1)
                }
                .tint(appearance.getAppColor())
                .background(TabBarConfigurator(activeTab: activeTab))
            }
        }
        .fontDesign(appearance.getAppFont())
        .animation(.easeInOut(duration: 0.16), value: showLaunchScreen())
        .onAppear {
            appearance.updateNavBarTypography()
        }
        .task {
            try? await Task.sleep(for: .seconds(3))
            self.timeRemaining = 0
        }
    }
    
    func showLaunchScreen() -> Bool {
        // show launch screen if we're waiting for portfolio/tokens, OR if timer is at 0
        return (wallet.loadingPortfolio || wallet.loadingTokens) && self.timeRemaining > 0
    }
}

private struct TabBarConfigurator: UIViewRepresentable {
    var activeTab: Int
    
    private static let symbolConfig: UIImage.SymbolConfiguration = {
        let font = UIFont.systemFont(ofSize: 20, weight: .regular)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        let roundedFont = UIFont(descriptor: descriptor, size: 20)
        return UIImage.SymbolConfiguration(font: roundedFont)
    }()
    
    private static let banknoteImage = UIImage(systemName: "banknote", withConfiguration: symbolConfig)
    private static let banknoteFillImage = UIImage(systemName: "banknote.fill", withConfiguration: symbolConfig)
    private static let shippingboxImage = UIImage(systemName: "shippingbox", withConfiguration: symbolConfig)
    private static let shippingboxFillImage = UIImage(systemName: "shippingbox.fill", withConfiguration: symbolConfig)
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            self.configureTabBar(from: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        self.configureTabBar(from: uiView)
    }
    
    private func findTabBar(in root: UIView) -> UITabBar? {
        if let bar = root as? UITabBar { return bar }
        for subview in root.subviews {
            if let bar = findTabBar(in: subview) { return bar }
        }
        return nil
    }
    
    private func configureTabBar(from view: UIView) {
        guard let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
            let tabBar = findTabBar(in: window) else {
            return
        }
        
        if let items = tabBar.items, items.count >= 2 {
            if items[0].image !== Self.banknoteImage {
                items[0].image = Self.banknoteImage
                items[0].selectedImage = Self.banknoteFillImage
                items[1].image = Self.shippingboxImage
                items[1].selectedImage = Self.shippingboxFillImage
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
