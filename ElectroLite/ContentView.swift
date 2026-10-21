//
//  ContentView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData
import Combine

struct ContentView: View {
    @State var activeTab = 0
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @State private var timeRemaining = 3
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
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
        .onReceive(timer) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 1
            }
        }
    }
    
    func showLaunchScreen() -> Bool {
        // show launch screen if we're waiting for portfolio/tokens, OR if timer is at 0
        return (wallet.loadingPortfolio || wallet.loadingTokens) && self.timeRemaining > 0
    }
}

private struct TabBarConfigurator: UIViewRepresentable {
    var activeTab: Int
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.configureTabBar(from: view)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.configureTabBar(from: uiView)
        }
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
        
        let font = UIFont.systemFont(ofSize: 20, weight: .regular)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        let roundedFont = UIFont(descriptor: descriptor, size: 20)
        let config = UIImage.SymbolConfiguration(font: roundedFont)
        
        if let items = tabBar.items, items.count >= 2 {
            items[0].image = UIImage(systemName: "banknote", withConfiguration: config)
            items[0].selectedImage = UIImage(systemName: "banknote.fill", withConfiguration: config)
            
            items[1].image = UIImage(systemName: "shippingbox", withConfiguration: config)
            items[1].selectedImage = UIImage(systemName: "shippingbox.fill", withConfiguration: config)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
