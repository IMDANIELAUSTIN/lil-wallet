import SwiftUI
import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

public struct MessageReaction: Codable, Hashable, Sendable {
    public let emoji: String
    public let isFromMe: Bool

    public init(emoji: String, isFromMe: Bool) {
        self.emoji = emoji
        self.isFromMe = isFromMe
    }
}

public enum MessageTransport: String, Codable, Hashable, Sendable {
    case p2p = "P2P"
    case bluetooth = "Bluetooth"
    case meshcore = "MeshCore"
    case meshtastic = "Meshtastic"
}

public enum MessageDeliveryPhase: Hashable, Sendable {
    case queued
    case sentMesh
    case sentRelay
    case delivered
    case seen(date: Date)
    case failed
}

public struct ChatMessage: Identifiable, Hashable {
    public var id: UUID
    public var text: String
    public let isSender: Bool
    public var timestampText: String?
    public var mediaType: String?
    public var mediaColor: Color?
    public var mediaIcon: String?
    public var mediaFileURL: URL?
    public var packetID: UUID?
    public var isDeleted: Bool
    public var isEdited: Bool
    public var wasMeshSend: Bool?
    public var transport: MessageTransport?
    /// Shared across photos sent in a single batch so they collapse into one `ImageStackBubble`.
    public var sendBatchID: UUID?
    public var reactions: [MessageReaction]
    /// Non-nil while the message is a pending "Send Later" scheduled draft.
    public var scheduledDeliveryDate: Date?
    public var scheduledRecordID: UUID?
    /// "sent", "delivered", "seen", or "failed"
    public var receiptStatus: String?
    public var readReceiptDate: Date?

    public init(
        id: UUID = UUID(),
        text: String,
        isSender: Bool,
        timestampText: String? = nil,
        mediaType: String? = nil,
        mediaColor: Color? = nil,
        mediaIcon: String? = nil,
        mediaFileURL: URL? = nil,
        packetID: UUID? = nil,
        isDeleted: Bool = false,
        isEdited: Bool = false,
        wasMeshSend: Bool? = nil,
        transport: MessageTransport? = nil,
        sendBatchID: UUID? = nil,
        reactions: [MessageReaction] = [],
        scheduledDeliveryDate: Date? = nil,
        scheduledRecordID: UUID? = nil,
        receiptStatus: String? = "sent",
        readReceiptDate: Date? = nil
    ) {
        self.id = id
        self.text = text
        self.isSender = isSender
        self.timestampText = timestampText
        self.mediaType = mediaType
        self.mediaColor = mediaColor
        self.mediaIcon = mediaIcon
        self.mediaFileURL = mediaFileURL
        self.packetID = packetID
        self.isDeleted = isDeleted
        self.isEdited = isEdited
        self.wasMeshSend = wasMeshSend
        self.transport = transport
        self.sendBatchID = sendBatchID
        self.reactions = reactions
        self.scheduledDeliveryDate = scheduledDeliveryDate
        self.scheduledRecordID = scheduledRecordID
        self.receiptStatus = receiptStatus
        self.readReceiptDate = readReceiptDate
    }
}

public struct ChatThread: Identifiable, Hashable {
    public let id: UUID
    public var contactName: String
    public var contactHandle: String
    public var avatarText: String
    public var avatarSystemImage: String?
    public var lastMessage: String
    public var timestamp: String
    public var messages: [ChatMessage]
    public var isPinned: Bool
    public var isGroup: Bool
    public var participantsCount: Int
    public var isMeshOnly: Bool
    public var isSignalSecured: Bool
    public var unreadCount: Int

    public init(
        id: UUID = UUID(),
        contactName: String,
        contactHandle: String,
        avatarText: String = "",
        avatarSystemImage: String? = nil,
        lastMessage: String = "",
        timestamp: String = "Now",
        messages: [ChatMessage] = [],
        isPinned: Bool = false,
        isGroup: Bool = false,
        participantsCount: Int = 1,
        isMeshOnly: Bool = false,
        isSignalSecured: Bool = true,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.contactName = contactName
        self.contactHandle = contactHandle
        self.avatarText = avatarText.isEmpty ? String(contactName.prefix(2)).uppercased() : avatarText
        self.avatarSystemImage = avatarSystemImage
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.messages = messages
        self.isPinned = isPinned
        self.isGroup = isGroup
        self.participantsCount = participantsCount
        self.isMeshOnly = isMeshOnly
        self.isSignalSecured = isSignalSecured
        self.unreadCount = unreadCount
    }
}

public struct PendingAttachment: Identifiable {
    public enum Kind { case image, voiceMemo, location }
    public let id = UUID()
    public let kind: Kind
    public var fileURL: URL?
    public var thumbnail: UIImage?
    public var locationLink: String?
    public var byteSize: Int = 0

