import SwiftUI
import AVFoundation
import Combine

// MARK: - Spatial Grid & Bubble Constants

private let bubbleCornerRadius: CGFloat = 18
private let mediaCardCornerRadius: CGFloat = OrchardDesign.CornerRadius.concentric(outer: bubbleCornerRadius, padding: 10)
private let bubbleHorizontalPadding: CGFloat = 16
private let bubbleVerticalPadding: CGFloat = 8
private let chatEdgeInset: CGFloat = 16
private let messageSpacing: CGFloat = 2

// Composer bar optical geometry
private let composerButtonDiameter: CGFloat = 36
private let composerButtonSlack: CGFloat = (OrchardDesign.Spacing.minimumTouchTarget - composerButtonDiameter) / 2 // 4pt
private let composerBarInset: CGFloat = chatEdgeInset - composerButtonSlack // 12pt -> 16pt visual margin
private let composerControlSpacing: CGFloat = 8 - composerButtonSlack       // 4pt -> 8pt visual gap

// MARK: - Custom Back Button with Unread Pill

public struct CustomBackButton: View {
    public var unreadCount: Int = 0
    @Environment(\.dismiss) private var dismiss

    private var unreadBadgeText: String? {
        guard unreadCount > 0 else { return nil }
        return unreadCount > 99 ? "99+" : "\(unreadCount)"
    }

    public init(unreadCount: Int = 0) {
        self.unreadCount = unreadCount
    }

    public var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.body.bold())
                    .foregroundStyle(.primary)

                if let text = unreadBadgeText {
                    Text(text)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, text.count > 2 ? 6 : 0)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Color.blue, in: Capsule())
                }
            }
        }
    }
}

// MARK: - Schedule Time Picker Sheet ("Send Later" / "Edit Time")

public struct ScheduleTimePickerSheet: View {
    @Binding public var date: Date
    public var isEditingExisting: Bool = false
    public let onConfirm: () -> Void
    public let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(
        date: Binding<Date>,
        isEditingExisting: Bool = false,
        onConfirm: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self._date = date
        self.isEditingExisting = isEditingExisting
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }

    private var presets: [(label: String, date: Date)] {
        let calendar = Calendar.current
        let now = Date()
        var options: [(String, Date)] = []

        if let inOneHour = calendar.date(byAdding: .hour, value: 1, to: now) {
            options.append(("In 1 Hour", inOneHour))
        }
        if let tonight = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: now), tonight > now {
            options.append(("Tonight", tonight))
        }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           let tomorrowMorning = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) {
            options.append(("Tomorrow 9 AM", tomorrowMorning))
        }
        return options
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: OrchardDesign.Spacing.standard) {
                if !presets.isEmpty {
                    ScrollView(.horizontal) {
                        HStack(spacing: OrchardDesign.Spacing.micro) {
                            ForEach(presets, id: \.label) { preset in
                                Button {
                                    OrchardMotion.perform(.selection) { date = preset.date }
                                } label: {
                                    Text(preset.label)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, OrchardDesign.Spacing.micro)
                                        .padding(.vertical, 8)
                                        .background(Color.gray.opacity(0.2), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, OrchardDesign.Spacing.standard)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }

                DatePicker(
                    "",
                    selection: $date,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Text("Orchard sends this when the time arrives. If your device is asleep or Orchard is closed, it goes out as soon as the app is next opened.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OrchardDesign.Spacing.standard)

                Spacer(minLength: 0)
            }
            .padding(.top, OrchardDesign.Spacing.standard)
            .navigationTitle(isEditingExisting ? "Edit Time" : "Send Later")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditingExisting ? "Save" : "Schedule") {
                        onConfirm()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(OrchardDesign.CornerRadius.sheetTopRadius)
        .interactiveDismissDisabled()
    }
}

// MARK: - Bubble Send Transition Helpers

/// Applies the `MBTChatView` vertical settle push (`keyframeAnimator` driven by
/// `isVisible` flipping from `false` to `true`) on newly sent bubbles.
private struct SendBubbleBounceModifier: ViewModifier {
    let isVisible: Bool
    let offsetAmplitude: CGFloat
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .compositingGroup()
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: isVisible) { view, progress in
                view.offset(y: reduceMotion ? 0 : offsetAmplitude * progress)
            } keyframes: { _ in
                CubicKeyframe(1, duration: 0.15)
                CubicKeyframe(0, duration: 0.15)
            }
    }
}

/// Lightweight visual clone of a sent `VoiceMemoPlayerView` capsule used for
/// the Frame-0 composer transition source without allocating an `AVAudioPlayer`.
private struct VoiceBubbleTransitionPreview: View {
    let url: URL
    let tint: Color
    let duration: TimeInterval
    var isScheduled: Bool = false

    private static let barCount = 36
    private static let playControlDiameter: CGFloat = 28
    private static let waveformHeight: CGFloat = 24
    private static let waveformBarSpacing: CGFloat = 2.0

    private var formattedDuration: String {
        let secs = max(0, Int(duration.rounded()))
        return String(format: "%02d:%02d", secs / 60, secs % 60)
    }

    var body: some View {
        let bars = WaveformAnalyzer.cachedBars(for: url) ?? WaveformAnalyzer.bars(for: url, count: Self.barCount)
        HStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(isScheduled ? tint.opacity(0.15) : OrchardDesign.Colors.offWhite)
                    .frame(width: Self.playControlDiameter, height: Self.playControlDiameter)
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                    .offset(x: 1)
            }
            .padding(.leading, 5)

            GeometryReader { proxy in
                let count = max(bars.count, 1)
                let barW = max(
                    (proxy.size.width - CGFloat(count - 1) * Self.waveformBarSpacing) / CGFloat(count),
                    1.5
                )
                let barColor = isScheduled ? tint.opacity(0.35) : OrchardDesign.Colors.offWhite.opacity(0.35)
                HStack(alignment: .center, spacing: Self.waveformBarSpacing) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, height in
                        Capsule()
                            .fill(barColor)
                            .frame(width: barW, height: max(3, height * proxy.size.height))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .frame(minWidth: 120, maxWidth: .infinity)
            .frame(height: Self.waveformHeight)
            .padding(.horizontal, 8)

            VStack(alignment: .center, spacing: 1) {
                Text("1x")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isScheduled ? tint.opacity(0.15) : OrchardDesign.Colors.offWhite.opacity(0.28),
                        in: Capsule()
                    )
                Text(formattedDuration)
                    .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                    .foregroundStyle(isScheduled ? tint : OrchardDesign.Colors.offWhite)
            }
            .padding(.trailing, 10)
        }
        .padding(.vertical, 5)
        .background(
            isScheduled ? AnyShapeStyle(Color.clear) : AnyShapeStyle(tint),
            in: Capsule()
        )
        .overlay {
            if isScheduled {
                Capsule()
                    .stroke(tint, style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round, dash: [5, 5]))
            }
        }
    }
}

