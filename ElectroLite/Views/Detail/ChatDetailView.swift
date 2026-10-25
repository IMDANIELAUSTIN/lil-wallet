//
//  ChatDetailView.swift
//  ElectroLite
//
//  Created by Daniel Lee Austin on 10/25/26.
//

import SwiftUI
import UIKit
import LinkPresentation
import AVFoundation

// MARK: - Chromatic Palette & Transport Colors
let imessageBlue = Color(red: 0x14/255, green: 0x7E/255, blue: 0xFB/255) // #147EFB
let bluetoothRed = Color(red: 0xFC/255, green: 0x3D/255, blue: 0x39/255) // #FC3D39

enum MessageTransport: String, CaseIterable, Identifiable, Codable {
    case p2p = "P2P"
    case bluetoothMesh = "Bluetooth Mesh"
    case meshCore = "MeshCore"
    case meshtastic = "Meshtastic"
    case walkieTalkie = "Walkie-Talkie"
    
    var id: String { rawValue }
    
    var bubbleColor: Color {
        switch self {
        case .p2p:
            return imessageBlue
        case .bluetoothMesh:
            return bluetoothRed
        case .meshCore:
            return Color.purple
        case .meshtastic:
            return Color.orange
        case .walkieTalkie:
            return Color.cyan
        }
    }
    
    var iconName: String {
        switch self {
        case .bluetoothMesh:
            return "antenna.radiowaves.left.and.right"
        default:
            return "lock.fill"
        }
    }
}

enum DeliveryStatus: Equatable {
    case failed
    case sending
    case sent
    case delivered
    case seen(Date)
}

struct ChatMediaItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    var systemIcon: String
    var gradientColors: [Color]
    var caption: String? = nil
}

struct VoiceMemoData: Equatable {
    var duration: TimeInterval
    var waveformLevels: [Float] // 36 normalized values (0.05 ... 1.0)
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    var text: String
    var isSender: Bool
    var timestamp: Date
    var transport: MessageTransport
    var deliveryStatus: DeliveryStatus? = nil
    var isDeleted: Bool = false
    var isThinking: Bool = false
    var scheduledSendDate: Date? = nil
    var sendBatchID: UUID? = nil
    var mediaItems: [ChatMediaItem] = []
    var voiceMemo: VoiceMemoData? = nil
    var reactions: [String] = []
    var userReaction: String? = nil
    var linkURL: URL? = nil
    
    var isBatchLeader: Bool = true
}

// MARK: - Swipe Back Gesture Restorer & Modern Liquid Glass Modifiers
struct SwipeBackGestureRestorer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            vc.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    func restoresSwipeBackGesture() -> some View {
        self.background(SwipeBackGestureRestorer())
    }
    
    @ViewBuilder
    func liquidGlassEffect() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
        }
    }
    
    @ViewBuilder
    func chatBottomSafeAreaBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            self.safeAreaBar(edge: .bottom, spacing: 0, content: content)
        } else {
            self.safeAreaInset(edge: .bottom, spacing: 0, content: content)
        }
    }
    
    @ViewBuilder
    func chatScrollEdgeEffectHidden() -> some View {
        if #available(iOS 26.0, *) {
            self.scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            self
        }
    }
}

// MARK: - ChatDetailView Main
struct ChatDetailView: View {
    var contactName: String = "Contact Name"
    var unreadBadgeCount: Int = 4
    var groupParticipantCount: Int? = 3
    var isEncryptedSession: Bool = true
    
    // Geometry Constants
    private let chatEdgeInset: CGFloat = 16
    private let messageSpacing: CGFloat = 2
    private let bubbleHorizontalPadding: CGFloat = 16
    private let bubbleVerticalPadding: CGFloat = 8
    private let bubbleCornerRadius: CGFloat = 18
    private let mediaCardCornerRadius: CGFloat = 8 // max(0, 18 - 10)
    private let maxBubbleWidth: CGFloat = 280
    
    // Composer Layout Math
    private let composerButtonDiameter: CGFloat = 36
    private let composerButtonSlack: CGFloat = 4
    private let composerBarInset: CGFloat = 12 // 16 - 4
    private let composerControlSpacing: CGFloat = 4 // 8 - 4
    
