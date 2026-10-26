import SwiftUI
import AVFoundation

// MARK: - Audio Waveform Analyzer (Cached RMS Peaks)

@MainActor
public enum WaveformAnalyzer {
    private static let cache = NSCache<NSURL, NSArray>()

    public static func cachedBars(for url: URL) -> [CGFloat]? {
        cache.object(forKey: url as NSURL) as? [CGFloat]
    }

    public static func bars(for url: URL, count: Int) -> [CGFloat] {
        if let cached = cache.object(forKey: url as NSURL) as? [CGFloat] {
            return cached
        }
        let computed = analyze(url: url, count: count)
        cache.setObject(computed as NSArray, forKey: url as NSURL)
        return computed
    }

    private static func analyze(url: URL, count: Int) -> [CGFloat] {
        let fallback = (0..<count).map { _ in CGFloat(0.35) }
        guard let file = try? AVAudioFile(forReading: url) else { return fallback }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frameCount),
              (try? file.read(into: buffer)) != nil,
              let samples = buffer.floatChannelData?[0] else { return fallback }

        let total = Int(buffer.frameLength)
        guard total > 0 else { return fallback }
        let chunk = max(total / count, 1)
        var peaks: [CGFloat] = []
        peaks.reserveCapacity(count)
        for i in 0..<count {
            let start = i * chunk
            guard start < total else { break }
            let end = min(start + chunk, total)
            var sum: Float = 0
            for j in start..<end { sum += samples[j] * samples[j] }
            let rms = sqrt(sum / Float(end - start))
            peaks.append(CGFloat(rms))
        }
        let maxPeak = peaks.max() ?? 1
        guard maxPeak > 0 else { return fallback }
        return peaks.map { 0.15 + 0.85 * ($0 / maxPeak) }
    }
}

// MARK: - Live Rolling Recording Waveform

public struct LiveWaveformView: View {
    public let levels: [Float]
    public var tint: Color = .accentColor

    public init(levels: [Float], tint: Color = .accentColor) {
        self.levels = levels
        self.tint = tint
    }

    public var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let barWidth = max((proxy.size.width / CGFloat(count)) - 2, 1)
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(tint)
                        .frame(width: barWidth, height: max(3, CGFloat(level) * proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .frame(height: 24)
    }
}

// MARK: - Staged Voice Memo Scrubber (In-Composer Review Bar)

public struct StagedWaveformScrubber: View {
    public let url: URL
    public let isPlaying: Bool
    public let player: AVAudioPlayer?
    public let onSeek: (Double) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var progress: Double = 0

    public init(
        url: URL,
        isPlaying: Bool,
        player: AVAudioPlayer?,
        onSeek: @escaping (Double) -> Void
    ) {
        self.url = url
        self.isPlaying = isPlaying
        self.player = player
        self.onSeek = onSeek
    }

    public var body: some View {
        let bars = WaveformAnalyzer.bars(for: url, count: 26)
        let playedColor = colorScheme == .dark ? Color.white : Color.primary
        let unplayedColor = colorScheme == .dark ? Color.white.opacity(0.35) : Color.primary.opacity(0.25)

        GeometryReader { geo in
            let totalWidth = geo.size.width
            let barCount = bars.count
            let spacing: CGFloat = 2.0
            let availableForBars = max(0, totalWidth - CGFloat(barCount - 1) * spacing)
            let barWidth = max(2.0, availableForBars / CGFloat(barCount))

            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    let fraction = barCount > 1 ? Double(index) / Double(barCount - 1) : 0
                    let isPlayed = fraction <= progress
                    let barHeight = max(4.0, bars[index] * geo.size.height)

                    Capsule(style: .continuous)
                        .fill(isPlayed ? playedColor : unplayedColor)
                        .frame(width: barWidth, height: barHeight)
                }
            }
            .frame(width: totalWidth, height: geo.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let frac = max(0, min(1, value.location.x / totalWidth))
                        progress = frac
                        onSeek(frac)
                    }
            )
        }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard let player, player.isPlaying else { break }
                let dur = player.duration
                if dur > 0 {
                    progress = min(1.0, player.currentTime / dur)
                }
            }
            if let player, !player.isPlaying, progress >= 0.98 {
                progress = 0
            }
        }
    }
}

// MARK: - Transcript Voice Memo Player Bubble (VoiceMemoPlayerView)

public struct VoiceMemoPlayerView: View {
    public let url: URL
    public var isSender: Bool = false
    public var tint: Color? = nil
    public var onLongPress: (() -> Void)? = nil

    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var duration: Double = 0
    @State private var bars: [CGFloat] = []
    @State private var lastHapticBar: Int = -1
    @State private var progressTask: Task<Void, Never>? = nil
    @State private var playbackSpeed: Double = 1.0

    private static let barCount = 36
    private static let bubbleHeight: CGFloat = 38
    private static let playControlDiameter: CGFloat = 28
    private static let waveformHeight: CGFloat = 24
    private static let waveformBarSpacing: CGFloat = 2.0
    private static let speeds: [Double] = [1.0, 1.25, 1.5, 2.0]
    private static let speedDefaultsKey = "voice_memo_playback_speed"

