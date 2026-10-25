//
//  NewChatView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 10/25/26.
//

import SwiftUI

struct NewChatView: View {
    @Binding var isPresented: Bool
    @State private var recipientText: String = ""
    @State private var messageText: String = ""
    
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.dismiss) private var dismiss
    
    init(isPresented: Binding<Bool> = .constant(true)) {
        self._isPresented = isPresented
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header: Cancel button (leading) & Centered "New Chat" title
                ZStack {
                    HStack {
                        Button {
                            isPresented = false
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .font(.system(.subheadline, design: appearance.getAppFont()).weight(.medium))
                                .foregroundStyle(Color.appPrimary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .overlay(
                                    Capsule()
                                        .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Spacer()
                    }
                    
                    Text("New Chat")
                        .font(.system(.headline, design: appearance.getAppFont()).weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)
                
                // "To:" Recipient Field Row
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Text("To:")
                            .font(.system(.subheadline, design: appearance.getAppFont()))
                            .foregroundStyle(.secondary)
                        
                        TextField("", text: $recipientText)
                            .font(.system(.body, design: appearance.getAppFont()))
                            .foregroundStyle(Color.appPrimary)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .overlay(
                        Capsule()
                            .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                    )
                    
                    Button {
                        // Contact picker action
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold, design: appearance.getAppFont()))
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                
                // Content area
                Spacer()
                
                // Bottom Message Input Bar
                HStack(spacing: 12) {
                    Button {
                        // Attachment / additional options action
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold, design: appearance.getAppFont()))
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle()
                                    .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 8) {
                        TextField("Message", text: $messageText)
                            .font(.system(.body, design: appearance.getAppFont()))
                            .foregroundStyle(Color.appPrimary)
                        
                        Button {
                            // Audio / waveform action
                        } label: {
                            Image(systemName: "waveform")
                                .font(.system(size: 18, weight: .medium, design: appearance.getAppFont()))
                                .foregroundStyle(Color.appPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 42)
                    .overlay(
                        Capsule()
                            .stroke(Color(uiColor: .systemGray4), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .fontDesign(appearance.getAppFont())
    }
}

struct NewChatView_Previews: PreviewProvider {
    static var previews: some View {
        NewChatView()
            .environmentObject(Wallet())
            .environmentObject(Appearance())
    }
}