    // Scheduled dash style
    private let scheduledDashStyle = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round, dash: [5, 5])
    
    // State
    @State private var messages: [ChatMessage] = []
    @State private var composerText: String = ""
    @State private var scheduledSendDate: Date? = nil
    @State private var currentTransport: MessageTransport = .p2p
    @State private var stagedAttachments: [ChatMediaItem] = []
    
    // Voice Memo Recording State
    @State private var isRecordingVoiceMemo: Bool = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var stagedVoiceMemo: VoiceMemoData? = nil
    @State private var stagedPlaybackProgress: Double = 0.0
    @State private var isPlayingStagedVoiceMemo: Bool = false
    @State private var liveLevels: [Float] = [0.2, 0.4, 0.6, 0.8, 0.5, 0.3, 0.7, 0.9]
    @State private var recordingTimer: Timer? = nil
    
    // Full Screen Media Viewer
    @State private var viewerImage: ChatMediaItem? = nil
    @State private var viewerImageBatch: [ChatMediaItem] = []
    @State private var viewerIndex: Int = 0
    @State private var viewerDragOffset: CGSize = .zero
    @Namespace private var mediaNamespace
    
    // Reaction Overlay State
    @State private var selectedReactionMessage: ChatMessage? = nil
    @State private var showReactionOverlay: Bool = false
    @State private var retryMessage: ChatMessage? = nil
    @State private var showRetryConfirmation: Bool = false
    
    @EnvironmentObject var wallet: Wallet
    @EnvironmentObject var appearance: Appearance
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: messageSpacing) {
                        ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                            // Transport Divider Header
                            if shouldShowTransportDivider(at: index) {
                                transportDivider(message.transport)
                            }
                            
                            // Message Row
                            messageRow(message)
                                .id(message.id)
                        }
                        
                        // Thread Encryption Footer
                        threadEncryptionFooter
                            .padding(.top, 12)
                        
                        // Bottom Clearance Anchor
                        Spacer(minLength: 4)
                        Color.clear
                            .frame(height: 1)
                            .id("chat_bottom_anchor")
                    }
                    .padding(.horizontal, chatEdgeInset)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .chatScrollEdgeEffectHidden()
                .defaultScrollAnchor(CommandLine.arguments.contains("-testScrollTop") ? .top : .bottom)
                .onChange(of: messages.count) { _ in
                    if !CommandLine.arguments.contains("-testScrollTop") {
                        withAnimation(.easeOut(duration: 0.25)) {
                            scrollProxy.scrollTo("chat_bottom_anchor", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .chatBottomSafeAreaBar {
            bottomComposerBar
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton(unreadCount: unreadBadgeCount) {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .principal) {
                principalHeaderMenu
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Video Call
                } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appPrimary)
                }
            }
            
            if #available(iOS 26.0, *) {
                ToolbarSpacer(.fixed, placement: .topBarTrailing)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    // Audio Call
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .toolbar(viewerImage != nil ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .restoresSwipeBackGesture()
        .fontDesign(appearance.getAppFont())
        .onAppear {
            if messages.isEmpty {
                loadSeedMessages()
            }
            if CommandLine.arguments.contains("-testArmedComposer") {
                scheduledSendDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
                composerText = "Waypoint rendezvous coordinates confirmed."
            }
            if CommandLine.arguments.contains("-testRecordingBar") {
                isRecordingVoiceMemo = true
                recordingDuration = 4.2
                liveLevels = [0.25, 0.5, 0.8, 1.0, 0.65, 0.35, 0.7, 0.9]
            }
            if CommandLine.arguments.contains("-testStagedReviewBar") {
                stagedVoiceMemo = VoiceMemoData(
                    duration: 16.0,
                    waveformLevels: (0..<36).map { _ in Float.random(in: 0.15...0.95) }
                )
                stagedPlaybackProgress = 0.42
            }
        }
        // Full Screen Hero Media Viewer Overlay
        .overlay {
            if let activeMedia = viewerImage {
                mediaViewerOverlay(activeMedia)
            }
        }
        // Tapback Reaction & Context Action Menu Overlay
        .overlay {
            if showReactionOverlay, let targetMessage = selectedReactionMessage {
                reactionOverlay(for: targetMessage)
            }
        }
        // Confirmation dialog for failed message retry
        .confirmationDialog("Message Failed", isPresented: $showRetryConfirmation, titleVisibility: .visible) {
            Button("Retry Sending") {
                if let msg = retryMessage, let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                    messages[idx].deliveryStatus = .delivered
                }
            }
            Button("Delete Message", role: .destructive) {
                if let msg = retryMessage {
                    messages.removeAll(where: { $0.id == msg.id })
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This message was not sent due to off-grid connection timeout.")
        }
    }
    
    // MARK: - Principal Header Menu
    private var principalHeaderMenu: some View {
        Menu {
            Button {
                currentTransport = .p2p
            } label: {
                Label("P2P (Signal / Nostr)", systemImage: "lock.fill")
            }
            Button {
                currentTransport = .bluetoothMesh
            } label: {
                Label("Bluetooth Mesh", systemImage: "antenna.radiowaves.left.and.right")
            }
            Button {
                currentTransport = .meshCore
            } label: {
                Label("MeshCore", systemImage: "point.3.filled.connected.trianglepath.dotted")
            }
            Button {
                currentTransport = .meshtastic
            } label: {
                Label("Meshtastic", systemImage: "wave.3.forward.circle.fill")
            }
            Button {
                currentTransport = .walkieTalkie
            } label: {
                Label("Walkie-Talkie", systemImage: "radio.fill")
            }
            
            Divider()
            
            Button {
                // View Contact Info
            } label: {
                Label("Contact Info", systemImage: "person.crop.circle")
            }
        } label: {
            VStack(spacing: 2) {
                CheckeredAvatarPlaceholder(size: 34)
                    .clipShape(Circle())
                
                HStack(spacing: 4) {
                    if isEncryptedSession {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    
                    Text(contactName)
                        .font(.system(.caption, design: appearance.getAppFont()).weight(.bold))
                        .foregroundStyle(Color.appPrimary)
                    
                    if let count = groupParticipantCount {
                        Text("(\(count))")
                            .font(.system(.caption2, design: appearance.getAppFont()))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Transport Divider Header
    private func shouldShowTransportDivider(at index: Int) -> Bool {
        let msg = messages[index]
        guard msg.isSender else { return false }
        if index == 0 { return true }
        // Find preceding sent message
        for prevIndex in (0..<index).reversed() {
            if messages[prevIndex].isSender {
                return messages[prevIndex].transport != msg.transport
            }
        }
        return true
    }
    
    private func transportDivider(_ transport: MessageTransport) -> some View {
        HStack(spacing: 5) {
            Image(systemName: transport.iconName)
                .font(.system(size: 10, weight: .semibold))
            Text(transport.rawValue)
                .font(.system(.caption2, design: appearance.getAppFont()).weight(.semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(uiColor: .secondarySystemFill))
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
    }
    
    // MARK: - Thread Encryption Footer
    private var threadEncryptionFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 10))
            Text("Messages Encrypted | \(currentTransport.rawValue)")
                .font(.system(.caption2, design: appearance.getAppFont()))
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    // MARK: - Message Row View
    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: message.isSender ? .trailing : .leading, spacing: 2) {
            HStack(alignment: .bottom, spacing: 0) {
                if message.isSender {
                    Spacer(minLength: 40)
                }
                
                // Bubble Container with Gestures
                ZStack(alignment: message.isSender ? .bottomLeading : .bottomTrailing) {
                    bubbleContent(message)
                    
                    // Tapback Reaction Pill
                    if !message.reactions.isEmpty {
                        reactionPill(for: message)
                            .offset(y: 10)
                    }
                }
                .frame(maxWidth: maxBubbleWidth, alignment: message.isSender ? .trailing : .leading)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.35)
                        .onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                selectedReactionMessage = message
                                showReactionOverlay = true
                            }
                        }
                )
                
                if !message.isSender {
                    Spacer(minLength: 40)
                }
            }
            
            // Rich Link Preview below bubble (if URL present)
            if let url = message.linkURL, !message.isDeleted {
                HStack {
                    if message.isSender { Spacer() }
                    ChatLinkPreview(url: url)
                        .frame(maxWidth: maxBubbleWidth)
                    if !message.isSender { Spacer() }
                }
                .padding(.top, 2)
            }
            
            // Delivery / Read Receipts
            if message.isSender {
                deliveryIndicator(for: message)
            }
        }
        .padding(.vertical, 1)
    }
    
    // MARK: - Bubble Content Dispatcher
    @ViewBuilder
    private func bubbleContent(_ message: ChatMessage) -> some View {
        if message.isDeleted {
            // Deleted Message State
            Text("This message was deleted")
                .font(.system(.body, design: appearance.getAppFont()))
                .italic()
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, bubbleHorizontalPadding)
                .padding(.vertical, bubbleVerticalPadding)
                .background(Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
        } else if message.isThinking || message.text == "Thinking..." {
            // Thinking / Typing Dots
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, bubbleHorizontalPadding)
            .padding(.vertical, bubbleVerticalPadding)
            .background(Color(uiColor: .quaternarySystemFill))
            .clipShape(Capsule())
        } else if let voiceMemo = message.voiceMemo {
            // Voice Memo Player Bubble
            VoiceMemoPlayerView(
                voiceMemo: voiceMemo,
                isSender: message.isSender,
                transportColor: message.transport.bubbleColor,
                fontDesign: appearance.getAppFont()
            )
        } else if !message.mediaItems.isEmpty {
            // Multi-Photo Fanned Stack
            ImageStackBubble(
                items: message.mediaItems,
                isSender: message.isSender,
                namespace: mediaNamespace
            ) { selectedItem in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    viewerImage = selectedItem
                    viewerImageBatch = message.mediaItems
                    viewerIndex = message.mediaItems.firstIndex(of: selectedItem) ?? 0
                }
            }
        } else if message.scheduledSendDate != nil {
            // Pending Scheduled Bubble
            VStack(alignment: .leading, spacing: 6) {
                Text(message.text)
                    .font(.system(.body, design: appearance.getAppFont()))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, bubbleHorizontalPadding)
            .padding(.vertical, bubbleVerticalPadding)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                    .stroke(imessageBlue, style: scheduledDashStyle)
            )
            .contextMenu {
                Button {
                    // Send Now
                    if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                        messages[idx].scheduledSendDate = nil
                        messages[idx].deliveryStatus = .delivered
                    }
                } label: {
                    Label("Send Message", systemImage: "paperplane.fill")
                }
                
                Button {
                    // Edit Time
                } label: {
                    Label("Edit Time", systemImage: "clock")
                }
                
                Button(role: .destructive) {
                    messages.removeAll(where: { $0.id == message.id })
                } label: {
                    Label("Delete Message", systemImage: "trash")
                }
            }
        } else {
            // Standard Text Bubble
            Text(message.text)
                .font(.system(.body, design: appearance.getAppFont()))
                .foregroundStyle(message.isSender ? .white : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, bubbleHorizontalPadding)
                .padding(.vertical, bubbleVerticalPadding)
                .background(message.isSender ? message.transport.bubbleColor : Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
        }
    }
    
    // MARK: - Delivery Indicator
    @ViewBuilder
    private func deliveryIndicator(for message: ChatMessage) -> some View {
        if let scheduledDate = message.scheduledSendDate {
            Label("Send Later \(formattedScheduled(scheduledDate))", systemImage: "clock.badge")
                .font(.system(.caption2, design: appearance.getAppFont()).weight(.medium))
                .foregroundStyle(imessageBlue)
                .padding(.top, 2)
        } else if let status = message.deliveryStatus {
            switch status {
            case .failed:
                Button {
                    retryMessage = message
                    showRetryConfirmation = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Not Delivered")
                    }
                    .font(.system(.caption2, design: appearance.getAppFont()).weight(.semibold))
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .padding(.top, 1)
                
            case .seen(let date):
                Text("Seen \(formattedSeenTime(date))")
                    .font(.system(.caption2, design: appearance.getAppFont()))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                
            case .delivered:
                if isLatestSentMessage(message) {
                    Text("Delivered")
                        .font(.system(.caption2, design: appearance.getAppFont()))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
                
            case .sent:
                if isLatestSentMessage(message) {
                    Text("Sent")
                        .font(.system(.caption2, design: appearance.getAppFont()))
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
                
            case .sending:
                Text("Sending...")
                    .font(.system(.caption2, design: appearance.getAppFont()))
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
            }
        }
    }
    
    private func isLatestSentMessage(_ message: ChatMessage) -> Bool {
        guard let lastSent = messages.last(where: { $0.isSender && $0.scheduledSendDate == nil }) else {
            return false
        }
        return lastSent.id == message.id
    }
    
    private func formattedSeenTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd/yy"
            return formatter.string(from: date)
        }
    }
    
    private func formattedScheduled(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "Today at \(formatter.string(from: date))"
    }
    
    // MARK: - Reaction Corner Pill
    private func reactionPill(for message: ChatMessage) -> some View {
        HStack(spacing: 2) {
            ForEach(message.reactions.prefix(4), id: \.self) { emoji in
                Text(emoji)
                    .font(.system(size: 13))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            message.userReaction != nil
            ? AnyShapeStyle(imessageBlue.opacity(0.9))
            : AnyShapeStyle(.thickMaterial)
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
    }
    
    // MARK: - Bottom Composer Bar
    private var bottomComposerBar: some View {
        VStack(spacing: 0) {
            // Attachment shelf (if any media staged)
            if !stagedAttachments.isEmpty {
                attachmentTray
            }
            
            // Armed "Send Later" Pill (if active)
            if let sendDate = scheduledSendDate {
                scheduledTimePill(sendDate)
            }
            
            if isRecordingVoiceMemo {
                inlineRecordingBar
            } else if stagedVoiceMemo != nil {
                stagedVoiceMemoBar
            } else {
                standardComposerRow
            }
        }
        .padding(.horizontal, composerBarInset)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.0),
                            .init(color: .black.opacity(0.35), location: 0.15),
                            .init(color: .black.opacity(0.85), location: 0.32),
                            .init(color: .black, location: 0.48),
                            .init(color: .black, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
    
    // MARK: - Standard Composer Row
    private var standardComposerRow: some View {
        HStack(spacing: composerControlSpacing) {
            // Plus Menu Button with 36pt optical diameter inside 44x44 target
            Menu {
                Button {
                    stagedAttachments.append(
                        ChatMediaItem(id: UUID(), title: "Photo", systemIcon: "photo", gradientColors: [.blue, .purple], caption: "Sunset Vista")
                    )
                } label: {
                    Label("Photos", systemImage: "photo.on.rectangle")
                }
                
                Button {
                    stagedAttachments.append(contentsOf: [
                        ChatMediaItem(id: UUID(), title: "Map", systemIcon: "map.fill", gradientColors: [.green, .teal], caption: "Trailhead Alpha"),
                        ChatMediaItem(id: UUID(), title: "Radio", systemIcon: "antenna.radiowaves.left.and.right", gradientColors: [.orange, .red], caption: "Relay Node"),
                        ChatMediaItem(id: UUID(), title: "Satellite", systemIcon: "globe.americas.fill", gradientColors: [.indigo, .blue], caption: "Topo Scan")
                    ])
                } label: {
                    Label("Add Fanned Stack (3 Photos)", systemImage: "square.stack.fill")
                }
                
                Button {
                    if scheduledSendDate == nil {
                        scheduledSendDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
                    } else {
                        scheduledSendDate = nil
                    }
                } label: {
                    Label(scheduledSendDate == nil ? "Send Later" : "Cancel Send Later", systemImage: "clock")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(uiColor: .secondarySystemFill))
                        .frame(width: composerButtonDiameter, height: composerButtonDiameter)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.appPrimary)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            
            // Text Input Capsule / Scheduled Dashed Capsule
            HStack(spacing: 8) {
                TextField("Message", text: $composerText)
                    .font(.system(.body, design: appearance.getAppFont()))
                    .foregroundStyle(Color.appPrimary)
                
                if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && stagedAttachments.isEmpty {
                    // Voice Memo Mic Button
                    Button {
                        startVoiceRecording()
                    } label: {
                        Image(systemName: "waveform")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Send Arrow Button
                    Button {
                        sendMessage()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(imessageBlue)
                                .frame(width: 30, height: 30)
                            
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: scheduledSendDate != nil ? bubbleCornerRadius : 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: scheduledSendDate != nil ? bubbleCornerRadius : 20, style: .continuous)
                    .stroke(
                        scheduledSendDate != nil ? imessageBlue : Color(uiColor: .separator),
                        style: scheduledSendDate != nil ? scheduledDashStyle : StrokeStyle(lineWidth: 0.5)
                    )
            )
        }
    }
    
    // MARK: - Armed Scheduled Time Pill
    private func scheduledTimePill(_ date: Date) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.fill")
                .font(.system(size: 11, weight: .semibold))
            
            Text(formattedScheduled(date))
                .font(.system(.caption, design: appearance.getAppFont()).weight(.medium))
            
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(imessageBlue.opacity(0.6))
            
            Spacer()
            
            Button {
                scheduledSendDate = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(imessageBlue)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(imessageBlue)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(imessageBlue.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(imessageBlue.opacity(0.40), lineWidth: 1)
        )
        .padding(.bottom, 6)
    }
    
    // MARK: - Inline Recording Bar
    private var inlineRecordingBar: some View {
        HStack(spacing: 10) {
            // Cancel button
            Button {
                cancelVoiceRecording()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .liquidGlassEffect()
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Capsule with pulsing dot, waveform, and timer
            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                
                LiveWaveformView(levels: liveLevels)
                    .frame(height: 20)
                
                Spacer()
                
                Text(formattedDuration(recordingDuration))
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)
            .liquidGlassEffect()
            .clipShape(Capsule())
            
            // Stop button
            Button {
                stopVoiceRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(.red)
                        .frame(width: 34, height: 34)
                    
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Staged Voice Memo Review Bar
    private var stagedVoiceMemoBar: some View {
        HStack(spacing: 10) {
            // Discard Button
            Button {
                stagedVoiceMemo = nil
                isPlayingStagedVoiceMemo = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 38, height: 38)
                    .liquidGlassEffect()
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            
            // Capsule Reviewer
            HStack(spacing: 10) {
                Button {
                    isPlayingStagedVoiceMemo.toggle()
                } label: {
                    Image(systemName: isPlayingStagedVoiceMemo ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(imessageBlue)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                StagedWaveformScrubber(
                    levels: stagedVoiceMemo?.waveformLevels ?? [],
                    progress: $stagedPlaybackProgress
                )
                .frame(height: 20)
                
                Text("+ 0:16")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                
                // Send Voice Memo
                Button {
                    if let memo = stagedVoiceMemo {
                        let newMsg = ChatMessage(
                            id: UUID(),
                            text: "Voice Memo",
                            isSender: true,
                            timestamp: Date(),
                            transport: currentTransport,
                            deliveryStatus: .delivered,
                            voiceMemo: memo
                        )
                        messages.append(newMsg)
                        stagedVoiceMemo = nil
                        isPlayingStagedVoiceMemo = false
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(imessageBlue)
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .liquidGlassEffect()
            .clipShape(Capsule())
        }
    }
    
    // MARK: - Media Attachment Shelf
    private var attachmentTray: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(stagedAttachments) { item in
                    ZStack(alignment: .topTrailing) {
                        LinearGradient(colors: item.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(uiColor: .separator), lineWidth: 0.5)
                            )
                            .overlay(
                                Image(systemName: item.systemIcon)
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.85))
                            )
                        
                        Button {
                            stagedAttachments.removeAll(where: { $0.id == item.id })
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.7))
                        }
                        .offset(x: 4, y: -4)
                    }
                    .frame(width: 62, height: 62)
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollClipDisabled()
        .padding(.bottom, 6)
    }
    
    // MARK: - Actions
    private func sendMessage() {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !stagedAttachments.isEmpty else { return }
        
        let batchID = stagedAttachments.count > 1 ? UUID() : nil
        let newMsg = ChatMessage(
            id: UUID(),
            text: trimmed,
            isSender: true,
            timestamp: Date(),
            transport: currentTransport,
            deliveryStatus: scheduledSendDate == nil ? .delivered : nil,
            scheduledSendDate: scheduledSendDate,
            sendBatchID: batchID,
            mediaItems: stagedAttachments,
            linkURL: detectLink(in: trimmed)
        )
        
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            messages.append(newMsg)
            composerText = ""
            stagedAttachments = []
            scheduledSendDate = nil
        }
    }
    
    private func detectLink(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return nil }
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        return matches.first?.url
    }
    
    private func startVoiceRecording() {
        isRecordingVoiceMemo = true
        recordingDuration = 0
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingDuration += 0.1
            liveLevels = (0..<8).map { _ in Float.random(in: 0.1...1.0) }
        }
    }
    
    private func stopVoiceRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecordingVoiceMemo = false
        stagedPlaybackProgress = 0.0
        
        // Generate 36 sample levels for review
        let sampleLevels = (0..<36).map { _ in Float.random(in: 0.15...0.95) }
        stagedVoiceMemo = VoiceMemoData(duration: recordingDuration > 0 ? recordingDuration : 16.0, waveformLevels: sampleLevels)
    }
    
    private func cancelVoiceRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        isRecordingVoiceMemo = false
        recordingDuration = 0
    }
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(seconds)
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
    
    // MARK: - Tapback Reactions Overlay
    private func reactionOverlay(for message: ChatMessage) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showReactionOverlay = false
                        selectedReactionMessage = nil
                    }
                }
            
            VStack(spacing: 16) {
                // 6-Emoji Tapback Capsule
                HStack(spacing: 14) {
                    ForEach(["❤️", "👍", "👎", "😂", "‼️", "❓"], id: \.self) { emoji in
                        Button {
                            toggleReaction(emoji, for: message)
                            withAnimation(.easeOut(duration: 0.2)) {
                                showReactionOverlay = false
                                selectedReactionMessage = nil
                            }
                        } label: {
                            Text(emoji)
                                .font(.system(size: 28))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(.regularMaterial)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.18), radius: 10, y: 5)
                
                // Echoed Target Bubble
                bubbleContent(message)
                    .frame(maxWidth: maxBubbleWidth, alignment: message.isSender ? .trailing : .leading)
                    .padding(.horizontal, 16)
                
                // Vertical Action Menu
                VStack(spacing: 0) {
                    if message.deliveryStatus == .failed {
                        menuRow(title: "Retry Send", icon: "arrow.clockwise") {
                            retryMessage = message
                            showRetryConfirmation = true
                            showReactionOverlay = false
                        }
                        Divider()
                    }
                    menuRow(title: "Copy", icon: "doc.on.doc") {
                        UIPasteboard.general.string = message.text
                        showReactionOverlay = false
                    }
                    Divider()
                    menuRow(title: "Edit", icon: "pencil") {
                        composerText = message.text
                        showReactionOverlay = false
                    }
                    Divider()
                    menuRow(title: "Share Audio...", icon: "square.and.arrow.up") {
                        showReactionOverlay = false
                    }
                    Divider()
                    menuRow(title: "Delete", icon: "trash", isDestructive: true) {
                        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
                            messages[idx].isDeleted = true
                        }
                        showReactionOverlay = false
                    }
                }
                .frame(maxWidth: 260)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 12, y: 6)
            }
            .padding(.horizontal, 24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }
    
    private func menuRow(title: String, icon: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(.body, design: appearance.getAppFont()))
                    .foregroundStyle(isDestructive ? .red : Color.appPrimary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isDestructive ? .red : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
    
    private func toggleReaction(_ emoji: String, for message: ChatMessage) {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return }
        if messages[idx].userReaction == emoji {
            messages[idx].userReaction = nil
            messages[idx].reactions.removeAll(where: { $0 == emoji })
        } else {
            if let old = messages[idx].userReaction {
                messages[idx].reactions.removeAll(where: { $0 == old })
            }
            messages[idx].userReaction = emoji
            messages[idx].reactions.append(emoji)
        }
    }
    
    // MARK: - Full Screen Hero Media Viewer Overlay
    @ViewBuilder
    private func mediaViewerOverlay(_ activeItem: ChatMediaItem) -> some View {
        let dragProgress = min(1.0, abs(viewerDragOffset.height) / 180.0)
        let backdropOpacity = max(0.0, 1.0 - Double(dragProgress) * 0.7)
        let scale = max(0.85, 1.0 - (dragProgress * 0.15))
        
        ZStack {
            Color.black.opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewerImage = nil
                    }
                }
            
            VStack {
                // Top controls
                HStack {
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            viewerImage = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Liquid Glass Page Indicator Capsule
                    if viewerImageBatch.count > 1 {
                        HStack(spacing: 5) {
                            ForEach(0..<viewerImageBatch.count, id: \.self) { idx in
                                Circle()
                                    .fill(idx == viewerIndex ? Color.white : Color.white.opacity(0.4))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlassEffect()
                        .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Button {
                        // Share
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Active Card Image
                ZStack {
                    LinearGradient(
                        colors: activeItem.gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(maxWidth: 320, maxHeight: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: activeItem.systemIcon)
                                .font(.system(size: 64, weight: .medium))
                                .foregroundStyle(.white.opacity(0.9))
                            
                            if let caption = activeItem.caption {
                                Text(caption)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }
                    )
                    .matchedGeometryEffect(id: activeItem.id, in: mediaNamespace)
                    .scaleEffect(scale)
                    .offset(viewerDragOffset)
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            viewerDragOffset = value.translation
                        }
                        .onEnded { value in
                            if abs(value.translation.height) > 120 {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    viewerImage = nil
                                    viewerDragOffset = .zero
                                }
                            } else if value.translation.width < -60 && viewerIndex < viewerImageBatch.count - 1 {
                                // Next page
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    viewerIndex += 1
                                    viewerImage = viewerImageBatch[viewerIndex]
                                    viewerDragOffset = .zero
                                }
                            } else if value.translation.width > 60 && viewerIndex > 0 {
                                // Previous page
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    viewerIndex -= 1
                                    viewerImage = viewerImageBatch[viewerIndex]
                                    viewerDragOffset = .zero
                                }
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    viewerDragOffset = .zero
                                }
                            }
                        }
                )
                
                Spacer()
            }
        }
        .transition(.opacity)
    }
    
    // MARK: - Seed Mock Data
    private func loadSeedMessages() {
        let sampleLevels: [Float] = [
            0.15, 0.30, 0.55, 0.80, 0.45, 0.20, 0.65, 0.90,
            0.75, 0.40, 0.25, 0.60, 0.85, 0.50, 0.35, 0.70,
            0.95, 0.60, 0.40, 0.20, 0.55, 0.85, 0.65, 0.30,
            0.45, 0.75, 0.90, 0.60, 0.35, 0.50, 0.70, 0.85,
            0.60, 0.40, 0.25, 0.15
        ]
        
        let batchID = UUID()
        let batchItems = [
            ChatMediaItem(id: UUID(), title: "Scan 1", systemIcon: "map.fill", gradientColors: [.blue, .purple], caption: "Ridge Topo Survey"),
            ChatMediaItem(id: UUID(), title: "Scan 2", systemIcon: "antenna.radiowaves.left.and.right", gradientColors: [.orange, .red], caption: "Relay Node Point"),
            ChatMediaItem(id: UUID(), title: "Scan 3", systemIcon: "globe.americas.fill", gradientColors: [.teal, .indigo], caption: "Satellite Fix")
        ]
        
        messages = [
            // 1. Received Thinking dot placeholder
            ChatMessage(
                id: UUID(),
                text: "Thinking...",
                isSender: false,
                timestamp: Date().addingTimeInterval(-3600),
                transport: .p2p,
                isThinking: true
            ),
            
            // 2. Sent P2P iMessage Blue with Delivered receipt
            ChatMessage(
                id: UUID(),
                text: "Confirming secure peer-to-peer session over local mesh.",
                isSender: true,
                timestamp: Date().addingTimeInterval(-3000),
                transport: .p2p,
                deliveryStatus: .delivered
            ),
            
            // 3. Received with Peer Heart reaction
            ChatMessage(
                id: UUID(),
                text: "Signal verified! Ready to transmit packet payload.",
                isSender: false,
                timestamp: Date().addingTimeInterval(-2400),
                transport: .p2p,
                reactions: ["❤️"]
            ),
            
            // 4. Sent Bluetooth Mesh with Thumbs Up user reaction
            ChatMessage(
                id: UUID(),
                text: "Switching channel to Bluetooth Mesh off-grid protocol.",
                isSender: true,
                timestamp: Date().addingTimeInterval(-1800),
                transport: .bluetoothMesh,
                deliveryStatus: .seen(Date().addingTimeInterval(-1700)),
                reactions: ["👍"],
                userReaction: "👍"
            ),
            
            // 5. Sent Voice Memo Bubble (38pt capsule, 36 RMS waveform)
            ChatMessage(
                id: UUID(),
                text: "Voice Memo",
                isSender: true,
                timestamp: Date().addingTimeInterval(-1200),
                transport: .bluetoothMesh,
                deliveryStatus: .delivered,
                voiceMemo: VoiceMemoData(duration: 16.0, waveformLevels: sampleLevels)
            ),
            
            // 6. Multi-Photo Fanned Stack (Batch leader with 3 items)
            ChatMessage(
                id: UUID(),
                text: "",
                isSender: true,
                timestamp: Date().addingTimeInterval(-900),
                transport: .bluetoothMesh,
                deliveryStatus: .delivered,
                sendBatchID: batchID,
                mediaItems: batchItems,
                isBatchLeader: true
            ),
            
            // 7. Rich Link Preview (Apple Maps link at 160pt height)
            ChatMessage(
                id: UUID(),
                text: "Meeting at Cupertino rendezvous point: https://maps.apple.com/?q=Cupertino",
                isSender: false,
                timestamp: Date().addingTimeInterval(-600),
                transport: .p2p,
                linkURL: URL(string: "https://maps.apple.com/?q=Cupertino")
            ),
            
            // 8. Pending Scheduled "Send Later" Bubble
            ChatMessage(
                id: UUID(),
                text: "Scheduled rendezvous check-in at beacon waypoint.",
                isSender: true,
                timestamp: Date(),
                transport: .p2p,
                scheduledSendDate: Calendar.current.date(byAdding: .hour, value: 3, to: Date())
            ),
            
            // 9. Failed Message with Not Delivered red button
            ChatMessage(
                id: UUID(),
                text: "Failed burst packet timeout on node 4.",
                isSender: true,
                timestamp: Date(),
                transport: .bluetoothMesh,
                deliveryStatus: .failed
            ),
            
            // 10. Deleted Message State
            ChatMessage(
                id: UUID(),
                text: "This message was deleted",
                isSender: false,
                timestamp: Date(),
                transport: .p2p,
                isDeleted: true
            )
        ]
    }
}

