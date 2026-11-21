//
//  MediaPlayerManager.swift
//  Salt
//
//  Centralized @MainActor playback engine for playable NFT media (songs, 16:9 videos,
//  video podcasts, audio podcasts). Owns a single AVPlayer so transitions between
//  MiniPlayer, ExpandedPlayer, audio-only mode ("Turn Video Off"), PiP, and
//  Fullscreen are seamless and glitch-free.
//

import Foundation
import SwiftUI
import AVFoundation
import AVKit
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class MediaPlayerManager: ObservableObject {
    // MARK: - Core Player
    let player: AVPlayer = {
        let p = AVPlayer()
        p.allowsExternalPlayback = true
        p.usesExternalPlaybackWhileExternalScreenIsActive = true
        p.preventsDisplaySleepDuringVideoPlayback = true
        return p
    }()

    // MARK: - Published Playback State
    @Published private(set) var currentItem: MediaItem?
    @Published private(set) var queue: [MediaItem] = []
    @Published private(set) var currentIndex: Int = 0

    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isBuffering: Bool = false
    @Published private(set) var playbackError: String?

    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isScrubbing: Bool = false
    @Published var scrubTime: TimeInterval = 0

    @Published var isVideoEnabled: Bool = true
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 0.85

    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var ambientPalette: ArtworkPalette = .neutral
    @Published private(set) var currentArtworkImage: UIImage?

    /// Triggers `ContentView` / `PlayerContainer` to expand into the full Now Playing view.
    @Published var expandRequestToken: UUID?
    @Published var showFullscreenVideo: Bool = false

    weak var pipController: AVPictureInPictureController?

    // MARK: - Private Observers & Tasks
    private let systemControls = SystemMediaCoordinator()
    private var timeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var itemDurationObservation: NSKeyValueObservation?
    private var endOfItemObserver: NSObjectProtocol?
    private var artworkLoadTask: Task<Void, Never>?

    private static let favoritesDefaultsKey = "salt_favorite_media_nft_ids"
    static let supportedRates: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var hasActiveItem: Bool {
        currentItem != nil
    }

    var displayedTime: TimeInterval {
        isScrubbing ? scrubTime : currentTime
    }

    var effectiveDuration: TimeInterval {
        if duration.isFinite && duration > 0 {
            return duration
        }
        return currentItem?.durationHint ?? 0
    }

    var progress: Double {
        let total = effectiveDuration
        guard total > 0 else { return 0 }
        return min(max(displayedTime / total, 0), 1)
    }

    var remainingTime: TimeInterval {
        let total = effectiveDuration
        guard total > 0 else { return 0 }
        return max(0, total - displayedTime)
    }

    var canStartPiP: Bool {
        guard let item = currentItem, item.kind.isVideoCapable, isVideoEnabled else { return false }
        return AVPictureInPictureController.isPictureInPictureSupported() && pipController != nil
    }

    var isShowingVideoCanvas: Bool {
        guard let item = currentItem else { return false }
        return item.kind.isVideoCapable && isVideoEnabled
    }

    // MARK: - Init
    init() {
        let savedFavs = UserDefaults.standard.stringArray(forKey: Self.favoritesDefaultsKey) ?? []
        self.favoriteIDs = Set(savedFavs)
        self.volume = SystemVolumeController.shared.currentOutputVolume()
        self.player.volume = self.volume

        setupObservers()
        setupRemoteCommands()
    }

    private func setupObservers() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] cmTime in
            let seconds = CMTimeGetSeconds(cmTime)
            guard seconds.isFinite else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                if !self.isScrubbing {
                    self.currentTime = max(0, seconds)
                }
                self.syncNowPlayingInfo()
            }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .playing:
                    self.isPlaying = true
                    self.isBuffering = false
                case .waitingToPlayAtSpecifiedRate:
                    self.isBuffering = true
                case .paused:
                    self.isPlaying = false
                    self.isBuffering = false
                @unknown default:
                    break
                }
                self.syncNowPlayingInfo()
            }
        }
    }

    private func setupRemoteCommands() {
        systemControls.configure(callbacks: .init(
            onPlay: { [weak self] in self?.play() },
            onPause: { [weak self] in self?.pause() },
            onTogglePlayPause: { [weak self] in self?.togglePlayPause() },
            onNextTrack: { [weak self] in self?.nextTrack() },
            onPreviousTrack: { [weak self] in self?.previousTrack() },
            onSkipForward: { [weak self] interval in self?.skipForward(interval) },
            onSkipBackward: { [weak self] interval in self?.skipBackward(interval) },
            onSeek: { [weak self] time in self?.seek(to: time) }
        ))
    }

    // MARK: - Loading & Playback Control

    func play(
        _ item: MediaItem,
        queue newQueue: [MediaItem]? = nil,
        autoExpand: Bool = true
    ) {
        if let newQueue, !newQueue.isEmpty {
            self.queue = newQueue
            self.currentIndex = newQueue.firstIndex(of: item) ?? 0
            if !newQueue.contains(item) {
                self.queue.insert(item, at: 0)
                self.currentIndex = 0
            }
        } else if let existingIndex = self.queue.firstIndex(of: item) {
            self.currentIndex = existingIndex
        } else {
            self.queue = [item]
            self.currentIndex = 0
        }

        // If already loaded with the exact same item, resume & expand without restarting
        if currentItem?.id == item.id {
            if !isPlaying {
                play()
            }
            if autoExpand {
                expandRequestToken = UUID()
            }
            return
        }

        loadAndStart(item: item, autoExpand: autoExpand)
    }

    private func loadAndStart(item: MediaItem, autoExpand: Bool) {
        currentItem = item
        playbackError = nil
        currentTime = 0
        scrubTime = 0
        duration = item.durationHint ?? 0
        isVideoEnabled = item.kind.isVideoCapable
        isBuffering = true

        // Reset speed to 1.0x when entering music mode
        if item.kind == .song {
            playbackRate = 1.0
        }

        systemControls.activateAudioSession(for: item.kind)
        systemControls.updateRemoteCommands(for: item.kind)

        let playerItem = AVPlayerItem(url: item.streamURL)
        observePlayerItem(playerItem)
        player.replaceCurrentItem(with: playerItem)
        player.volume = volume
        player.playImmediately(atRate: playbackRate)
        isPlaying = true

        loadArtworkAndPalette(for: item)
        syncNowPlayingInfo()

        if autoExpand {
            expandRequestToken = UUID()
        }
    }

    private func observePlayerItem(_ playerItem: AVPlayerItem) {
        itemStatusObservation?.invalidate()
        itemDurationObservation?.invalidate()
        if let endOfItemObserver {
            NotificationCenter.default.removeObserver(endOfItemObserver)
        }

        itemStatusObservation = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            let status = item.status
            let errMsg = item.error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.playbackError = nil
                    let dur = CMTimeGetSeconds(item.duration)
                    if dur.isFinite && dur > 0 {
                        self.duration = dur
                    }
                    self.syncNowPlayingInfo()
                case .failed:
                    self.isBuffering = false
                    self.isPlaying = false
                    self.playbackError = errMsg ?? "Unable to load media stream."
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        itemDurationObservation = playerItem.observe(\.duration, options: [.new]) { [weak self] item, _ in
            let dur = CMTimeGetSeconds(item.duration)
            guard dur.isFinite && dur > 0 else { return }
            Task { @MainActor [weak self] in
                self?.duration = dur
                self?.syncNowPlayingInfo()
            }
        }

        endOfItemObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleItemEnded()
            }
        }
    }

    private func handleItemEnded() {
        if currentIndex + 1 < queue.count {
            nextTrack()
        } else {
            isPlaying = false
            seek(to: 0)
            pause()
        }
    }

    private func loadArtworkAndPalette(for item: MediaItem) {
        artworkLoadTask?.cancel()

        if let cachedPalette = ArtworkPaletteExtractor.shared.cachedPalette(for: item.artworkURL) {
            withAnimation(.easeInOut(duration: 0.45)) {
                self.ambientPalette = cachedPalette
            }
            self.currentArtworkImage = ArtworkPaletteExtractor.shared.cachedImage(for: item.artworkURL)
            syncNowPlayingInfo()
            return
        }

        artworkLoadTask = Task { @MainActor [weak self] in
            let (image, palette) = await ArtworkPaletteExtractor.shared.loadArtworkAndPalette(for: item.artworkURL)
            guard let self, !Task.isCancelled, self.currentItem?.id == item.id else { return }
            self.currentArtworkImage = image
            withAnimation(.easeInOut(duration: 0.5)) {
                self.ambientPalette = palette
            }
            self.syncNowPlayingInfo()
        }
    }

    // MARK: - Transport Controls

    func play() {
        guard let item = currentItem else { return }
        systemControls.activateAudioSession(for: item.kind)
        player.playImmediately(atRate: playbackRate)
        isPlaying = true
        syncNowPlayingInfo()
    }

    func pause() {
        player.pause()
        isPlaying = false
        syncNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to seconds: TimeInterval) {
        let total = effectiveDuration
        let clamped = total > 0 ? min(max(seconds, 0), total) : max(seconds, 0)
        currentTime = clamped
        let target = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        syncNowPlayingInfo()
    }

    func beginScrubbing(at fraction: Double) {
        isScrubbing = true
        scrubTime = fraction * effectiveDuration
    }

    func updateScrubbing(to fraction: Double) {
        scrubTime = min(max(fraction, 0), 1) * effectiveDuration
    }

    func endScrubbing(at fraction: Double) {
        let target = min(max(fraction, 0), 1) * effectiveDuration
        isScrubbing = false
        seek(to: target)
    }

    func skipBackward(_ seconds: TimeInterval = 15) {
        seek(to: currentTime - seconds)
    }

    func skipForward(_ seconds: TimeInterval = 30) {
        seek(to: currentTime + seconds)
    }

    func nextTrack() {
        guard !queue.isEmpty else { return }
        let nextIdx = (currentIndex + 1) % queue.count
        currentIndex = nextIdx
        loadAndStart(item: queue[nextIdx], autoExpand: false)
    }

    func previousTrack() {
        guard !queue.isEmpty else { return }
        // Standard Apple Music behavior: restart song if more than 3 seconds in
        if currentTime > 3.0 {
            seek(to: 0)
            return
        }
        let prevIdx = currentIndex > 0 ? currentIndex - 1 : queue.count - 1
        currentIndex = prevIdx
        loadAndStart(item: queue[prevIdx], autoExpand: false)
    }

    func setPlaybackRate(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            player.rate = rate
        }
        syncNowPlayingInfo()
    }

    func setVolume(_ newVolume: Float) {
        let clamped = min(max(newVolume, 0), 1)
        volume = clamped
        player.volume = clamped
        SystemVolumeController.shared.setSystemVolume(clamped)
    }

    // MARK: - Video Off / On Toggle & PiP

    /// Toggles video viewport off/on without interrupting audio playback.
    func toggleVideoOutput() {
        guard let item = currentItem, item.kind.isVideoCapable else { return }
        withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: 0)) {
            isVideoEnabled.toggle()
        }
    }

    func togglePictureInPicture() {
        guard let pipController else { return }
        if pipController.isPictureInPictureActive {
            pipController.stopPictureInPicture()
        } else {
            pipController.startPictureInPicture()
        }
    }

    // MARK: - Favorites & Queue Management

    func isFavorite(_ item: MediaItem) -> Bool {
        favoriteIDs.contains(item.id)
    }

    func toggleFavorite(for item: MediaItem) {
        if favoriteIDs.contains(item.id) {
            favoriteIDs.remove(item.id)
        } else {
            favoriteIDs.insert(item.id)
        }
        UserDefaults.standard.set(Array(favoriteIDs), forKey: Self.favoritesDefaultsKey)
    }

    func playNext(_ item: MediaItem) {
        if currentItem == nil {
            play(item, queue: [item], autoExpand: false)
            return
        }
        if let existingIdx = queue.firstIndex(of: item) {
            if existingIdx == currentIndex { return }
            queue.remove(at: existingIdx)
            if existingIdx < currentIndex {
                currentIndex -= 1
            }
        }
        let insertIndex = min(currentIndex + 1, queue.count)
        queue.insert(item, at: insertIndex)
    }

    func addToQueue(_ item: MediaItem) {
        if currentItem == nil {
            play(item, queue: [item], autoExpand: false)
            return
        }
        guard !queue.contains(item) else { return }
        queue.append(item)
    }

    func jumpToQueueIndex(_ index: Int) {
        guard queue.indices.contains(index) else { return }
        currentIndex = index
        loadAndStart(item: queue[index], autoExpand: false)
    }

    func moveQueueItems(from source: IndexSet, to destination: Int) {
        let activeID = currentItem?.id
        queue.move(fromOffsets: source, toOffset: destination)
        if let activeID, let updatedIdx = queue.firstIndex(where: { $0.id == activeID }) {
            currentIndex = updatedIdx
        }
    }

    func removeQueueItems(at offsets: IndexSet) {
        let activeID = currentItem?.id
        let filtered = IndexSet(offsets.filter { $0 != currentIndex })
        queue.remove(atOffsets: filtered)
        if let activeID, let updatedIdx = queue.firstIndex(where: { $0.id == activeID }) {
            currentIndex = updatedIdx
        }
    }

    func stopAndDismiss() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentItem = nil
        isPlaying = false
        isBuffering = false
        currentTime = 0
        duration = 0
        systemControls.updateNowPlayingInfo(
            item: nil,
            artwork: nil,
            currentTime: 0,
            duration: 0,
            isPlaying: false,
            rate: 1.0
        )
    }

    private func syncNowPlayingInfo() {
        systemControls.updateNowPlayingInfo(
            item: currentItem,
            artwork: currentArtworkImage,
            currentTime: currentTime,
            duration: effectiveDuration,
            isPlaying: isPlaying,
            rate: playbackRate
        )
    }
}
