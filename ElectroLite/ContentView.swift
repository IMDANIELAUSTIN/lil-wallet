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
    @State private var lastNonProminentTab = 0
    @State private var showScanSheet = false
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
                if #available(iOS 27.0, *) {
                    TabView(selection: $activeTab) {
                        Tab(value: 0) {
                            CoinsView()
                                .environmentObject(wallet)
                                .environment(\.managedObjectContext, viewContext)
                        } label: {
                            Label("Home", systemImage: activeTab == 0 ? "house.fill" : "house")
                                .environment(\.symbolVariants, activeTab == 0 ? .fill : .none)
                        }
                        
                        Tab(value: 1, role: .prominent) {
                            if lastNonProminentTab == 2 {
                                ObjectsView()
                                    .environment(\.managedObjectContext, viewContext)
                            } else {
                                CoinsView()
                                    .environmentObject(wallet)
                                    .environment(\.managedObjectContext, viewContext)
                            }
                        } label: {
                            Label("Scan", systemImage: "qrcode")
                                .environment(\.symbolVariants, .none)
                        }
                        
                        Tab(value: 2) {
                            ObjectsView()
                                .environment(\.managedObjectContext, viewContext)
                        } label: {
                            Label("Objects", systemImage: activeTab == 2 ? "shippingbox.fill" : "shippingbox")
                                .environment(\.symbolVariants, activeTab == 2 ? .fill : .none)
                        }
                    }
                    .tint(appearance.getAppColor())
                    .tabBarMinimizeBehavior(.onScrollDown)
                    .background(TabBarConfigurator(activeTab: activeTab))
                } else {
                    TabView(selection: $activeTab) {
                        CoinsView()
                            .environmentObject(wallet)
                            .environment(\.managedObjectContext, viewContext)
                            .tabItem {
                                Image(systemName: activeTab == 0 ? "house.fill" : "house")
                                    .font(.system(size: 20, design: .rounded))
                                    .environment(\.symbolVariants, activeTab == 0 ? .fill : .none)
                                Text("Home")
                            }
                            .tag(0)
                        
                        CoinsView()
                            .environmentObject(wallet)
                            .environment(\.managedObjectContext, viewContext)
                            .tabItem {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 20, design: .rounded))
                                Text("Scan")
                            }
                            .tag(1)
                        
                        ObjectsView()
                            .environment(\.managedObjectContext, viewContext)
                            .tabItem {
                                Image(systemName: activeTab == 2 ? "shippingbox.fill" : "shippingbox")
                                    .font(.system(size: 20, design: .rounded))
                                    .environment(\.symbolVariants, activeTab == 2 ? .fill : .none)
                                Text("Objects")
                            }
                            .tag(2)
                    }
                    .tint(appearance.getAppColor())
                    .background(TabBarConfigurator(activeTab: activeTab))
                }
            }
        }
        .fontDesign(appearance.getAppFont())
        .animation(.easeInOut(duration: 0.16), value: showLaunchScreen())
        .onChange(of: activeTab) { oldValue, newValue in
            if newValue == 1 {
                activeTab = lastNonProminentTab
                showScanSheet = true
            } else {
                lastNonProminentTab = newValue
            }
        }
        .sheet(isPresented: $showScanSheet) {
            ScanQRView()
                .environmentObject(wallet)
                .environmentObject(appearance)
                .environment(\.managedObjectContext, viewContext)
                .tint(appearance.getAppColor())
                .fontDesign(appearance.getAppFont())
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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
    
    final class Coordinator {
        var didMinimizeInitially = false
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private static let symbolConfig: UIImage.SymbolConfiguration = {
        let font = UIFont.systemFont(ofSize: 20, weight: .regular)
        let descriptor = font.fontDescriptor.withDesign(.rounded) ?? font.fontDescriptor
        let roundedFont = UIFont(descriptor: descriptor, size: 20)
        return UIImage.SymbolConfiguration(font: roundedFont)
    }()
    
    private static let houseImage = UIImage(systemName: "house", withConfiguration: symbolConfig)
    private static let houseFillImage = UIImage(systemName: "house.fill", withConfiguration: symbolConfig)
    private static let qrCodeImage = UIImage(systemName: "qrcode", withConfiguration: symbolConfig)
    private static let shippingboxImage = UIImage(systemName: "shippingbox", withConfiguration: symbolConfig)
    private static let shippingboxFillImage = UIImage(systemName: "shippingbox.fill", withConfiguration: symbolConfig)
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let coordinator = context.coordinator
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            self.configureTabBar(from: view, coordinator: coordinator)
        }
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        self.configureTabBar(from: uiView, coordinator: context.coordinator)
    }
    
    private func findTabBar(in root: UIView) -> UITabBar? {
        if let bar = root as? UITabBar { return bar }
        for subview in root.subviews {
            if let bar = findTabBar(in: subview) { return bar }
        }
        return nil
    }
    
    private func findTabBarController(in vc: UIViewController) -> UITabBarController? {
        if let tbc = vc as? UITabBarController { return tbc }
        for child in vc.children {
            if let tbc = findTabBarController(in: child) { return tbc }
        }
        return nil
    }
    
    private func configureTabBar(from view: UIView, coordinator: Coordinator) {
        guard let window = view.window ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }),
            let tabBar = findTabBar(in: window) else {
            return
        }
        
        if #available(iOS 18.0, *),
           let rootVC = window.rootViewController,
           let tbc = findTabBarController(in: rootVC) {
            for tab in tbc.tabs {
                switch tab.title {
                case "Home":
                    tab.image = Self.houseImage
                    if #available(iOS 26.1, *) {
                        tab.selectedImage = Self.houseFillImage
                    }
                case "Objects":
                    tab.image = Self.shippingboxImage
                    if #available(iOS 26.1, *) {
                        tab.selectedImage = Self.shippingboxFillImage
                    }
                case "Scan":
                    tab.image = Self.qrCodeImage
                    if #available(iOS 26.1, *) {
                        tab.selectedImage = Self.qrCodeImage
                    }
                default:
                    break
                }
            }
        }
        
        if let items = tabBar.items {
            for item in items {
                switch item.title {
                case "Home":
                    item.image = Self.houseImage
                    item.selectedImage = Self.houseFillImage
                case "Objects":
                    item.image = Self.shippingboxImage
                    item.selectedImage = Self.shippingboxFillImage
                case "Scan":
                    item.image = Self.qrCodeImage
                    item.selectedImage = Self.qrCodeImage
                default:
                    break
                }
            }
        }
        
        if !coordinator.didMinimizeInitially,
           let vp = tabBar.value(forKey: "_visualProvider") as AnyObject? {
            let sel = Selector(("setMinimized:"))
            if vp.responds(to: sel), let imp = vp.method(for: sel) {
                typealias SetMinFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                unsafeBitCast(imp, to: SetMinFn.self)(vp, sel, true)
                coordinator.didMinimizeInitially = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