// MARK: - Custom Back Button with Unread Badge
struct CustomBackButton: View {
    let unreadCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.appPrimary)
                
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(imessageBlue)
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice Memo Player View (Section 6)
struct VoiceMemoPlayerView: View {
    let voiceMemo: VoiceMemoData
    let isSender: Bool
    let transportColor: Color
    let fontDesign: Font.Design
    
    @State private var isPlaying: Bool = false
    @State private var playbackProgress: Double = 0.35
    @State private var currentSpeedIndex: Int = 0
    private let speeds: [Double] = [1.0, 1.25, 1.5, 2.0]
    private let speedLabels: [String] = ["1x", "1.25x", "1.5x", "2x"]
    
    var body: some View {
        HStack(spacing: 8) {
            // 28x28 Play/Pause Circle Button (5pt concentric inset in 38pt capsule)
            Button {
                isPlaying.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(isSender ? Color.white.opacity(0.25) : Color(uiColor: .tertiarySystemFill))
                        .frame(width: 28, height: 28)
                    
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(isSender ? .white : Color.appPrimary)
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            
            // 36-Bar RMS Waveform Analyzer (24pt height, 2pt bar spacing)
            GeometryReader { geo in
                let barWidth: CGFloat = (geo.size.width - (CGFloat(voiceMemo.waveformLevels.count - 1) * 2)) / CGFloat(voiceMemo.waveformLevels.count)
                
                HStack(spacing: 2) {
                    ForEach(0..<voiceMemo.waveformLevels.count, id: \.self) { i in
                        let level = CGFloat(voiceMemo.waveformLevels[i])
                        let barHeight = max(4, level * 24)
                        let barProgress = Double(i) / Double(voiceMemo.waveformLevels.count)
                        let isPlayed = barProgress <= playbackProgress
                        
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .fill(
                                isSender
                                ? (isPlayed ? Color.white : Color.white.opacity(0.4))
                                : (isPlayed ? Color.appPrimary : Color.secondary.opacity(0.35))
                            )
                            .frame(width: max(1.5, barWidth), height: barHeight)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = max(0.0, min(1.0, value.location.x / geo.size.width))
                            playbackProgress = fraction
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                )
            }
            .frame(height: 24)
            
            // Trailing Stack: Speed Pill above Monospaced Duration Counter
            VStack(alignment: .trailing, spacing: 1) {
                Button {
                    currentSpeedIndex = (currentSpeedIndex + 1) % speeds.count
                } label: {
                    Text(speedLabels[currentSpeedIndex])
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(isSender ? .white : Color.appPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSender ? Color.white.opacity(0.25) : Color(uiColor: .tertiarySystemFill))
                        )
                }
                .buttonStyle(.plain)
                
                Text(formattedDuration(voiceMemo.duration * (1.0 - playbackProgress)))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isSender ? .white.opacity(0.85) : .secondary)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .frame(idealWidth: 260, maxWidth: 280)
        .background(isSender ? transportColor : Color(uiColor: .secondarySystemFill))
        .clipShape(Capsule())
    }
    
    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let secs = Int(max(0, seconds))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Live Waveform View for Inline Recording Bar
struct LiveWaveformView: View {
    let levels: [Float]
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<levels.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.red)
                    .frame(width: 3, height: max(4, CGFloat(levels[i]) * 20))
            }
        }
    }
}

