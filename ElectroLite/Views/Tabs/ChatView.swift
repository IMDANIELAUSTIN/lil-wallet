//
//  ChatView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 10/24/26.
//

import SwiftUI
import CoreData

struct PinnedConversation: Identifiable, Hashable {
    let id = UUID()
    var name: String
    
    static let sampleFavorites: [PinnedConversation] = (0..<9).map { _ in
        PinnedConversation(name: "Name")
    }
}

struct ChatView: View {
    @Binding var activeTab: Int
    @Binding var isAtRoot: Bool
    @State private var showActivityView = false
    @State private var showSettingsView = false
    @State private var pinnedConversations: [PinnedConversation] = CommandLine.arguments.contains("-testFavorites") ? PinnedConversation.sampleFavorites : []
    @State private var navigationPath: [ChatCategory] = {
        if CommandLine.arguments.contains("-openCategoryKnownSenders") {
            return [.knownSenders]
        } else if CommandLine.arguments.contains("-openCategoryUnknownSenders") {
            return [.unknownSenders]
        } else if CommandLine.arguments.contains("-openCategoryUnreadChats") {
            return [.unreadChats]
        } else if CommandLine.arguments.contains("-openCategoryArchivedMessages") {
            return [.archivedMessages]
        } else if CommandLine.arguments.contains("-openCategoryAllChats") {
            return [.allChats]
        }
        return []
    }()
    
    init(activeTab: Binding<Int>, isAtRoot: Binding<Bool> = .constant(true)) {
        self._activeTab = activeTab
        self._isAtRoot = isAtRoot
    }
    
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    // Shared conversation threads across categories, Favorites, and Archived Messages
    @State private var threads: [ChatThread] = {
        var list = (0..<4).map { _ in
            ChatThread.sampleThread(contactName: "Contact Name", unreadCount: 3)
        }
        if CommandLine.arguments.contains("-seedArchivedThread") {
            var archived = ChatThread.sampleThread(contactName: "Contact Name", unreadCount: 0)
            archived.isArchived = true
            list.append(archived)
        }
        if CommandLine.arguments.contains("-seedFavoriteThread"), !list.isEmpty {
            list[0].isPinned = true
        }
        return list
    }()
    @State private var allChatsCount = 0
    @State private var knownSendersCount = 0
    @State private var unknownSendersCount = 0
    @State private var unreadChatsCount = 0
    @State private var favoriteThread: ChatThread = ChatThread.sampleThread(contactName: "Contact Name", unreadCount: 3)
    @State private var selectedFavoriteThreadID: UUID?
    @State private var showFavoriteThread = false
    
    private var archivedCount: Int {
        threads.filter { $0.isArchived }.count
    }
    
