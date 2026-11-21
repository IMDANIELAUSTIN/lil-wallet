//
//  MediaModels.swift
//  Salt
//
//  Models, URI normalization, and dynamic artwork palette extraction
//  for playable NFT media (songs, 16:9 videos, video podcasts, audio podcasts).
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(CoreImage)
import CoreImage
#endif

// MARK: - Media Kind

enum NFTMediaKind: String, Codable, Hashable, Sendable, CaseIterable {
    case song
    case video
    case videoPodcast
    case audioPodcast

    var isVideoCapable: Bool {
        self == .video || self == .videoPodcast
    }

    var usesPodcastSkipControls: Bool {
        self == .video || self == .videoPodcast || self == .audioPodcast
    }

    var showsReleaseDate: Bool {
        self == .video || self == .videoPodcast || self == .audioPodcast
    }

    var displayLabel: String {
        switch self {
        case .song: return "Song"
        case .video: return "Video"
        case .videoPodcast: return "Video Podcast"
        case .audioPodcast: return "Podcast"
        }
    }

    var badgeSymbol: String {
        switch self {
        case .song: return "music.note"
        case .video: return "play.fill"
        case .videoPodcast: return "video.fill"
        case .audioPodcast: return "waveform"
        }
    }
}

// MARK: - Chapters

struct MediaChapter: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let title: String
    let startTime: TimeInterval

    init(id: String = UUID().uuidString, title: String, startTime: TimeInterval) {
        self.id = id
        self.title = title
        self.startTime = startTime
    }
}

// MARK: - Unified Media Item

struct MediaItem: Identifiable, Hashable, Sendable {
    let id: String
    let assetID: Int
    let kind: NFTMediaKind
    let title: String
    let creator: String
    let releaseDateText: String?
    let artworkURL: URL?
    let streamURL: URL
    let audioFallbackURL: URL?
    let durationHint: TimeInterval?
    let audioQualityBadge: String
    let lyricsOrTranscript: String?
    let chapters: [MediaChapter]
    let permalinkURL: URL?
    let sourceAsset: OpenSeaAsset?

    static func == (lhs: MediaItem, rhs: MediaItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Decentralized Media URI Resolver

enum MediaURLResolver {
    static func resolve(_ raw: String?) -> URL? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.lowercased().hasPrefix("ipfs://") {
            var path = String(trimmed.dropFirst("ipfs://".count))
            if path.lowercased().hasPrefix("ipfs/") {
                path = String(path.dropFirst("ipfs/".count))
            }
            return URL(string: "https://ipfs.io/ipfs/\(path)")
        }

        if trimmed.lowercased().hasPrefix("ar://") {
            let hash = String(trimmed.dropFirst("ar://".count))
            return URL(string: "https://arweave.net/\(hash)")
        }

        return URL(string: trimmed)
    }

    static func inferMediaKind(
        streamURL: URL,
        explicitHint: NFTMediaKind?,
        traits: [OpenSeaAssetTrait],
        description: String?
    ) -> NFTMediaKind? {
        if let explicitHint {
            return explicitHint
        }

        let ext = streamURL.pathExtension.lowercased()
        let traitText = traits
            .map { "\($0.trait_type.lowercased()) \($0.value.lowercased())" }
            .joined(separator: " ")
        let descText = (description ?? "").lowercased()
        let combined = "\(traitText) \(descText)"

        let looksLikePodcast = combined.contains("podcast")
            || combined.contains("episode")
            || combined.contains("interview")
            || traits.contains { $0.trait_type.lowercased() == "host" }

        let videoExtensions: Set<String> = ["mp4", "mov", "m4v", "m3u8", "webm"]
        let audioExtensions: Set<String> = ["mp3", "m4a", "wav", "aac", "flac", "ogg", "aiff"]

        if videoExtensions.contains(ext) {
            return looksLikePodcast ? .videoPodcast : .video
        }

        if audioExtensions.contains(ext) {
            return looksLikePodcast ? .audioPodcast : .song
        }

        if combined.contains("video podcast") { return .videoPodcast }
        if combined.contains("video") || combined.contains("film") || combined.contains("cinema") { return .video }
        if combined.contains("podcast") { return .audioPodcast }
        if combined.contains("song") || combined.contains("music") || combined.contains("audio") || combined.contains("track") {
            return .song
        }

        return nil
    }
}

// MARK: - Dynamic Subtle Artwork Ambient Palette

struct ArtworkPalette: Equatable, Sendable {
    let primaryRed: Double
    let primaryGreen: Double
    let primaryBlue: Double