    private static var playButtonInset: CGFloat {
        (bubbleHeight - playControlDiameter) / 2
    }

    public init(url: URL, isSender: Bool = false, tint: Color? = nil, onLongPress: (() -> Void)? = nil) {
        self.url = url
        self.isSender = isSender
        self.tint = tint
        self.onLongPress = onLongPress
        if let cached = WaveformAnalyzer.cachedBars(for: url) {
            _bars = State(initialValue: cached)
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            playButton
                .padding(.leading, Self.playButtonInset)

            waveformScrubber
                .frame(minWidth: 120, maxWidth: .infinity)
                .frame(height: Self.waveformHeight)
                .padding(.horizontal, 8)

            trailingControlStack
                .padding(.trailing, 10)
        }
        .frame(idealWidth: 260, maxWidth: 280)
        .frame(height: Self.bubbleHeight)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35)
                .onEnded { _ in onLongPress?() }
        )
        .onAppear { prepare() }
        .onDisappear {
            progressTask?.cancel()
            player?.stop()
            isPlaying = false
        }
        .onChange(of: isPlaying) { _, playing in
            if playing { startProgressUpdates() } else { progressTask?.cancel() }
        }
    }

    private var playButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .fill(isSender ? OrchardDesign.Colors.offWhite : (tint ?? OrchardDesign.Colors.imessageBlue))
                    .frame(width: Self.playControlDiameter, height: Self.playControlDiameter)
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSender ? (tint ?? OrchardDesign.Colors.imessageBlue) : OrchardDesign.Colors.offWhite)
                    .offset(x: isPlaying ? 0 : 1)
            }
            .scaleEffect(isPlaying ? 1.06 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPlaying)
        }
        .buttonStyle(.plain)
    }

    private var waveformScrubber: some View {
        GeometryReader { proxy in
            let played = duration > 0 ? progress / duration : 0
            let count = max(bars.count, 1)
            let barW = max((proxy.size.width - CGFloat(count - 1) * Self.waveformBarSpacing) / CGFloat(count), 1.5)
            let playedColor = isSender ? OrchardDesign.Colors.offWhite : (tint ?? OrchardDesign.Colors.imessageBlue)
            let unplayedColor = isSender ? OrchardDesign.Colors.offWhite.opacity(0.35) : Color.secondary.opacity(0.30)

            HStack(alignment: .center, spacing: Self.waveformBarSpacing) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                    let fractionAt = bars.isEmpty ? 0 : Double(index) / Double(bars.count)
                    Capsule()
                        .fill(fractionAt <= played ? playedColor : unplayedColor)
                        .frame(width: barW, height: max(3, height * proxy.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = min(max(value.location.x / proxy.size.width, 0), 1)
                        seek(toFraction: fraction)
                        let barIdx = Int(fraction * Double(Self.barCount))
                        if barIdx != lastHapticBar {
                            lastHapticBar = barIdx
                            OrchardMotion.HapticStyle.selection.fire()
                        }
                    }
            )
        }
    }

    private var trailingControlStack: some View {
        VStack(alignment: .center, spacing: 1) {
            Button(action: cycleSpeed) {
                Text(String(format: "%gx", playbackSpeed))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(isSender ? (tint ?? OrchardDesign.Colors.imessageBlue) : Color.primary.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        isSender ? OrchardDesign.Colors.offWhite.opacity(0.28) : Color(.tertiarySystemFill),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)

            let secs = Int(max(0, progress > 0 ? progress : duration))
            Text(String(format: "%02d:%02d", secs / 60, secs % 60))
                .font(.system(size: 9.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(isSender ? OrchardDesign.Colors.offWhite : Color.secondary)
        }
    }

    private func cycleSpeed() {
        let speeds = Self.speeds
        if let idx = speeds.firstIndex(of: playbackSpeed) {
            playbackSpeed = speeds[(idx + 1) % speeds.count]
        } else {
            playbackSpeed = 1.0
        }
        OrchardMotion.HapticStyle.selection.fire()
        player?.enableRate = true
        player?.rate = Float(playbackSpeed)
        UserDefaults.standard.set(playbackSpeed, forKey: Self.speedDefaultsKey)
    }

    private func seek(toFraction fraction: Double) {
        prepare()
        guard let player else { return }
        player.currentTime = fraction * duration
        progress = player.currentTime
    }

    private func prepare() {
        guard player == nil else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.enableRate = true
        let saved = UserDefaults.standard.double(forKey: Self.speedDefaultsKey)
        playbackSpeed = saved > 0 ? saved : 1.0
        player?.rate = Float(playbackSpeed)
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        if bars.isEmpty {
            bars = WaveformAnalyzer.bars(for: url, count: Self.barCount)
        }
    }

    private func toggle() {
        prepare()
        guard let player else { return }
        OrchardMotion.HapticStyle.light.fire()
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player.enableRate = true
            player.rate = Float(playbackSpeed)
            player.play()
            isPlaying = true
        }
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task { @MainActor in
            while !Task.isCancelled && isPlaying {
                if let player {
                    progress = player.currentTime
                    if !player.isPlaying {
                        isPlaying = false
                        progress = 0
                        break
                    }
                }
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
    }
}
