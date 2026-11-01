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
    @Binding var threads: [ChatThread]
    @State private var showNewChatSheet = CommandLine.arguments.contains("-openNewChatSheet")
    @State private var navigateToDetail = CommandLine.arguments.contains("-openChatDetail")
    @State private var selectedThreadID: UUID?
    @State private var defaultDetailThread: ChatThread = ChatThread.sampleThread(contactName: "Contact Name", unreadCount: 3)
    
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    init(category: ChatCategory, threads: Binding<[ChatThread]>? = nil) {
        self.category = category
        if let threads {
            self._threads = threads
        } else {
            self._threads = .constant((0..<4).map { _ in
                ChatThread.sampleThread(contactName: "Contact Name", unreadCount: 3)
            })
        }
    }
    
    private var visibleThreads: [ChatThread] {
        switch category {
        case .archivedMessages:
            return threads.filter { $0.isArchived }
        case .allChats:
            return threads.filter { !$0.isArchived }
        case .knownSenders:
            return threads.filter { !$0.isArchived && $0.isKnownSender }
        case .unknownSenders:
            return threads.filter { !$0.isArchived && !$0.isKnownSender }
        case .unreadChats:
            return threads.filter { !$0.isArchived && $0.unreadCount > 0 }
        }
    }
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
            
            List {
                // Header Title & Subtitle
                VStack(alignment: .leading, spacing: 4) {
                    Text(category.rawValue)
                        .font(.system(size: 32, weight: .bold, design: appearance.getAppFont()))
                        .foregroundStyle(Color.appPrimary)
                    
                    Text("Updated Just Now")
                        .font(.system(.subheadline, design: appearance.getAppFont()))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 24, trailing: 20))
                
                // Conversation rows with native swipe actions
                ForEach(visibleThreads) { chat in
                    Button {
                        selectedThreadID = chat.id
                        navigateToDetail = true
                    } label: {
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                CheckeredAvatarPlaceholder(size: 50)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(chat.contactName)
                                            .font(.system(.headline, design: appearance.getAppFont()).weight(.semibold))
                                            .foregroundStyle(Color.appPrimary)
                                        
                                        if chat.isPinned {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.yellow)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(chat.timestamp)
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
                            
                            Divider()
                                .padding(.leading, 84)
                                .padding(.trailing, 20)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if category == .archivedMessages {
                            Button(role: .destructive) {
                                deleteThread(id: chat.id)
                            } label: {
                                Label("Delete", systemImage: "trash.fill")
                            }
                            .tint(.red)
                        } else {
                            Button {
                                archiveThread(id: chat.id)
                            } label: {
                                Label("Archive", systemImage: "archivebox.fill")
                            }
                            .tint(.indigo)
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if category == .allChats {
                            Button {
                                toggleFavorite(id: chat.id)
                            } label: {
                                Label(
                                    chat.isPinned ? "Unfavorite" : "Favorite",
                                    systemImage: chat.isPinned ? "star.slash.fill" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .navigationDestination(isPresented: $navigateToDetail) {
            if let id = selectedThreadID, let index = threads.firstIndex(where: { $0.id == id }) {
                ChatDetailView(thread: $threads[index], totalUnreadCount: 3)
                    .environmentObject(wallet)
                    .environmentObject(appearance)
                    .environment(\.managedObjectContext, viewContext)
            } else {
                ChatDetailView(thread: $defaultDetailThread, totalUnreadCount: 3)
                    .environmentObject(wallet)
                    .environmentObject(appearance)
                    .environment(\.managedObjectContext, viewContext)
            }
        }
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
    
    private func archiveThread(id: UUID) {
        withAnimation {
            if let index = threads.firstIndex(where: { $0.id == id }) {
                threads[index].isArchived = true
                threads[index].isPinned = false
            }
        }
    }
    
    private func deleteThread(id: UUID) {
        withAnimation {
            threads.removeAll { $0.id == id }
        }
    }
    
    private func toggleFavorite(id: UUID) {
        withAnimation {
            guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
            if threads[index].isPinned {
                threads[index].isPinned = false
            } else {
                let currentFavoritesCount = threads.filter { $0.isPinned && !$0.isArchived }.count
                if currentFavoritesCount < 9 {
                    threads[index].isPinned = true
                }
            }
        }
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
