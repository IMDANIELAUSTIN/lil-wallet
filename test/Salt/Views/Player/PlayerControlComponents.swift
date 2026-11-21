//
//  PlayerControlComponents.swift
//  Salt
//
//  Reusable UI primitives for Salt's Now Playing experience:
//  - Dynamic subtle artwork-colored ambient gradient (Light & Dark Mode)
//  - Thumb-free interactive CapsuleScrubber & CapsuleVolumeSlider
//  - Circular Liquid Glass action buttons (Star, Share, More)
//  - Monospaced time formatters matching Video/Podcast & Music mockups
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Dynamic Subtle Artwork Ambient Gradient

struct ArtworkAmbientBackground: View {
    let palette: ArtworkPalette
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                Color(red: 0.06, green: 0.06, blue: 0.07)

                LinearGradient(
                    stops: [
                        .init(color: palette.primaryColor.opacity(0.32), location: 0.0),
                        .init(color: palette.secondaryColor.opacity(0.18), location: 0.48),
                        .init(color: Color.black.opacity(0.25), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        palette.primaryColor.opacity(0.24),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.28),
                    startRadius: 20,
                    endRadius: 340
                )
            } else {
                // Crisp luminous Light Mode canvas washed with a delicate artwork tint
                Color(.systemBackground)

                LinearGradient(
                    stops: [
                        .init(color: palette.primaryColor.opacity(0.14), location: 0.0),
                        .init(color: palette.secondaryColor.opacity(0.08), location: 0.45),
                        .init(color: palette.primaryColor.opacity(0.03), location: 1.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [
                        palette.primaryColor.opacity(0.12),
                        Color.clear
                    ],
                    center: .init(x: 0.5, y: 0.28),
                    startRadius: 20,
                    endRadius: 320
                )
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.55), value: palette)
    }
}

// MARK: - Interactive Capsule Scrubber (Timeline)

struct CapsuleScrubber: View {
    let progress: Double
    var onScrubBegan: (Double) -> Void
    var onScrubChanged: (Double) -> Void
    var onScrubEnded: (Double) -> Void

    @State private var isDragging = false
    @State private var dragFraction: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    private var displayedProgress: Double {
        min(max(isDragging ? dragFraction : progress, 0), 1)
    }

    var body: some View {
        let trackHeight: CGFloat = isDragging ? 10 : 7
        let unfilledColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.20)
            : Color.primary.opacity(0.15)
        let filledColor: Color = colorScheme == .dark
            ? Color.white.opacity(isDragging ? 0.92 : 0.72)
            : Color.primary.opacity(isDragging ? 0.80 : 0.50)

        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(unfilledColor)
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(filledColor)
                    .frame(width: max(trackHeight, width * displayedProgress), height: trackHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let frac = min(max(Double(value.location.x / width), 0), 1)
                        if !isDragging {
                            isDragging = true
                            OrchardMotion.HapticStyle.selection.fire()
                            onScrubBegan(frac)
                        }
                        dragFraction = frac
                        onScrubChanged(frac)
                    }
                    .onEnded { value in
                        let frac = min(max(Double(value.location.x / width), 0), 1)
                        dragFraction = frac
                        isDragging = false
                        OrchardMotion.HapticStyle.light.fire()
                        onScrubEnded(frac)
                    }
            )
        }
        .frame(height: 28)
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isDragging)
    }
}

// MARK: - Interactive Capsule Volume Slider

struct CapsuleVolumeSlider: View {
    @Binding var volume: Float
    var onVolumeChange: (Float) -> Void

    @State private var isDragging = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let trackHeight: CGFloat = isDragging ? 9 : 7
        let unfilledColor: Color = colorScheme == .dark
            ? Color.white.opacity(0.20)
            : Color.primary.opacity(0.15)
        let filledColor: Color = colorScheme == .dark
            ? Color.white.opacity(isDragging ? 0.92 : 0.72)
            : Color.primary.opacity(isDragging ? 0.80 : 0.50)

        HStack(spacing: 12) {
            Button {
                OrchardMotion.HapticStyle.light.fire()
                let next = max(0, volume - 0.1)
                volume = next
                onVolumeChange(next)
            } label: {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appPrimary.opacity(isDragging ? 0.95 : 0.78))
            }
            .buttonStyle(.plain)

            GeometryReader { proxy in
                let width = max(proxy.size.width, 1)
                let fraction = CGFloat(min(max(volume, 0), 1))

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(unfilledColor)
                        .frame(height: trackHeight)

                    Capsule(style: .continuous)
                        .fill(filledColor)
                        .frame(width: max(trackHeight, width * fraction), height: trackHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                OrchardMotion.HapticStyle.selection.fire()
                            }
                            let next = Float(min(max(value.location.x / width, 0), 1))
                            volume = next
                            onVolumeChange(next)
                        }
                        .onEnded { value in
                            let next = Float(min(max(value.location.x / width, 0), 1))
                            volume = next
                            onVolumeChange(next)
                            isDragging = false
                        }
                )
            }
            .frame(height: 28)

            Button {
                OrchardMotion.HapticStyle.light.fire()
                let next = min(1, volume + 0.1)
                volume = next
                onVolumeChange(next)
            } label: {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.appPrimary.opacity(isDragging ? 0.95 : 0.78))
            }
            .buttonStyle(.plain)
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.8), value: isDragging)
    }
}

// MARK: - Circular Glass Action Button

struct CircularGlassIconLabel: View {
    let systemName: String
    var isActive: Bool = false
    var activeColor: Color = .appPrimary
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(isActive ? activeColor : Color.appPrimary.opacity(0.85))
            .frame(width: size, height: size)
            .glassEffect(.regular.interactive(), in: .circle)
            .overlay(
                Circle()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.6)
            )
            .contentShape(Circle())
    }
}

// MARK: - Tactile Transport Button Style

struct TransportPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(OrchardMotion.press, value: configuration.isPressed)
    }
}

// MARK: - Artwork Thumbnail Helper

struct PlayerArtworkImage: View {
    let url: URL?
    let cachedImage: UIImage?
    var fallbackSymbol: String = "music.note"

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    private var placeholder: some View {
        ZStack {
            Color(.secondarySystemGroupedBackground)
            Image(systemName: fallbackSymbol)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Time Formatter

enum PlayerTimeFormatter {
    static func formatElapsed(_ seconds: TimeInterval, includeHoursWhenLong: Bool = false) -> String {
        let clamped = max(0, Int(seconds.isFinite ? seconds : 0))
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else if includeHoursWhenLong && seconds >= 3600 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    static func formatRemaining(_ seconds: TimeInterval, forceLongFormat: Bool) -> String {
        let clamped = max(0, Int(seconds.isFinite ? seconds : 0))
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let secs = clamped % 60

        if forceLongFormat || hours > 0 {
            return String(format: "-%02d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "-%d:%02d", minutes, secs)
        }
    }
}