    private var favoritedThreads: [ChatThread] {
        threads.filter { $0.isPinned && !$0.isArchived }
    }
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    private var currentlyAtRoot: Bool {
        navigationPath.isEmpty && !showFavoriteThread
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        // Favorites Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Favorites")
                                .font(.system(.subheadline, design: appearance.getAppFont()).weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            
                            if !favoritedThreads.isEmpty {
                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(favoritedThreads.prefix(9)) { thread in
                                        Button {
                                            selectedFavoriteThreadID = thread.id
                                            showFavoriteThread = true
                                        } label: {
                                            VStack(spacing: 8) {
                                                CheckeredAvatarPlaceholder(size: 74)
                                                
                                                Text(thread.contactName)
                                                    .font(.system(.subheadline, design: appearance.getAppFont()))
                                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            } else if !pinnedConversations.isEmpty {
                                LazyVGrid(columns: columns, spacing: 18) {
                                    ForEach(pinnedConversations.prefix(9)) { conversation in
                                        Button {
                                            selectedFavoriteThreadID = nil
                                            favoriteThread = ChatThread.sampleThread(contactName: conversation.name, unreadCount: 3)
                                            showFavoriteThread = true
                                        } label: {
                                            VStack(spacing: 8) {
                                                CheckeredAvatarPlaceholder(size: 74)
                                                
                                                Text(conversation.name)
                                                    .font(.system(.subheadline, design: appearance.getAppFont()))
                                                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                                                    .lineLimit(1)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        .padding(.top, 4)
                        
                        // Chats Section
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Chats")
                                .font(.system(.subheadline, design: appearance.getAppFont()).weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 20)
                            
                            // Card 1: Main Categories
                            VStack(spacing: 0) {
                                chatCategoryRow(
                                    category: .allChats,
                                    count: allChatsCount
                                )
                                
                                rowDivider
                                
                                chatCategoryRow(
                                    category: .knownSenders,
                                    count: knownSendersCount
                                )
                                
                                rowDivider
                                
                                chatCategoryRow(
                                    category: .unknownSenders,
                                    count: unknownSendersCount
                                )
                                
                                rowDivider
                                
                                chatCategoryRow(
                                    category: .unreadChats,
                                    count: unreadChatsCount
                                )
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .padding(.horizontal, 16)
                            
                            // Card 2: Archived Messages
                            VStack(spacing: 0) {
                                chatCategoryRow(
                                    category: .archivedMessages,
                                    count: archivedCount
                                )
                            }
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .padding(.horizontal, 16)
                            .padding(.top, 6)
                        }
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Chat")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ChatCategory.self) { category in
                ChatCategoryListView(category: category, threads: $threads)
                    .environmentObject(wallet)
                    .environmentObject(appearance)
                    .environment(\.managedObjectContext, viewContext)
            }
            .navigationDestination(isPresented: $showFavoriteThread) {
                if let id = selectedFavoriteThreadID, let index = threads.firstIndex(where: { $0.id == id }) {
                    ChatDetailView(thread: $threads[index], totalUnreadCount: 3)
                        .environmentObject(wallet)
                        .environmentObject(appearance)
                        .environment(\.managedObjectContext, viewContext)
                } else {
                    ChatDetailView(thread: $favoriteThread, totalUnreadCount: 3)
                        .environmentObject(wallet)
                        .environmentObject(appearance)
                        .environment(\.managedObjectContext, viewContext)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showActivityView.toggle()
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.headline)
                            .foregroundStyle(Color.appPrimary)
                    }
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
                    Button {
                        showSettingsView.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .font(.headline)
                            .foregroundStyle(Color.appPrimary)
                    }
                    .sheet(isPresented: $showSettingsView) {
                        SettingsView(showSettingsView: $showSettingsView)
                            .environmentObject(wallet)
                            .environmentObject(appearance)
                            .environment(\.managedObjectContext, viewContext)
                    }
                }
            }
        }
        .fontDesign(appearance.getAppFont())
        .onAppear {
            isAtRoot = currentlyAtRoot
        }
        .onChange(of: currentlyAtRoot) { _, newValue in
            isAtRoot = newValue
        }
    }
    
    private var rowDivider: some View {
        Divider()
            .padding(.leading, 56)
    }
    
    @ViewBuilder
    private func chatCategoryRow(
        category: ChatCategory,
        count: Int
    ) -> some View {
        NavigationLink(value: category) {
            HStack(spacing: 14) {
                Image(systemName: category.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(category.iconColor)
                    .frame(width: 30, height: 30)
                
                Text(category.rawValue)
                    .font(.system(.body, design: appearance.getAppFont()))
                    .foregroundStyle(Color.appPrimary)
                
                Spacer()
                
                Text("\(count)")
                    .font(.system(.body, design: appearance.getAppFont()))
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold, design: appearance.getAppFont()))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avatar Placeholder
struct CheckeredAvatarPlaceholder: View {
    var size: CGFloat = 74
    
    var body: some View {
        Canvas { context, canvasSize in
            let tileSize: CGFloat = 7
            let cols = Int(ceil(canvasSize.width / tileSize))
            let rows = Int(ceil(canvasSize.height / tileSize))
            
            for r in 0..<rows {
                for c in 0..<cols {
                    let isEven = (r + c) % 2 == 0
                    let color = isEven
                        ? Color(uiColor: .systemGray5)
                        : Color(uiColor: .systemGray4).opacity(0.7)
                    let rect = CGRect(
                        x: CGFloat(c) * tileSize,
                        y: CGFloat(r) * tileSize,
                        width: tileSize,
                        height: tileSize
                    )
                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(Color(uiColor: .separator).opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(activeTab: .constant(2))
            .environmentObject(Wallet())
            .environmentObject(Appearance())
    }
}