// MARK: - Staged Waveform Scrubber
struct StagedWaveformScrubber: View {
    let levels: [Float]
    @Binding var progress: Double
    
    var body: some View {
        GeometryReader { geo in
            let count = max(1, min(26, levels.count))
            let barWidth = (geo.size.width - CGFloat(count - 1) * 2) / CGFloat(count)
            
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { i in
                    let level = CGFloat(levels[i % levels.count])
                    let h = max(4, level * 20)
                    let p = Double(i) / Double(count)
                    
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(p <= progress ? imessageBlue : Color.secondary.opacity(0.3))
                        .frame(width: max(1.5, barWidth), height: h)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        progress = max(0.0, min(1.0, val.location.x / geo.size.width))
                    }
            )
        }
    }
}

// MARK: - Multi-Photo Fanned Stack Bubble (Section 5)
struct ImageStackBubble: View {
    let items: [ChatMediaItem]
    let isSender: Bool
    var namespace: Namespace.ID
    let onSelect: (ChatMediaItem) -> Void
    
    private let cardWidth: CGFloat = 180
    private let cardHeight: CGFloat = 240
    private let cardCornerRadius: CGFloat = 20
    private let fanBleed: CGFloat = 56
    private let bottomBleed: CGFloat = 24
    private let maxDealtCards = 2
    
