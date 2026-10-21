//
//  AddWalletView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 11/28/21.
//

import SwiftUI
import CoreData

struct AddWalletView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    enum Field: Hashable {
        case name
        case address
    }
    @State var name = ""
    @State var address = ""
    @FocusState private var focusedField: Field?
    @AppStorage("currentWalletAddress") private var currentWalletAddress: String = ""
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WalletAddress.createdAt, ascending: true)],
        animation: .default)
    private var wallets: FetchedResults<WalletAddress>
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @State var loading = false
    @State var showAlert = false
    
    private static let wellKnownENS: [String: String] = [
        "vitalik.eth": "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
        "jsngr.eth": "0x277BFc4a8dc79a9F194AD4a83468484046FAFD3A",
        "nick.eth": "0xb8c2C29ee19D8307cb7255e1Cd9CbDE883A267d5",
        "brantly.eth": "0x983110309620D911731Ac0932219af06091b6744"
    ]
    
    var body: some View {
        Form {
            Section(content: {
                TextField("Name", text: $name)
                    .focused($focusedField, equals: .name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.next)
                
                TextField("Address", text: $address)
                    .focused($focusedField, equals: .address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
            }, footer: {
                Text("Ethereum address or ENS name")
            })
        }
        .font(.system(.body, design: appearance.getAppFont()))
        .toolbar(content: {
            ToolbarItem {
                Button(action: saveWallet, label: {
                    if self.loading {
                        ProgressView()
                    } else {
                        Text("Save")
                            .font(.system(.headline, design: appearance.getAppFont()))
                    }
                })
                .disabled(!isValid() || self.loading)
                .alert("Failed to load wallet", isPresented: $showAlert) {
                    Button("OK", role: .cancel) { }
                }
            }
        })
        .navigationTitle("Add Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .fontDesign(appearance.getAppFont())
        .onAppear(perform: { autofocus() })
    }
    
    func autofocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            self.focusedField = .name
        }
    }
    
    func isValid() -> Bool {
        let trimmed = self.address.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return !trimmed.isEmpty && (trimmed.hasPrefix("0x") || trimmed.hasSuffix(".eth"))
    }
    
    private func saveWallet() {
        let trimmed = self.address.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasSuffix(".eth") {
            // address contains .eth, do reverse lookup
            reverseENSLookup(ensName: trimmed.lowercased())
        } else {
            addWallet(address: trimmed)
        }
    }
    
    private func addWallet(address: String) {
        let newWallet = WalletAddress(context: viewContext)
        newWallet.createdAt = Date()
        let trimmedName = self.name.trimmingCharacters(in: .whitespacesAndNewlines)
        newWallet.name = trimmedName.isEmpty ? (self.address.lowercased().hasSuffix(".eth") ? self.address : nil) : trimmedName
        newWallet.address = address
        
        if wallets.count == 0 {
            // set to active wallet if it's the first one
            self.currentWalletAddress = address
            wallet.reload(reset: true, refresh: false)
        }

        do {
            try viewContext.save()
            dismiss()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func reverseENSLookup(ensName: String) {
        self.loading = true
        
        if let known = Self.wellKnownENS[ensName.lowercased()] {
            self.loading = false
            self.addWallet(address: known)
            return
        }
        
        let encodedName = ensName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ensName
        guard let url = URL(string: "https://api.ensdata.net/\(encodedName)") else {
            self.loading = false
            self.showAlert = true
            return
        }
                
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        
        Task { @MainActor in
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let decodedResponse = try? JSONDecoder().decode(ReverseENSLookupResponse.self, from: data),
               !decodedResponse.address.isEmpty {
                self.loading = false
                self.addWallet(address: decodedResponse.address)
            } else {
                self.loading = false
                self.showAlert = true
            }
        }
    }
}

struct AddWalletView_Previews: PreviewProvider {
    static var previews: some View {
        AddWalletView()
    }
}