    public var icon: String {
        switch kind {
        case .image: return "photo.fill"
        case .voiceMemo: return "waveform"
        case .location: return "mappin.and.ellipse"
        }
    }

    public init(
        kind: Kind,
        fileURL: URL? = nil,
        thumbnail: UIImage? = nil,
        locationLink: String? = nil,
        byteSize: Int = 0
    ) {
        self.kind = kind
        self.fileURL = fileURL
        self.thumbnail = thumbnail
        self.locationLink = locationLink
        self.byteSize = byteSize
    }
}

// MARK: - Sample Seed Generator (Real Disk Assets for Preview & Verification)

@MainActor
public enum ChatSampleAssetGenerator {
    private static var cachedPhotoURLs: [URL]?
    private static var cachedVoiceMemoURL: URL?

    public static func samplePhotoURLs() -> [URL] {
        if let existing = cachedPhotoURLs, existing.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) {
            return existing
        }

        let specs: [(name: String, title: String, subtitle: String, colors: [UIColor], symbol: String)] = [
            (
                "orchard_sample_photo_1.png",
                "Ridge Topo Survey",
                "37.3346° N, 122.0090° W",
                [UIColor(red: 0.08, green: 0.35, blue: 0.68, alpha: 1), UIColor(red: 0.14, green: 0.62, blue: 0.85, alpha: 1)],
                "mountain.2.fill"
            ),
            (
                "orchard_sample_photo_2.png",
                "Sector B Relay Node",
                "Mesh Signal +14 dBm",
                [UIColor(red: 0.85, green: 0.24, blue: 0.22, alpha: 1), UIColor(red: 0.96, green: 0.55, blue: 0.24, alpha: 1)],
                "antenna.radiowaves.left.and.right"
            ),
            (
                "orchard_sample_photo_3.png",
                "Solar Array Telemetry",
                "Battery Bank 98%",
                [UIColor(red: 0.15, green: 0.58, blue: 0.42, alpha: 1), UIColor(red: 0.32, green: 0.78, blue: 0.56, alpha: 1)],
                "sun.max.fill"
            )
        ]

        let size = CGSize(width: 540, height: 720)
        var urls: [URL] = []

        for spec in specs {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(spec.name)
            if !FileManager.default.fileExists(atPath: url.path) {
                let renderer = UIGraphicsImageRenderer(size: size)
                let img = renderer.image { ctx in
                    let cgCtx = ctx.cgContext
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let cgColors = spec.colors.map { $0.cgColor } as CFArray
                    if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0.0, 1.0]) {
                        cgCtx.drawLinearGradient(
                            gradient,
                            start: .zero,
                            end: CGPoint(x: size.width, y: size.height),
                            options: []
                        )
                    }

                    // Subtle grid lines
                    UIColor.white.withAlphaComponent(0.12).setStroke()
                    for y in stride(from: CGFloat(60), to: size.height, by: 60) {
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        path.lineWidth = 1
                        path.stroke()
                    }

                    // Center symbol
                    let config = UIImage.SymbolConfiguration(pointSize: 110, weight: .semibold)
                    if let symbolImg = UIImage(systemName: spec.symbol, withConfiguration: config)?
                        .withTintColor(.white.withAlphaComponent(0.9), renderingMode: .alwaysOriginal) {
                        let symOrigin = CGPoint(
                            x: (size.width - symbolImg.size.width) / 2,
                            y: (size.height - symbolImg.size.height) / 2 - 40
                        )
                        symbolImg.draw(at: symOrigin)
                    }

                    // Caption text
                    let paragraph = NSMutableParagraphStyle()
                    paragraph.alignment = .left
                    let titleAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                        .foregroundColor: UIColor.white,
                        .paragraphStyle: paragraph
                    ]
                    let subAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .medium),
                        .foregroundColor: UIColor.white.withAlphaComponent(0.85),
                        .paragraphStyle: paragraph
                    ]
                    (spec.title as NSString).draw(in: CGRect(x: 36, y: size.height - 130, width: size.width - 72, height: 44), withAttributes: titleAttrs)
                    (spec.subtitle as NSString).draw(in: CGRect(x: 36, y: size.height - 82, width: size.width - 72, height: 32), withAttributes: subAttrs)
                }
                if let data = img.pngData() {
                    try? data.write(to: url, options: .atomic)
                }
            }
            urls.append(url)
        }

        cachedPhotoURLs = urls
        return urls
    }

    public static func sampleVoiceMemoURL(durationSeconds: Double = 10.0) -> URL {
        if let existing = cachedVoiceMemoURL, FileManager.default.fileExists(atPath: existing.path) {
            return existing
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("orchard_sample_voice_memo.wav")
        if !FileManager.default.fileExists(atPath: url.path) {
            let sampleRate: Double = 22050
            let totalFrames = AVAudioFrameCount(sampleRate * durationSeconds)
            if let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
               let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) {
                buffer.frameLength = totalFrames
                if let channel = buffer.floatChannelData?[0] {
                    let envelope: [Float] = [
                        0.22, 0.45, 0.78, 0.95, 0.62, 0.35, 0.88, 0.74, 0.40,
                        0.92, 0.66, 0.30, 0.55, 0.82, 0.98, 0.70, 0.44, 0.60,
                        0.85, 0.50, 0.28, 0.76, 0.90, 0.64, 0.38, 0.72, 0.84,
                        0.52, 0.32, 0.68, 0.94, 0.77, 0.48, 0.62, 0.40, 0.25
                    ]
                    for i in 0..<Int(totalFrames) {
                        let progress = Double(i) / Double(totalFrames)
                        let envIdx = min(Int(progress * Double(envelope.count)), envelope.count - 1)
                        let amp = envelope[envIdx] * 0.5
                        let carrier = Float(sin(2.0 * .pi * 440.0 * Double(i) / sampleRate))
                        channel[i] = amp * carrier
                    }
                }
                if let audioFile = try? AVAudioFile(forWriting: url, settings: format.settings) {
                    try? audioFile.write(from: buffer)
                }
            }
        }

        cachedVoiceMemoURL = url
        return url
    }
}