    let secondaryRed: Double
    let secondaryGreen: Double
    let secondaryBlue: Double

    var primaryColor: Color {
        Color(red: primaryRed, green: primaryGreen, blue: primaryBlue)
    }

    var secondaryColor: Color {
        Color(red: secondaryRed, green: secondaryGreen, blue: secondaryBlue)
    }

    static let neutral = ArtworkPalette(
        primaryRed: 0.48, primaryGreen: 0.50, primaryBlue: 0.56,
        secondaryRed: 0.62, secondaryGreen: 0.64, secondaryBlue: 0.70
    )
}

@MainActor
final class ArtworkPaletteExtractor {
    static let shared = ArtworkPaletteExtractor()

    private var paletteCache: [URL: ArtworkPalette] = [:]
    private var imageCache: [URL: UIImage] = [:]

    func cachedPalette(for url: URL?) -> ArtworkPalette? {
        guard let url else { return nil }
        return paletteCache[url]
    }

    func cachedImage(for url: URL?) -> UIImage? {
        guard let url else { return nil }
        return imageCache[url]
    }

    func loadArtworkAndPalette(for url: URL?) async -> (UIImage?, ArtworkPalette) {
        guard let url else { return (nil, .neutral) }

        if let cachedImg = imageCache[url], let cachedPal = paletteCache[url] {
            return (cachedImg, cachedPal)
        }

        let result: (UIImage?, ArtworkPalette) = await Task.detached(priority: .userInitiated) {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            guard let (data, _) = try? await URLSession.shared.data(for: request),
                  let uiImage = UIImage(data: data) else {
                return (nil, ArtworkPalette.neutral)
            }
            let palette = Self.extractPalette(from: uiImage)
            return (uiImage, palette)
        }.value

        if let img = result.0 {
            imageCache[url] = img
        }
        paletteCache[url] = result.1
        return result
    }

    /// Samples upper and lower halves of a downscaled 24×24 bitmap to derive two
    /// balanced, gently saturated ambient colors for Light & Dark Mode gradients.
    private nonisolated static func extractPalette(from image: UIImage) -> ArtworkPalette {
        guard let cgImage = image.cgImage else { return .neutral }

        let size = 24
        let bytesPerPixel = 4
        let bytesPerRow = size * bytesPerPixel
        var rawBytes = [UInt8](repeating: 0, count: size * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &rawBytes,
                  width: size,
                  height: size,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return .neutral
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size, height: size))

        func regionColor(yRange: Range<Int>) -> (Double, Double, Double) {
            var rSum: Double = 0
            var gSum: Double = 0
            var bSum: Double = 0
            var weightSum: Double = 0

            for y in yRange {
                for x in 0..<size {
                    let offset = y * bytesPerRow + x * bytesPerPixel
                    let r = Double(rawBytes[offset]) / 255.0
                    let g = Double(rawBytes[offset + 1]) / 255.0
                    let b = Double(rawBytes[offset + 2]) / 255.0

                    let maxC = max(r, g, b)
                    let minC = min(r, g, b)
                    let saturation = maxC > 0 ? (maxC - minC) / maxC : 0
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b

                    // Favor colorful mid-tones over clipped pure white/black corners
                    let midToneWeight = 1.0 - abs(luminance - 0.5) * 1.1
                    let weight = max(0.15, (0.35 + saturation * 2.2) * max(0.2, midToneWeight))

                    rSum += r * weight
                    gSum += g * weight
                    bSum += b * weight
                    weightSum += weight
                }
            }

            guard weightSum > 0 else { return (0.48, 0.50, 0.56) }
            return (
                min(max(rSum / weightSum, 0), 1),
                min(max(gSum / weightSum, 0), 1),
                min(max(bSum / weightSum, 0), 1)
            )
        }

        let top = regionColor(yRange: 0..<(size / 2))
        let bottom = regionColor(yRange: (size / 2)..<size)

        return ArtworkPalette(
            primaryRed: top.0, primaryGreen: top.1, primaryBlue: top.2,
            secondaryRed: bottom.0, secondaryGreen: bottom.1, secondaryBlue: bottom.2
        )
    }
}