// MARK: - Main Threaded Chat View (ChatDetailView)

public struct ChatDetailView: View {
    @Binding public var thread: ChatThread
    public var totalUnreadCount: Int = 0
    public var onStartCall: ((Bool) -> Void)? = nil

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var messageText = ""
    @State private var pendingAttachments: [PendingAttachment] = []
    @State private var showingMediaPicker = false
    @State private var attachmentNotice: String?
    @State private var viewerImage: IdentifiableURL?
    @Namespace private var mediaNamespace
    @Namespace private var bubbleNamespace
    @FocusState private var isComposerFocused: Bool

    // Composer-to-Transcript Send Transition State
    @State private var messageFieldSize: CGSize = .zero
    @State private var activeTransitionIDs: Set<UUID> = []
    @State private var activeTextTransitionID: UUID?
    @State private var activeTextSnapshot = ""
    @State private var activeVoiceTransitionID: UUID?
    @State private var transitioningFitByID: [UUID: Bool] = [:]
    @State private var trayFlightIDByAttachmentID: [UUID: String] = [:]
    @State private var scrollToBottomTrigger = 0

    // Edit, Retry & Tapback Overlay State
    @State private var editingMessage: ChatMessage?
    @State private var editText = ""
    @State private var retryDialogMessage: ChatMessage?
    @State private var reactingMessage: ChatMessage?

    // Inline Voice Recording & Staged Review State
    @State private var isRecordingInline = false
    @State private var recordingElapsed = 0
    @State private var liveWaveformLevels: [Float] = [0.25, 0.55, 0.85, 0.40, 0.95, 0.60, 0.30, 0.75, 0.90, 0.45, 0.65, 0.80]
    @State private var stagedVoiceMemoURL: URL?
    @State private var stagedVoiceMemoDuration: Double = 0
    @State private var isPlayingStagedVoiceMemo = false
    @State private var stagedPlaybackProgress: Double = 0
    @State private var stagedPlayer: AVAudioPlayer?
    @State private var stagedProgressTask: Task<Void, Never>?
    private let inlineRecordTick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Send Later State
    @State private var scheduledSendDate: Date?
    @State private var showingSchedulePicker = false
    @State private var reschedulingRecordID: UUID?

    private let bottomAnchorID = "chat_bottom_anchor"
    @State private var scrollID = UUID()

    private var scheduledAccent: Color { OrchardDesign.Colors.imessageBlue }

    private static let scheduledDashStyle = StrokeStyle(
        lineWidth: 1.75, lineCap: .round, lineJoin: .round, dash: [5, 5]
    )

