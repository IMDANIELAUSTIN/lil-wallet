//
//  ScanQRView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 10/22/26.
//

import SwiftUI
import CoreData
import CoreImage.CIFilterBuiltins

struct ScanQRView: View {
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var selectedMode: ScanMode = .scan
    @State private var isTorchOn = false
    @State private var copiedAddress = false
    @State private var showActivityView = false
    @State private var showSettingsView = false
    
    enum ScanMode: String, CaseIterable, Identifiable {
        case scan = "Scan"
        case receive = "My Code"
        var id: String { rawValue }
    }
    
    private var displayAddress: String {
        wallet.currentWalletAddress.isEmpty ? "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045" : wallet.currentWalletAddress
    }
    
    private var shortenedAddress: String {
        let addr = displayAddress
        guard addr.count > 10 else { return addr }
        return "\(addr.prefix(6))...\(addr.suffix(4))"
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 28) {
                    Picker("Mode", selection: $selectedMode) {
                        ForEach(ScanMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    
                    Spacer()
                    
                    if selectedMode == .scan {
                        scanViewfinder
                    } else {
                        receiveQRCard
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle(selectedMode == .scan ? "Scan QR" : "Receive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showActivityView.toggle() }, label: { Image(systemName: "magnifyingglass").font(.headline) })
                        .sheet(isPresented: $showActivityView) {
                            ActivityView()
                                .environmentObject(wallet)
                                .environmentObject(appearance)
                        }
                }
                
                if #available(iOS 26.0, *) {
                    ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsView.toggle() }, label: { Image(systemName: "gear").font(.headline) })
                        .sheet(isPresented: $showSettingsView) {
                            SettingsView(showSettingsView: $showSettingsView)
                                .environmentObject(wallet)
                                .environmentObject(appearance)
                                .environment(\.managedObjectContext, viewContext)
                        }
                }
            }
        }
    }
    
    private var scanViewfinder: some View {
        VStack(spacing: 28) {
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    .frame(width: 260, height: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(appearance.getAppColor().opacity(0.35), style: StrokeStyle(lineWidth: 2.5, dash: [14, 10]))
                    )
                
                VStack(spacing: 14) {
                    Image(systemName: "qrcode.viewfinder")
                        .font(.system(size: 72, weight: .regular, design: appearance.getAppFont()))
                        .foregroundStyle(appearance.getAppColor())
                    
                    Text("Align QR code inside frame")
                        .font(.system(.subheadline, design: appearance.getAppFont()))
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(spacing: 8) {
                Text("Scan to Send or Connect")
                    .font(.system(.title3, design: appearance.getAppFont()).weight(.semibold))
                
                Text("Scan an Ethereum wallet address or WalletConnect QR code.")
                    .font(.system(.subheadline, design: appearance.getAppFont()))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            HStack(spacing: 16) {
                Button {
                    isTorchOn.toggle()
                } label: {
                    Label(isTorchOn ? "Light On" : "Light", systemImage: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(.subheadline, design: appearance.getAppFont()).weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                
                Button {
                    if let pasted = UIPasteboard.general.string, !pasted.isEmpty {
                        wallet.currentWalletAddress = pasted
                    }
                } label: {
                    Label("Paste Address", systemImage: "doc.on.clipboard")
                        .font(.system(.subheadline, design: appearance.getAppFont()).weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
            }
        }
    }
    
    private var receiveQRCard: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                if let qrImage = generateQRCode(from: displayAddress) {
                    Image(uiImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                        .padding(20)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                
                Text(shortenedAddress)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding(24)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            
            HStack(spacing: 16) {
                Button {
                    UIPasteboard.general.string = displayAddress
                    copiedAddress = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copiedAddress = false
                    }
                } label: {
                    Label(copiedAddress ? "Copied" : "Copy Address", systemImage: copiedAddress ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(.subheadline, design: appearance.getAppFont()).weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
                
                ShareLink(item: displayAddress) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.system(.subheadline, design: appearance.getAppFont()).weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .clipShape(Capsule())
            }
        }
    }
    
    private func generateQRCode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