public extension ChatThread {
    @MainActor
    static func sampleThread(contactName: String = "Contact Name", unreadCount: Int = 3) -> ChatThread {
        let photoURLs = ChatSampleAssetGenerator.samplePhotoURLs()
        let voiceURL = ChatSampleAssetGenerator.sampleVoiceMemoURL(durationSeconds: 10.0)
        let batchID = UUID()
        let now = Date()

        let messages: [ChatMessage] = [
            ChatMessage(
                text: "Thinking...",
                isSender: false
            ),
            ChatMessage(
                text: "Confirming secure peer-to-peer session over local mesh.",
                isSender: true,
                transport: .p2p,
                receiptStatus: "delivered"
            ),
            ChatMessage(
                text: "Signal verified! Ready to transmit packet payload.",
                isSender: false,
                reactions: [MessageReaction(emoji: "❤️", isFromMe: false)]
            ),
            ChatMessage(
                text: "Switching channel to Bluetooth Mesh off-grid protocol.",
                isSender: true,
                wasMeshSend: true,
                transport: .bluetooth,
                reactions: [MessageReaction(emoji: "👍", isFromMe: true)],
                receiptStatus: "seen",
                readReceiptDate: Calendar.current.date(byAdding: .minute, value: -28, to: now)
            ),
            ChatMessage(
                text: "Voice Memo",
                isSender: true,
                mediaType: "Voice Memo",
                mediaFileURL: voiceURL,
                wasMeshSend: true,
                transport: .bluetooth,
                receiptStatus: "delivered"
            ),
            ChatMessage(
                text: "Ridge Topo Survey",
                isSender: true,
                mediaType: "Photo",
                mediaFileURL: photoURLs[0],
                transport: .p2p,
                sendBatchID: batchID,
                receiptStatus: "delivered"
            ),
            ChatMessage(
                text: "Sector B Relay Node",
                isSender: true,
                mediaType: "Photo",
                mediaFileURL: photoURLs[1],
                transport: .p2p,
                sendBatchID: batchID,
                receiptStatus: "delivered"
            ),
            ChatMessage(
                text: "Solar Array Telemetry",
                isSender: true,
                mediaType: "Photo",
                mediaFileURL: photoURLs[2],
                transport: .p2p,
                sendBatchID: batchID,
                receiptStatus: "delivered"
            ),
            ChatMessage(
                text: "Meeting at Cupertino rendezvous point: https://maps.apple.com/?q=Cupertino",
                isSender: false
            ),
            ChatMessage(
                text: "Scheduled rendezvous check-in at beacon waypoint.",
                isSender: true,
                transport: .p2p,
                scheduledDeliveryDate: Calendar.current.date(byAdding: .hour, value: 3, to: now),
                scheduledRecordID: UUID()
            ),
            ChatMessage(
                text: "Failed burst packet timeout on node 4.",
                isSender: true,
                wasMeshSend: true,
                transport: .bluetooth,
                receiptStatus: "failed"
            ),
            ChatMessage(
                text: "This message was deleted",
                isSender: false,
                isDeleted: true
            )
        ]

        return ChatThread(
            contactName: contactName,
            contactHandle: "@\(contactName.lowercased().replacingOccurrences(of: " ", with: ""))",
            lastMessage: "First line of chat message . . .",
            timestamp: "00/00/00",
            messages: messages,
            isPinned: false,
            isGroup: true,
            participantsCount: 3,
            isMeshOnly: false,
            isSignalSecured: true,
            unreadCount: unreadCount
        )
    }
}
