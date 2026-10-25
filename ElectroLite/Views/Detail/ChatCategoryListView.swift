//
//  ChatCategoryListView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 10/24/26.
//

import SwiftUI
import CoreData

enum ChatCategory: String, CaseIterable, Identifiable, Hashable {
    case allChats = "All Chats"
    case knownSenders = "Known Senders"
    case unknownSenders = "Unknown Senders"
    case unreadChats = "Unread Chats"
    case archivedMessages = "Archived Messages"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .allChats: return "message.fill"
        case .knownSenders: return "person.crop.circle.fill"
        case .unknownSenders: return "person.crop.circle.badge.questionmark.fill"
        case .unreadChats: return "message.badge.filled.fill"
        case .archivedMessages: return "trash.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .archivedMessages: return .red
        default: return .blue
        }
    }
}

struct ChatMessagePreview: Identifiable, Hashable {
    let id = UUID()
    var contactName: String
    var lastMessage: String
    var dateString: String
    
    static let sampleList: [ChatMessagePreview] = (0..<4).map { _ in
        ChatMessagePreview(
            contactName: "Contact Name",
            lastMessage: "First line of chat message . . .",
            dateString: "00/00/00"
        )
    }
}

struct ChatCategoryListView: View {
    let category: ChatCategory
    @State private var showNewChatSheet = CommandLine.arguments.contains("-openNewChatSheet")
    @State private var messages: [ChatMessagePreview] = ChatMessagePreview.sampleList
    
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header Title & Subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.rawValue)
                            .font(.system(size: 32, weight: .bold, design: appearance.getAppFont()))
                            .foregroundStyle(Color.appPrimary)
                        
                        Text("Updated Just Now")
                            .font(.system(.subheadline, design: appearance.getAppFont()))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    
                    // List of chat conversations
                    LazyVStack(spacing: 0) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, chat in
                            Button {
                                // Navigation to individual chat message view will be wired in upcoming milestone
                            } label: {
                                HStack(spacing: 14) {
                                    CheckeredAvatarPlaceholder(size: 50)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(chat.contactName)
                                                .font(.system(.headline, design: appearance.getAppFont()).weight(.semibold))
                                                .foregroundStyle(Color.appPrimary)
                                            
                                            Spacer()
                                            
                                            Text(chat.dateString)
                                                .font(.system(.subheadline, design: appearance.getAppFont()))
                                                .foregroundStyle(.secondary)
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 13, weight: .semibold, design: appearance.getAppFont()))
                                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                        }
                                        
                                        Text(chat.lastMessage)
                                            .font(.system(.subheadline, design: appearance.getAppFont()))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            
                            Divider()
                                .padding(.leading, 84)
                                .padding(.trailing, 20)
                        }
                    }
                }
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold, design: appearance.getAppFont()))
                        .foregroundStyle(Color.appPrimary)
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showNewChatSheet.toggle()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold, design: appearance.getAppFont()))
                        .foregroundStyle(Color.appPrimary)
                }
                .sheet(isPresented: $showNewChatSheet) {
                    NewChatView(isPresented: $showNewChatSheet)
                        .environmentObject(wallet)
                        .environmentObject(appearance)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
        .fontDesign(appearance.getAppFont())
    }
}

struct ChatCategoryListView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChatCategoryListView(category: .allChats)
                .environmentObject(Wallet())
                .environmentObject(Appearance())
        }
    }
}