    private static let scheduledPillFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.doesRelativeDateFormatting = true
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public init(
        thread: Binding<ChatThread>,
        totalUnreadCount: Int = 0,
        onStartCall: ((Bool) -> Void)? = nil
    ) {
        self._thread = thread
        self.totalUnreadCount = totalUnreadCount
        self.onStartCall = onStartCall
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: messageSpacing) {
                    ForEach(thread.messages) { message in
                        messageRow(message)
                    }

                    // Encryption Status Footer
                    HStack(spacing: 4) {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(thread.isMeshOnly ? "Messages Encrypted | Bluetooth" : "Messages Encrypted | P2P")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, OrchardDesign.Spacing.small)

                    Spacer(minLength: 4)
                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorID)
                }
                .padding(.horizontal, chatEdgeInset)
                .padding(.vertical, OrchardDesign.Spacing.small)
            }
            .id(scrollID)
            .defaultScrollAnchor(CommandLine.arguments.contains("-testScrollTop") ? .top : .bottom)
            .textSelection(.enabled)
            .scrollEdgeEffectHidden(true, for: .bottom)
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: thread.messages.count) { _, _ in
                if activeTransitionIDs.isEmpty {
                    withAnimation(OrchardMotion.standard) {
                        proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                    }
                }
            }
            .onChange(of: scrollToBottomTrigger) { _, _ in
                withAnimation(bubbleTransitionAnimation) {
                    proxy.scrollTo(bottomAnchorID, anchor: .bottom)
                }
            }
        }
        .background(OrchardDesign.Colors.background)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                if let attachmentNotice {
                    Text(attachmentNotice)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if scheduledSendDate != nil {
                    scheduledTimePill
                }

                if !pendingAttachments.filter({ $0.kind != .voiceMemo }).isEmpty {
                    attachmentTray
                        .transition(trayFlightIDByAttachmentID.isEmpty ? .opacity : .identity)
                }

                composerInputBar
            }
            .padding(.horizontal, composerBarInset)
            .padding(.vertical, OrchardDesign.Spacing.nano)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .black.opacity(0.35), location: 0.15),
                                .init(color: .black.opacity(0.85), location: 0.32),
                                .init(color: .black, location: 0.48),
                                .init(color: .black, location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea(edges: .bottom)
            }
            .animation(OrchardMotion.snappy, value: pendingAttachments.count)
            .animation(OrchardMotion.snappy, value: canSend)
            .animation(OrchardMotion.snappy, value: scheduledSendDate)
        }
        .sheet(isPresented: $showingSchedulePicker) {
            ScheduleTimePickerSheet(
                date: Binding(
                    get: { scheduledSendDate ?? defaultScheduleDate() },
                    set: { scheduledSendDate = $0 }
                ),
                isEditingExisting: reschedulingRecordID != nil,
                onConfirm: { commitSchedulePick() },
                onCancel: { cancelSchedulePick() }
            )
        }
        .confirmationDialog(
            "This message wasn't delivered.",
            isPresented: Binding(get: { retryDialogMessage != nil }, set: { if !$0 { retryDialogMessage = nil } }),
            titleVisibility: .visible,
            presenting: retryDialogMessage
        ) { message in
            Button("Try Again") {
                if let idx = thread.messages.firstIndex(where: { $0.id == message.id }) {
                    thread.messages[idx].receiptStatus = "delivered"
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Edit Message", isPresented: Binding(
            get: { editingMessage != nil },
            set: { if !$0 { editingMessage = nil } }
        )) {
            TextField("Message", text: $editText)
            Button("Cancel", role: .cancel) { editingMessage = nil }
            Button("Save") {
                if let editing = editingMessage,
                   let idx = thread.messages.firstIndex(where: { $0.id == editing.id }) {
                    let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        thread.messages[idx].text = trimmed
                        thread.messages[idx].isEdited = true
                    }
                }
                editingMessage = nil
            }
        }
        .overlay {
            if let item = viewerImage {
                ChatMediaViewer(
                    urls: item.urls,
                    startIndex: item.startIndex,
                    namespace: mediaNamespace,
                    geometryID: item.id.uuidString,
                    onReply: { isComposerFocused = true }
                ) {
                    viewerImage = nil
                }
                .zIndex(1)
            }
        }
        .overlay {
            if let reacting = reactingMessage {
                reactionOverlay(for: reacting)
            }
        }
        .navigationBarBackButtonHidden(true)
        .restoresSwipeBackGesture()
        .toolbar(.hidden, for: .tabBar)
        .toolbar(viewerImage == nil ? .visible : .hidden, for: .navigationBar)
        .navigationTitle(thread.contactName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CustomBackButton(unreadCount: totalUnreadCount)
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    ZStack {
                        Circle()
                            .fill(Color(uiColor: .systemGray4))
                            .frame(width: 34, height: 34)

                        if thread.isGroup {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                                .foregroundStyle(.white)
                        } else {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(.white)
                        }
                    }
                    .overlay(Circle().stroke(Color(.separator), lineWidth: 1))

                    HStack(spacing: 2) {
                        if thread.isSignalSecured {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                        Text(thread.contactName)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                        if thread.isGroup {
                            Text("(\(thread.participantsCount) people)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button { onStartCall?(true) } label: {
                    Image(systemName: "video.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .disabled(!thread.isSignalSecured)
            }

            ToolbarSpacer(.fixed, placement: .topBarTrailing)

            ToolbarItem(placement: .topBarTrailing) {
                Button { onStartCall?(false) } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .disabled(!thread.isSignalSecured)
            }
        }
        .onAppear {
            if CommandLine.arguments.contains("-testArmedComposer") {
                scheduledSendDate = Calendar.current.date(byAdding: .hour, value: 2, to: Date())
                messageText = "Waypoint rendezvous coordinates confirmed."
            }
            if CommandLine.arguments.contains("-testRecordingBar") {
                isRecordingInline = true
                recordingElapsed = 4
            }
            if CommandLine.arguments.contains("-testStagedReviewBar") {
                stagedVoiceMemoURL = ChatSampleAssetGenerator.sampleVoiceMemoURL(durationSeconds: 16.0)
                stagedVoiceMemoDuration = 16.0
                stagedPlaybackProgress = 0.42
            }
        }
    }

    // MARK: - Message Row Rendering

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        let isVisible = !activeTransitionIDs.contains(message.id)
        let isTransitionTarget = transitioningFitByID[message.id] != nil
        let isFit = transitioningFitByID[message.id] ?? false

        VStack(spacing: 2) {
            if isVisible, let timestamp = message.timestampText {
                Text(timestamp)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, OrchardDesign.Spacing.nano)
            }

            if isVisible, let dividerLabel = transportDividerLabel(for: message) {
                HStack(spacing: 4) {
                    Image(systemName: dividerLabel == "Bluetooth" ? "antenna.radiowaves.left.and.right" : "lock.fill")
                    Text(dividerLabel)
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.vertical, OrchardDesign.Spacing.nano)
            }

            HStack {
                if message.isSender {
                    Spacer()
                    if message.mediaType != nil {
                        if isBatchLeader(message) {
                            VStack(alignment: .trailing, spacing: 2) {
                                ZStack {
                                    if isVisible {
                                        mediaBubbleContent(for: message, isSender: true)
                                    }
                                }
                                .modifier(SendBubbleBounceModifier(
                                    isVisible: isVisible,
                                    offsetAmplitude: max(messageFieldSize.height, 44) * 0.55,
                                    reduceMotion: reduceMotion
                                ))
                                if isVisible {
                                    if let fireDate = message.scheduledDeliveryDate {
                                        Label(Self.scheduledPillFormatter.string(from: fireDate), systemImage: "clock.badge")
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(scheduledAccent)
                                    } else {
                                        deliveryIndicator(for: message)
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 2) {
                            ZStack {
                                if isVisible {
                                    sentTextBubble(for: message, isFit: isFit)
                                        .matchedGeometryEffect(
                                            id: message.id.uuidString,
                                            in: bubbleNamespace,
                                            properties: isFit ? [.position, .size] : [.position]
                                        )
                                }
                            }
                            .fixedSize(horizontal: isFit ? isVisible : false, vertical: true)
                            .modifier(SendBubbleBounceModifier(
                                isVisible: isVisible,
                                offsetAmplitude: max(messageFieldSize.height, 38) * 0.55,
                                reduceMotion: reduceMotion
                            ))
                            .frame(
                                maxWidth: isTransitionTarget && !isFit && messageFieldSize.width > 0
                                    ? min(280, messageFieldSize.width)
                                    : 280,
                                alignment: .trailing
                            )

                            if isVisible {
                                if !message.isDeleted, let link = ChatLinkDetector.firstLink(in: message.text) {
                                    ChatLinkPreview(url: link)
                                        .frame(maxWidth: 280)
                                }
                                if message.isEdited && !message.isDeleted {
                                    Text("Edited")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let fireDate = message.scheduledDeliveryDate {
                                    Label(Self.scheduledPillFormatter.string(from: fireDate), systemImage: "clock.badge")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(scheduledAccent)
                                } else {
                                    deliveryIndicator(for: message)
                                }
                            }
                        }
                    }
                } else {
                    if message.mediaType != nil {
                        if isBatchLeader(message) {
                            mediaBubbleContent(for: message, isSender: false)
                        }
                    } else {
                        receivedTextBubble(for: message)
                    }
                    Spacer()
                }
            }
        }
        .id(message.id)
        .overlay(alignment: message.isSender ? .bottomLeading : .bottomTrailing) {
            if isVisible, !message.reactions.isEmpty {
                reactionPill(for: message)
                    .offset(y: 10)
            }
        }
        .onLongPressGesture(minimumDuration: 0.35) {
            guard !message.isDeleted, message.scheduledDeliveryDate == nil else { return }
            OrchardMotion.perform(.selection, animation: OrchardMotion.snappy) {
                reactingMessage = message
            }
        }
        .contextMenu {
            if message.scheduledDeliveryDate != nil {
                Button {
                    if let idx = thread.messages.firstIndex(where: { $0.id == message.id }) {
                        thread.messages[idx].scheduledDeliveryDate = nil
                        thread.messages[idx].receiptStatus = "sent"
                    }
                } label: {
                    Label("Send Message", systemImage: "paperplane.fill")
                }
                Button {
                    reschedulingRecordID = message.scheduledRecordID ?? message.id
                    scheduledSendDate = message.scheduledDeliveryDate ?? defaultScheduleDate()
                    showingSchedulePicker = true
                } label: {
                    Label("Edit Time", systemImage: "clock")
                }
                Button(role: .destructive) {
                    thread.messages.removeAll { $0.id == message.id }
                } label: {
                    Label("Delete Message", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func sentTextBubble(for message: ChatMessage, isFit: Bool) -> some View {
        outgoingTextBubblePill(
            text: message.text,
            tint: sentBubbleColor(for: message),
            isScheduled: message.scheduledDeliveryDate != nil,
            isDeleted: message.isDeleted,
            isFit: isFit
        )
    }

    @ViewBuilder
    private func outgoingTextBubblePill(
        text: String,
        tint: Color,
        isScheduled: Bool,
        isDeleted: Bool = false,
        isFit: Bool,
        lineLimit: Int? = nil
    ) -> some View {
        Text(text)
            .font(.body)
            .italic(isDeleted)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, bubbleHorizontalPadding)
            .padding(.vertical, bubbleVerticalPadding)
            .frame(maxWidth: isFit ? .infinity : nil, alignment: .leading)
            .background(
                isScheduled
                    ? AnyShapeStyle(Color.clear)
                    : (isDeleted
                        ? AnyShapeStyle(Color(.secondarySystemFill))
                        : AnyShapeStyle(tint)),
                in: .rect(cornerRadius: bubbleCornerRadius, style: .continuous)
            )
            .overlay {
                if isScheduled {
                    RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                        .stroke(scheduledAccent, style: Self.scheduledDashStyle)
                }
            }
            .foregroundStyle(
                isScheduled
                    ? AnyShapeStyle(Color.primary)
                    : (isDeleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.white))
            )
    }

    private func temporaryTextTransitionSource(for transitionID: UUID) -> some View {
        let isFit = transitioningFitByID[transitionID] ?? false
        let message = thread.messages.first(where: { $0.id == transitionID })
        let sourceText = activeTextSnapshot.isEmpty ? (message?.text ?? messageText) : activeTextSnapshot
        let tint = message.map(sentBubbleColor(for:)) ?? defaultOutgoingBubbleColor
        let isScheduled = (message?.scheduledDeliveryDate ?? scheduledSendDate) != nil

        return outgoingTextBubblePill(
            text: sourceText,
            tint: tint,
            isScheduled: isScheduled,
            isFit: isFit,
            lineLimit: 6
        )
        .matchedGeometryEffect(
            id: transitionID.uuidString,
            in: bubbleNamespace,
            properties: isFit ? [.position, .size] : [.position]
        )
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func receivedTextBubble(for message: ChatMessage) -> some View {
        let isThinking = message.text == "Thinking..."
        VStack(alignment: .leading, spacing: 2) {
            Text(message.text)
                .font(.body)
                .italic(message.isDeleted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, bubbleHorizontalPadding)
                .padding(.vertical, bubbleVerticalPadding)
                .background(
                    isThinking ? AnyShapeStyle(.clear) : AnyShapeStyle(Color(.secondarySystemFill)),
                    in: .rect(cornerRadius: bubbleCornerRadius, style: .continuous)
                )
                .foregroundStyle(message.isDeleted ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .overlay {
                    if isThinking {
                        HStack(spacing: 4) {
                            ForEach(0..<3, id: \.self) { _ in
                                Circle().fill(.secondary).frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, bubbleHorizontalPadding)
                        .padding(.vertical, bubbleVerticalPadding)
                        .background(.quaternary, in: .capsule)
                    }
                }
                .frame(maxWidth: 280, alignment: .leading)

            if !message.isDeleted, !isThinking, let link = ChatLinkDetector.firstLink(in: message.text) {
                ChatLinkPreview(url: link)
                    .frame(maxWidth: 280)
            }
            if message.isEdited && !message.isDeleted {
                Text("Edited")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Media Bubble Content

    private func batchMessages(for message: ChatMessage) -> [ChatMessage] {
        guard let batchID = message.sendBatchID else { return [message] }
        return thread.messages.filter { $0.sendBatchID == batchID }
    }

    private func isBatchLeader(_ message: ChatMessage) -> Bool {
        guard let batchID = message.sendBatchID else { return true }
        return thread.messages.first(where: { $0.sendBatchID == batchID })?.id == message.id
    }

    private func isImageMessage(_ message: ChatMessage) -> Bool {
        guard let url = message.mediaFileURL else { return false }
        return ["jpg", "jpeg", "png", "heic", "heif", "gif"].contains(url.pathExtension.lowercased())
    }

    private func isVoiceMessage(_ message: ChatMessage) -> Bool {
        if message.mediaType == "Voice Memo" || message.mediaType == "Voice Note" || message.mediaType == "Walkie-Talkie" {
            return true
        }
        guard let url = message.mediaFileURL else { return false }
        return ["m4a", "mp3", "wav", "caf", "aac"].contains(url.pathExtension.lowercased())
    }

    @ViewBuilder
    private func mediaBubbleContent(for message: ChatMessage, isSender: Bool) -> some View {
        let batch = batchMessages(for: message)
        let imageURLs = batch.compactMap { isImageMessage($0) ? $0.mediaFileURL : nil }
        let isScheduled = isSender && message.scheduledDeliveryDate != nil

        if !imageURLs.isEmpty {
            let heroID = message.id.uuidString
            ImageStackBubble(
                urls: imageURLs,
                isSender: isSender,
                namespace: mediaNamespace,
                geometryID: heroID,
                isHeroSource: viewerImage?.id.uuidString != heroID,
                sendFlightNamespace: isSender ? bubbleNamespace : nil,
                sendFlightID: isSender ? message.id : nil
            ) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewerImage = IdentifiableURL(id: message.id, urls: imageURLs, startIndex: 0)
                }
            }
        } else if isVoiceMessage(message), let url = message.mediaFileURL {
            let bubbleColor = isSender ? sentBubbleColor(for: message) : Color(.secondarySystemFill)
            VoiceMemoPlayerView(
                url: url,
                isSender: isSender,
                tint: isScheduled ? scheduledAccent : bubbleColor,
                isScheduled: isScheduled
            )
                .background(
                    isScheduled ? AnyShapeStyle(Color.clear) : AnyShapeStyle(bubbleColor),
                    in: Capsule()
                )
                .overlay {
                    if isScheduled {
                        Capsule()
                            .stroke(scheduledAccent, style: Self.scheduledDashStyle)
                    }
                }
                .modifier(OptionalMatchedGeometry(
                    id: isSender ? message.id.uuidString : nil,
                    namespace: bubbleNamespace,
                    properties: [.position, .size]
                ))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: mediaCardCornerRadius, style: .continuous)
                        .fill(LinearGradient(
                            colors: [message.mediaColor?.opacity(0.4) ?? .gray, message.mediaColor ?? .gray],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 180, height: 120)
                    Image(systemName: message.mediaIcon ?? "doc")
                        .font(.largeTitle)
                        .foregroundStyle(.primary)
                }
                Text(message.text)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
            }
            .padding(10)
            .background(.quaternary, in: .rect(cornerRadius: bubbleCornerRadius, style: .continuous))
            .modifier(OptionalMatchedGeometry(
                id: isSender ? message.id.uuidString : nil,
                namespace: bubbleNamespace,
                properties: [.position, .size]
            ))
        }
    }

    // MARK: - Transport Colors & Delivery Receipts

    private var defaultOutgoingBubbleColor: Color {
        thread.isMeshOnly ? OrchardDesign.Colors.bluetoothRed : OrchardDesign.Colors.imessageBlue
    }

    private var bubbleTransitionAnimation: Animation {
        .interpolatingSpring(duration: 0.3, bounce: 0, initialVelocity: 0)
    }

    private func resolvedTransport(for message: ChatMessage) -> MessageTransport {
        if let explicit = message.transport { return explicit }
        if message.wasMeshSend == true || thread.isMeshOnly { return .bluetooth }
        return .p2p
    }

    private func sentBubbleColor(for message: ChatMessage) -> Color {
        if message.mediaType == "Walkie-Talkie" { return .cyan }
        switch resolvedTransport(for: message) {
        case .bluetooth: return OrchardDesign.Colors.bluetoothRed
        case .meshcore: return .purple
        case .meshtastic: return .orange
        case .p2p: return OrchardDesign.Colors.imessageBlue
        }
    }

    private func transportDividerLabel(for message: ChatMessage) -> String? {
        guard message.isSender else { return nil }
        let transport = resolvedTransport(for: message)
        let messages = thread.messages
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return nil }
        var priorTransport: MessageTransport? = nil
        var i = idx - 1
        while i >= 0 {
            if messages[i].isSender {
                priorTransport = resolvedTransport(for: messages[i])
                break
            }
            i -= 1
        }
        if priorTransport == nil || priorTransport != transport {
            return transport.rawValue
        }
        return nil
    }

    private var lastSentMessageID: UUID? {
        thread.messages.last(where: {
            $0.isSender && $0.scheduledDeliveryDate == nil && !activeTransitionIDs.contains($0.id)
        })?.id
    }

    @ViewBuilder
    private func deliveryIndicator(for message: ChatMessage) -> some View {
        if message.isSender, message.scheduledDeliveryDate == nil {
            let isLastSent = (message.id == lastSentMessageID)
            let status = message.receiptStatus

            if status == "failed" {
                Button {
                    retryDialogMessage = message
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Not Delivered")
                    }
                    .foregroundStyle(.red)
                    .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.plain)
            } else if status == "seen", let readDate = message.readReceiptDate {
                Text(formatSeenText(for: readDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                    .padding(.trailing, 2)
            } else if isLastSent, let status {
                Text(status.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)
                    .padding(.trailing, 2)
            }
        }
    }

    private func formatSeenText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "h:mm a" : "MM/dd/yy"
        return "Seen \(formatter.string(from: date))"
    }

    // MARK: - Tapbacks & Long-Press Reaction Overlay

    private func reactionPill(for message: ChatMessage) -> some View {
        HStack(spacing: 2) {
            ForEach(Array(message.reactions.suffix(4).enumerated()), id: \.offset) { _, reaction in
                Text(reaction.emoji)
                    .font(.caption)
                    .padding(4)
                    .background(
                        reaction.isFromMe
                            ? AnyShapeStyle(OrchardDesign.Colors.imessageBlue.opacity(0.9))
                            : AnyShapeStyle(.thickMaterial),
                        in: .circle
                    )
            }
        }
        .shadow(radius: 1, y: 1)
    }

    @ViewBuilder
    private func reactionOverlay(for message: ChatMessage) -> some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(OrchardMotion.snappy) { reactingMessage = nil }
                }

            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    ForEach(["❤️", "👍", "👎", "😂", "‼️", "❓"], id: \.self) { emoji in
                        Button {
                            toggleReaction(emoji, on: message)
                        } label: {
                            Text(emoji).font(.title2)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial, in: .capsule)
                .shadow(radius: 8, y: 4)

                Text(message.mediaType ?? message.text)
                    .font(.subheadline)
                    .lineLimit(3)
                    .padding(.horizontal, bubbleHorizontalPadding)
                    .padding(.vertical, bubbleVerticalPadding)
                    .background(
                        message.isSender
                            ? AnyShapeStyle(sentBubbleColor(for: message))
                            : AnyShapeStyle(Color(.secondarySystemFill)),
                        in: .rect(cornerRadius: bubbleCornerRadius, style: .continuous)
                    )
                    .foregroundStyle(message.isSender ? AnyShapeStyle(Color.white) : AnyShapeStyle(.primary))
                    .frame(maxWidth: 280)

                VStack(spacing: 0) {
                    if message.isSender {
                        overlayActionRow("Edit", systemImage: "pencil") {
                            editingMessage = message
                            editText = message.text
                        }
                        Divider()
                    }
                    overlayActionRow("Delete", systemImage: "trash", role: .destructive) {
                        if let idx = thread.messages.firstIndex(where: { $0.id == message.id }) {
                            thread.messages[idx].isDeleted = true
                            thread.messages[idx].text = "This message was deleted"
                        }
                    }
                    Divider()
                    overlayActionRow("Copy", systemImage: "doc.on.doc") {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = message.text
                        #endif
                    }
                }
                .background(.regularMaterial, in: .rect(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: 260)
                .shadow(radius: 8, y: 4)
            }
            .padding()
        }
        .transition(.opacity)
    }

    private func overlayActionRow(_ title: String, systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role) {
            action()
            withAnimation(OrchardMotion.snappy) { reactingMessage = nil }
        } label: {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: systemImage)
            }
            .font(.body)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(role == .destructive ? AnyShapeStyle(.red) : AnyShapeStyle(.primary))
    }

    private func toggleReaction(_ emoji: String, on message: ChatMessage) {
        withAnimation(OrchardMotion.snappy) { reactingMessage = nil }
        guard let idx = thread.messages.firstIndex(where: { $0.id == message.id }) else { return }
        let reaction = MessageReaction(emoji: emoji, isFromMe: true)
        if let existing = thread.messages[idx].reactions.firstIndex(of: reaction) {
            thread.messages[idx].reactions.remove(at: existing)
        } else {
            thread.messages[idx].reactions.append(reaction)
        }
    }

    // MARK: - Composer Bar, Scheduled Pill, Media Tray & Inline Voice Bars

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty || !pendingAttachments.isEmpty || stagedVoiceMemoURL != nil
    }

    private func defaultScheduleDate() -> Date {
        let target = Date().addingTimeInterval(3600)
        let interval: TimeInterval = 300
        return Date(timeIntervalSinceReferenceDate:
            (target.timeIntervalSinceReferenceDate / interval).rounded(.up) * interval)
    }

    private func commitSchedulePick() {
        guard let date = scheduledSendDate else { return }
        if let recordID = reschedulingRecordID {
            for index in thread.messages.indices where (thread.messages[index].scheduledRecordID == recordID || thread.messages[index].id == recordID) {
                thread.messages[index].scheduledDeliveryDate = date
            }
            reschedulingRecordID = nil
            scheduledSendDate = nil
        }
        OrchardMotion.HapticStyle.success.fire()
    }

    private func cancelSchedulePick() {
        if reschedulingRecordID != nil {
            reschedulingRecordID = nil
            scheduledSendDate = nil
        }
    }

    private var scheduledTimePill: some View {
        HStack(spacing: 0) {
            Button {
                OrchardMotion.HapticStyle.selection.fire()
                reschedulingRecordID = nil
                showingSchedulePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                    Text(Self.scheduledPillFormatter.string(from: scheduledSendDate ?? .now))
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.7)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(scheduledAccent)
                .padding(.leading, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            Button {
                OrchardMotion.perform(.light) { scheduledSendDate = nil }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(scheduledAccent)
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.trailing, 2)
        .background(scheduledAccent.opacity(0.12), in: Capsule())
        .overlay(Capsule().stroke(scheduledAccent.opacity(0.4), lineWidth: 1))
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.scale.combined(with: .opacity))
    }

    private var attachmentTray: some View {
        let nonVoice = pendingAttachments.filter { $0.kind != .voiceMemo }
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(nonVoice.enumerated()), id: \.element.id) { index, attachment in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let thumb = attachment.thumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                ZStack {
                                    Rectangle().fill(.quaternary)
                                    Image(systemName: attachment.icon)
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .modifier(OptionalMatchedGeometry(
                            id: trayFlightIDByAttachmentID[attachment.id],
                            namespace: bubbleNamespace,
                            properties: [.position, .size]
                        ))
                        .padding(.top, 6)
                        .padding(.trailing, 6)

                        if trayFlightIDByAttachmentID.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                                    pendingAttachments.removeAll { $0.id == attachment.id }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, Color.black.opacity(0.65))
                                    .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 62, height: 62)
                    .zIndex(Double(index))
                    .transition(
                        trayFlightIDByAttachmentID.isEmpty
                            ? .asymmetric(
                                insertion: .scale(scale: 0.8, anchor: .center)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(x: 12)),
                                removal: .scale(scale: 0.8, anchor: .center)
                                    .combined(with: .opacity)
                            )
                            : .identity
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
        .frame(height: 64)
    }

    private var composerInputBar: some View {
        HStack(alignment: .bottom, spacing: composerControlSpacing) {
            if isRecordingInline {
                inlineRecordingBar
            } else if let voiceMemoURL = stagedVoiceMemoURL {
                stagedVoiceMemoBar(url: voiceMemoURL)
                    .transition(activeVoiceTransitionID == nil ? .opacity : .identity)
            } else {
                Menu {
                    Button {
                        let urls = ChatSampleAssetGenerator.samplePhotoURLs()
                        if let first = urls.first, let data = try? Data(contentsOf: first), let img = UIImage(data: data) {
                            withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                                pendingAttachments.append(PendingAttachment(kind: .image, fileURL: first, thumbnail: img))
                            }
                        }
                    } label: {
                        Label("Photos", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        recordingElapsed = 0
                        withAnimation(OrchardMotion.snappy) { isRecordingInline = true }
                    } label: {
                        Label("Voice Memo", systemImage: "waveform")
                    }

                    Button {
                        reschedulingRecordID = nil
                        scheduledSendDate = scheduledSendDate ?? defaultScheduleDate()
                        showingSchedulePicker = true
                    } label: {
                        Label("Send Later", systemImage: "clock.arrow.circlepath")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(OrchardDesign.Colors.imessageBlue)
                        .frame(width: composerButtonDiameter, height: composerButtonDiameter)
                        .background(colorScheme == .light ? Color(uiColor: .systemGray6) : Color.clear, in: Circle())
                        .glassEffect(.clear.interactive(), in: Circle())
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1.5)
                }
                .keepsKeyboardActiveOnTap()
                .frame(width: OrchardDesign.Spacing.minimumTouchTarget, height: OrchardDesign.Spacing.minimumTouchTarget)
                .contentShape(Circle())

                HStack(alignment: .bottom, spacing: 0) {
                    TextField(
                        !pendingAttachments.isEmpty ? "Add comment or Send" : "Message",
                        text: $messageText,
                        axis: .vertical
                    )
                    .font(.body)
                    .focused($isComposerFocused)
                    .lineLimit(1...6)
                    .submitLabel(.send)
                    .onSubmit {
                        guard activeTransitionIDs.isEmpty else { return }
                        sendComposed()
                    }
                    .opacity(activeTextTransitionID == nil ? 1 : 0)
                    .padding(.horizontal, bubbleHorizontalPadding)
                    .padding(.vertical, bubbleVerticalPadding)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { newSize in
                        messageFieldSize = newSize
                    }
                    .overlay(alignment: .topLeading) {
                        if let textTransitionID = activeTextTransitionID {
                            temporaryTextTransitionSource(for: textTransitionID)
                        }
                    }

                    if !canSend {
                        Button {
                            recordingElapsed = 0
                            withAnimation(OrchardMotion.snappy) { isRecordingInline = true }
                        } label: {
                            Image(systemName: "waveform")
                                .foregroundStyle(OrchardDesign.Colors.bluetoothRed)
                                .frame(
                                    width: OrchardDesign.Spacing.minimumTouchTarget,
                                    height: OrchardDesign.Spacing.minimumTouchTarget
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .keepsKeyboardActiveOnTap()
                        .padding(.trailing, 2)
                    }
                }
                .frame(minHeight: OrchardDesign.Spacing.minimumTouchTarget)
                .background(
                    colorScheme == .light ? Color(uiColor: .systemGray6).opacity(0.85) : Color.clear,
                    in: scheduledSendDate == nil
                        ? AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        : AnyShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
                )
                .glassEffect(
                    .clear,
                    in: scheduledSendDate == nil
                        ? AnyShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        : AnyShape(RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous))
                )
                .overlay {
                    if scheduledSendDate == nil {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    } else {
                        RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
                            .stroke(scheduledAccent, style: Self.scheduledDashStyle)
                    }
                }
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                if canSend {
                    Button {
                        guard activeTransitionIDs.isEmpty else { return }
                        sendComposed()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(OrchardDesign.Colors.imessageBlue)
                            .frame(
                                width: OrchardDesign.Spacing.minimumTouchTarget,
                                height: OrchardDesign.Spacing.minimumTouchTarget
                            )
                            .contentShape(Circle())
                    }
                    .disabled(!activeTransitionIDs.isEmpty)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(OrchardMotion.snappy, value: canSend)
        .animation(OrchardMotion.snappy, value: isRecordingInline)
        .animation(OrchardMotion.snappy, value: stagedVoiceMemoURL)
    }

    // MARK: - Inline Voice Recording & Staged Review Bars

    private var inlineRecordingBar: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(OrchardMotion.snappy) {
                    isRecordingInline = false
                    recordingElapsed = 0
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                    .frame(width: 38, height: 38)
                    .background(colorScheme == .light ? Color(uiColor: .systemGray6) : Color.clear, in: Circle())
                    .glassEffect(.clear.interactive(), in: Circle())
                    .overlay(Circle().strokeBorder(colorScheme == .dark ? Color.white.opacity(0.18) : Color.primary.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel recording")

            HStack(spacing: 8) {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(0.9)
                LiveWaveformView(levels: liveWaveformLevels, tint: OrchardDesign.Colors.bluetoothRed)
                    .frame(maxWidth: .infinity)
                Text(String(format: "%d:%02d", recordingElapsed / 60, recordingElapsed % 60))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(colorScheme == .light ? Color(uiColor: .systemGray6).opacity(0.85) : Color.clear, in: Capsule())
            .glassEffect(.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(colorScheme == .dark ? Color.white.opacity(0.18) : Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)

            Button {
                let recordedDuration = max(1, Double(recordingElapsed))
                let url = ChatSampleAssetGenerator.sampleVoiceMemoURL(durationSeconds: recordedDuration)
                withAnimation(OrchardMotion.snappy) {
                    isRecordingInline = false
                    stagedVoiceMemoURL = url
                    stagedVoiceMemoDuration = recordedDuration
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 34, height: 34)
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop and review recording")
        }
        .onReceive(inlineRecordTick) { _ in
            guard isRecordingInline else { return }
            recordingElapsed += 1
            liveWaveformLevels.append(Float.random(in: 0.2...0.95))
            if liveWaveformLevels.count > 24 {
                liveWaveformLevels.removeFirst()
            }
        }
    }

    private func stagedVoiceMemoBar(url: URL) -> some View {
        HStack(spacing: 8) {
            Button {
                stopStagedVoiceMemoPlayback()
                withAnimation(OrchardMotion.snappy) {
                    stagedVoiceMemoURL = nil
                    stagedVoiceMemoDuration = 0
                    stagedPlaybackProgress = 0
                }
                OrchardMotion.perform(.light) {}
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                    .frame(width: 38, height: 38)
                    .background(colorScheme == .light ? Color(uiColor: .systemGray6) : Color.clear, in: Circle())
                    .glassEffect(.clear.interactive(), in: Circle())
                    .overlay(Circle().strokeBorder(colorScheme == .dark ? Color.white.opacity(0.18) : Color.primary.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1.5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Discard voice memo")

            HStack(spacing: 8) {
                Button {
                    toggleStagedVoiceMemoPlayback(url: url)
                } label: {
                    ZStack {
                        Circle()
                            .fill(colorScheme == .dark ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
                            .frame(width: 32, height: 32)
                        Image(systemName: isPlayingStagedVoiceMemo ? "pause.fill" : "play.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                            .offset(x: isPlayingStagedVoiceMemo ? 0 : 1)
                    }
                }
                .buttonStyle(.plain)

                StagedWaveformScrubber(
                    url: url,
                    isPlaying: isPlayingStagedVoiceMemo,
                    player: stagedPlayer,
                    onSeek: { fraction in
                        let clamped = min(max(fraction, 0), 1)
                        stagedPlaybackProgress = clamped
                        stagedPlayer?.currentTime = clamped * (stagedPlayer?.duration ?? stagedVoiceMemoDuration)
                        OrchardMotion.HapticStyle.selection.fire()
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: 24)

                let total = max(1, Int(stagedVoiceMemoDuration.rounded()))
                Text(String(format: "+ %d:%02d", total / 60, total % 60))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white : Color.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(colorScheme == .dark ? Color.white.opacity(0.18) : Color.primary.opacity(0.08)))

                Button {
                    guard activeTransitionIDs.isEmpty else { return }
                    sendStagedVoiceMemo(url: url)
                } label: {
                    ZStack {
                        Circle()
                            .fill(OrchardDesign.Colors.imessageBlue)
                            .frame(width: 32, height: 32)
                        Image(systemName: "arrow.up")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(!activeTransitionIDs.isEmpty)
                .buttonStyle(.plain)
                .accessibilityLabel("Send voice memo")
            }
            .padding(.leading, 6)
            .padding(.trailing, 6)
            .padding(.vertical, 5)
            .frame(minHeight: OrchardDesign.Spacing.minimumTouchTarget)
            .background(colorScheme == .light ? Color(uiColor: .systemGray6).opacity(0.85) : Color.clear, in: Capsule())
            .glassEffect(.clear, in: Capsule())
            .overlay(Capsule().strokeBorder(colorScheme == .dark ? Color.white.opacity(0.18) : Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
            .opacity(activeVoiceTransitionID == nil ? 1 : 0)
            .overlay {
                if let voiceTransitionID = activeVoiceTransitionID {
                    VoiceBubbleTransitionPreview(
                        url: url,
                        tint: voiceBubbleTint(for: voiceTransitionID),
                        duration: stagedVoiceMemoDuration,
                        isScheduled: scheduledSendDate != nil
                    )
                    .matchedGeometryEffect(
                        id: voiceTransitionID.uuidString,
                        in: bubbleNamespace,
                        properties: [.position, .size]
                    )
                }
            }
        }
        .onDisappear {
            stopStagedVoiceMemoPlayback()
        }
    }

    private func toggleStagedVoiceMemoPlayback(url: URL) {
        if isPlayingStagedVoiceMemo {
            stagedPlayer?.pause()
            isPlayingStagedVoiceMemo = false
            stagedProgressTask?.cancel()
            stagedProgressTask = nil
        } else {
            if stagedPlayer == nil {
                stagedPlayer = try? AVAudioPlayer(contentsOf: url)
                stagedPlayer?.prepareToPlay()
            }
            guard let player = stagedPlayer else { return }
            player.play()
            isPlayingStagedVoiceMemo = true
            stagedProgressTask?.cancel()
            stagedProgressTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard let p = stagedPlayer else { break }
                    if !p.isPlaying {
                        isPlayingStagedVoiceMemo = false
                        break
                    }
                }
            }
        }
    }

    private func stopStagedVoiceMemoPlayback() {
        stagedPlayer?.stop()
        stagedPlayer = nil
        isPlayingStagedVoiceMemo = false
        stagedProgressTask?.cancel()
        stagedProgressTask = nil
    }

    private func voiceBubbleTint(for messageID: UUID) -> Color {
        if let message = thread.messages.first(where: { $0.id == messageID }) {
            return message.scheduledDeliveryDate != nil ? scheduledAccent : sentBubbleColor(for: message)
        }
        return scheduledSendDate != nil ? scheduledAccent : defaultOutgoingBubbleColor
    }

    private func isTextSingleLineFit(_ text: String) -> Bool {
        guard !text.contains("\n") else { return false }
        let fieldWidth = messageFieldSize.width > 0 ? messageFieldSize.width : 280
        let availableTextWidth = max(0, min(280, fieldWidth) - bubbleHorizontalPadding * 2 - 4)
        #if canImport(UIKit)
        let width = (text as NSString).size(withAttributes: [
            .font: UIFont.preferredFont(forTextStyle: .body)
        ]).width
        return width < availableTextWidth
        #else
        return false
        #endif
    }

    private func runSendTransition(
        transitionIDs: Set<UUID>,
        fitMap: [UUID: Bool],
        textTransitionID: UUID?,
        voiceTransitionID: UUID?,
        trayFlights: [UUID: String],
        clearComposer: @escaping @MainActor () -> Void
    ) {
        if reduceMotion || transitionIDs.isEmpty {
            withAnimation(OrchardMotion.snappy) {
                clearComposer()
                activeTextSnapshot = ""
                scrollToBottomTrigger += 1
            }
            return
        }

        transitioningFitByID.merge(fitMap) { _, new in new }
        activeTextTransitionID = textTransitionID
        activeVoiceTransitionID = voiceTransitionID
        trayFlightIDByAttachmentID = trayFlights
        activeTransitionIDs.formUnion(transitionIDs)

        let batchIDs = transitionIDs
        let capturedVoiceID = voiceTransitionID
        let capturedTrayIDs = Array(trayFlights.keys)
        DispatchQueue.main.async {
            withAnimation(bubbleTransitionAnimation, completionCriteria: .removed) {
                clearComposer()
                activeTransitionIDs.subtract(batchIDs)
                activeTextTransitionID = nil
                scrollToBottomTrigger += 1
            } completion: {
                if activeTextTransitionID == nil {
                    activeTextSnapshot = ""
                }
                if activeVoiceTransitionID == capturedVoiceID {
                    activeVoiceTransitionID = nil
                }
                for key in capturedTrayIDs {
                    trayFlightIDByAttachmentID.removeValue(forKey: key)
                }
                for id in batchIDs {
                    transitioningFitByID.removeValue(forKey: id)
                }
            }
        }
    }

    private func sendStagedVoiceMemo(url: URL) {
        guard activeTransitionIDs.isEmpty else { return }
        stopStagedVoiceMemoPlayback()

        let voiceMessageID = UUID()
        let isScheduled = scheduledSendDate != nil
        let msg = ChatMessage(
            id: voiceMessageID,
            text: "Voice Memo",
            isSender: true,
            mediaType: "Voice Memo",
            mediaFileURL: url,
            wasMeshSend: thread.isMeshOnly,
            transport: thread.isMeshOnly ? .bluetooth : .p2p,
            scheduledDeliveryDate: scheduledSendDate,
            scheduledRecordID: isScheduled ? UUID() : nil,
            receiptStatus: isScheduled ? nil : "sent"
        )
        thread.messages.append(msg)
        thread.lastMessage = "Voice Memo"
        thread.timestamp = "Now"

        runSendTransition(
            transitionIDs: [voiceMessageID],
            fitMap: [:],
            textTransitionID: nil,
            voiceTransitionID: voiceMessageID,
            trayFlights: [:]
        ) {
            stagedVoiceMemoURL = nil
            stagedVoiceMemoDuration = 0
            stagedPlaybackProgress = 0
            scheduledSendDate = nil
        }
        OrchardMotion.HapticStyle.light.fire()
    }

    private func sendComposed() {
        guard activeTransitionIDs.isEmpty else { return }
        if let voiceMemoURL = stagedVoiceMemoURL {
            sendStagedVoiceMemo(url: voiceMemoURL)
            return
        }

        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !pendingAttachments.isEmpty else { return }

        var transitionIDs: Set<UUID> = []
        var fitMap: [UUID: Bool] = [:]
        var textTransitionID: UUID?
        var trayFlights: [UUID: String] = [:]
        let isScheduled = scheduledSendDate != nil
        let sharedScheduleRecordID = isScheduled ? UUID() : nil
        let stagedAttachments = pendingAttachments

        if !stagedAttachments.isEmpty {
            let batchID = UUID()
            let imageLeadID = UUID()
            var imageIndex = 0

            for attachment in stagedAttachments {
                if let url = attachment.fileURL {
                    let isImage = attachment.kind == .image
                    let msgID: UUID = (isImage && imageIndex == 0) ? imageLeadID : UUID()

                    if isImage {
                        if let thumb = attachment.thumbnail {
                            DiskImageThumbnail.prewarmPreview(thumb, for: url)
                        }
                        if imageIndex < 3 {
                            trayFlights[attachment.id] = imageIndex == 0
                                ? imageLeadID.uuidString
                                : "\(imageLeadID.uuidString)-card-\(imageIndex)"
                        }
                        if imageIndex == 0 {
                            transitionIDs.insert(imageLeadID)
                        }
                        imageIndex += 1
                    } else {
                        transitionIDs.insert(msgID)
                        trayFlights[attachment.id] = msgID.uuidString
                    }

                    let msg = ChatMessage(
                        id: msgID,
                        text: trimmed.isEmpty ? "Photo" : trimmed,
                        isSender: true,
                        mediaType: "Photo",
                        mediaFileURL: url,
                        wasMeshSend: thread.isMeshOnly,
                        transport: thread.isMeshOnly ? .bluetooth : .p2p,
                        sendBatchID: batchID,
                        scheduledDeliveryDate: scheduledSendDate,
                        scheduledRecordID: sharedScheduleRecordID,
                        receiptStatus: isScheduled ? nil : "sent"
                    )
                    thread.messages.append(msg)
                    thread.lastMessage = trimmed.isEmpty ? "Photo" : trimmed
                    thread.timestamp = "Now"
                }
            }
        }

        if !trimmed.isEmpty {
            let textMsgID = UUID()
            let isFit = isTextSingleLineFit(trimmed)
            activeTextSnapshot = trimmed
            let msg = ChatMessage(
                id: textMsgID,
                text: trimmed,
                isSender: true,
                wasMeshSend: thread.isMeshOnly,
                transport: thread.isMeshOnly ? .bluetooth : .p2p,
                scheduledDeliveryDate: scheduledSendDate,
                scheduledRecordID: sharedScheduleRecordID,
                receiptStatus: isScheduled ? nil : "sent"
            )
            thread.messages.append(msg)
            thread.lastMessage = trimmed
            thread.timestamp = "Now"
            transitionIDs.insert(textMsgID)
            fitMap[textMsgID] = isFit
            textTransitionID = textMsgID
        }

        runSendTransition(
            transitionIDs: transitionIDs,
            fitMap: fitMap,
            textTransitionID: textTransitionID,
            voiceTransitionID: nil,
            trayFlights: trayFlights
        ) {
            messageText = ""
            pendingAttachments.removeAll()
            scheduledSendDate = nil
        }
        OrchardMotion.HapticStyle.light.fire()
    }
}
