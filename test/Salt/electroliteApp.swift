//
//  electroliteApp.swift
//  Salt
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

@main
struct SaltApp: App {
    @StateObject private var appearance = Appearance()
    @StateObject private var wallet = Wallet()
    @StateObject private var mediaPlayer = MediaPlayerManager()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wallet)
                .environmentObject(appearance)
                .environmentObject(mediaPlayer)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
