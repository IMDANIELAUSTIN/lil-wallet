//
//  SystemMediaControls.swift
//  Salt
//
//  AVAudioSession configuration, Lock Screen / Control Center Now Playing integration,
//  native AirPlay route picker, and hardware system volume bridge.
//

import SwiftUI
import AVFoundation
import AVKit
import MediaPlayer
#if canImport(UIKit)
import UIKit
#endif

// MARK: - System Media Coordinator (Lock Screen & Control Center)

@MainActor
final class SystemMediaCoordinator {
    struct Callbacks {
        var onPlay: @MainActor () -> Void
        var onPause: @MainActor () -> Void
        var onTogglePlayPause: @MainActor () -> Void
        var onNextTrack: @MainActor () -> Void
        var onPreviousTrack: @MainActor () -> Void
        var onSkipForward: @MainActor (TimeInterval) -> Void
        var onSkipBackward: @MainActor (TimeInterval) -> Void
        var onSeek: @MainActor (TimeInterval) -> Void
    }

    private var callbacks: Callbacks?
    private var isConfigured = false

    func configure(callbacks: Callbacks) {
        self.callbacks = callbacks
        guard !isConfigured else { return }
        isConfigured = true

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callbacks?.onPlay()
            }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callbacks?.onPause()
            }
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callbacks?.onTogglePlayPause()
            }
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callbacks?.onNextTrack()
            }
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.callbacks?.onPreviousTrack()
            }
            return .success
        }

        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 15
            Task { @MainActor [weak self] in
                self?.callbacks?.onSkipBackward(interval)
            }
            return .success
        }

        center.skipForwardCommand.preferredIntervals = [30]
        center.skipForwardCommand.addTarget { [weak self] event in
            let interval = (event as? MPSkipIntervalCommandEvent)?.interval ?? 30
            Task { @MainActor [weak self] in
                self?.callbacks?.onSkipForward(interval)
            }
            return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let targetTime = posEvent.positionTime
            Task { @MainActor [weak self] in
                self?.callbacks?.onSeek(targetTime)
            }
            return .success
        }
    }

    func activateAudioSession(for kind: NFTMediaKind) {
        let session = AVAudioSession.sharedInstance()
        let mode: AVAudioSession.Mode = {
            switch kind {
            case .videoPodcast, .audioPodcast: return .spokenAudio
            case .video: return .moviePlayback
            case .song: return .default
            }
        }()

        do {
            try session.setCategory(.playback, mode: mode, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            // Best-effort fallback if spokenAudio/moviePlayback mode conflicts on simulator
            try? session.setCategory(.playback)
            try? session.setActive(true)
        }
    }

    func updateRemoteCommands(for kind: NFTMediaKind) {
        let center = MPRemoteCommandCenter.shared()
        let isPodcastStyle = kind.usesPodcastSkipControls
        center.skipBackwardCommand.isEnabled = isPodcastStyle
        center.skipForwardCommand.isEnabled = isPodcastStyle
        center.previousTrackCommand.isEnabled = !isPodcastStyle
        center.nextTrackCommand.isEnabled = !isPodcastStyle
    }

    func updateNowPlayingInfo(
        item: MediaItem?,
        artwork: UIImage?,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isPlaying: Bool,
        rate: Float
    ) {
        guard let item else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.creator,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, currentTime),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? Double(rate) : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(rate),
            MPNowPlayingInfoPropertyMediaType: item.kind.isVideoCapable
                ? MPNowPlayingInfoMediaType.video.rawValue
                : MPNowPlayingInfoMediaType.audio.rawValue
        ]

        if duration.isFinite && duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        if let artwork {
            let size = artwork.size
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: size) { _ in artwork }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

// MARK: - AirPlay Route Picker View

struct AirPlayRoutePickerView: UIViewRepresentable {
    var tintColor: UIColor
    var activeTintColor: UIColor
    var prioritizesVideoDevices: Bool

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.backgroundColor = .clear
        picker.tintColor = tintColor
        picker.activeTintColor = activeTintColor
        picker.prioritizesVideoDevices = prioritizesVideoDevices
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = tintColor
        uiView.activeTintColor = activeTintColor
        uiView.prioritizesVideoDevices = prioritizesVideoDevices
    }
}

// MARK: - System Volume Bridge

@MainActor
final class SystemVolumeController {
    static let shared = SystemVolumeController()

    private lazy var volumeView: MPVolumeView = {
        let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        view.alpha = 0.0001
        return view
    }()

    func currentOutputVolume() -> Float {
        let vol = AVAudioSession.sharedInstance().outputVolume
        return vol > 0 ? vol : 0.75
    }

    func setSystemVolume(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        if let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first {
            slider.value = clamped
        }
    }
}