    var body: some View {
        let displayCount = min(items.count, maxDealtCards + 1)
        
        ZStack(alignment: .bottom) {
            // Render back cards first (depth 2 down to 0)
            ForEach(Array(stride(from: displayCount - 1, through: 0, by: -1)), id: \.self) { depth in
                let item = items[depth]
                let scale = pow(0.84, Double(depth))
                let rotationAngle = Double(depth) * 16.0 * (isSender ? 1.0 : -1.0)
                
                singleCard(item)
                    .scaleEffect(scale, anchor: .bottom)
                    .rotationEffect(.degrees(rotationAngle), anchor: .bottom)
                    .offset(x: isSender ? -CGFloat(depth * 4) : CGFloat(depth * 4))
                    .matchedGeometryEffect(id: depth == 0 ? item.id : UUID(), in: namespace)
                    .zIndex(Double(-depth))
            }
        }
        .frame(
            width: cardWidth + fanBleed,
            height: cardHeight + bottomBleed,
            alignment: isSender ? .bottomTrailing : .bottomLeading
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if let first = items.first {
                onSelect(first)
            }
        }
    }
    
    private func singleCard(_ item: ChatMediaItem) -> some View {
        LinearGradient(
            colors: item.gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.3), lineWidth: 0.5)
        )
        .overlay(
            VStack {
                Spacer()
                Image(systemName: item.systemIcon)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                if let caption = item.caption {
                    Text(caption)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 12)
                }
            }
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Rich Link Preview (Section 7)
struct ChatLinkPreview: View {
    let url: URL
    
