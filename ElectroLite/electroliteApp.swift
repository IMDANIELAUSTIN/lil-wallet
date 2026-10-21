//
//  electroliteApp.swift
//  ElectroLite
//
//  Created by Jordan Singer on 11/28/21.
//

import SwiftUI
import CoreData

@main
struct ElectroLiteApp: App {
    @StateObject private var appearance = Appearance()
    @StateObject private var wallet = Wallet()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wallet)
                .environmentObject(appearance)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