    private var isMapLink: Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("maps.apple.com") || host.contains("maps.google.com") || host.contains("waze.com")
    }
    
    var body: some View {
        LinkPreviewViewRepresentable(url: url, isMap: isMapLink)
            .frame(height: isMapLink ? 160 : 90)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: .separator).opacity(0.5), lineWidth: 0.5)
            )
    }
}

@MainActor
final class LinkPreviewCache {
    static let shared = LinkPreviewCache()
    private var cache: [URL: LPLinkMetadata] = [:]
    
    func metadata(for url: URL) -> LPLinkMetadata? {
        cache[url]
    }
    func store(_ metadata: LPLinkMetadata, for url: URL) {
        cache[url] = metadata
    }
}

struct LinkPreviewViewRepresentable: UIViewRepresentable {
    let url: URL
    let isMap: Bool
    
    func makeUIView(context: Context) -> LPLinkView {
        if let cached = LinkPreviewCache.shared.metadata(for: url) {
            let linkView = LPLinkView(metadata: cached)
            return linkView
        }
        
        let linkView = LPLinkView(url: url)
        Task { @MainActor in
            let provider = LPMetadataProvider()
            if let meta = try? await provider.startFetchingMetadata(for: url) {
                LinkPreviewCache.shared.store(meta, for: url)
                linkView.metadata = meta
            }
        }
        return linkView
    }
    
    func updateUIView(_ uiView: LPLinkView, context: Context) {}
}

// MARK: - Preview Provider
struct ChatDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ChatDetailView()
                .environmentObject(Wallet())
                .environmentObject(Appearance())
        }
    }
}
