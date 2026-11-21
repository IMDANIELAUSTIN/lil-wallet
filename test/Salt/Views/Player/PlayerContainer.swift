//
//  PlayerContainer.swift
//  Salt
//
//  Liquid Glass morphing container adapted from AMPlayer-2 for Salt.
//  Transitions smoothly between the TabView bottom-accessory MiniPlayer and
//  the full-screen ExpandedPlayer using ConcentricRectangle, glassEffect,
//  matchedGeometryEffect, and a direction-locked vertical DismissGesture.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Container Config

struct PlayerContainerConfig {
    var minimisedPlayerRect: CGRect = .zero
    var isInlinePlacement: Bool = false
    var attachExpandedPlayer: Bool = false
    var expandPlayer: Bool = false
    var dragOffset: CGFloat = 0
    var animation: Animation = .interpolatingSpring(duration: 0.34, bounce: 0, initialVelocity: 0)

    mutating func ensureAnchorRect(defaultAnchorSize: CGSize?) {
        if minimisedPlayerRect == .zero, let screenSize = defaultAnchorSize {
            minimisedPlayerRect = CGRect(
                x: 16,
                y: max(0, screenSize.height - 134),
                width: max(200, screenSize.width - 32),
                height: 54
            )
        }
    }

    mutating func collapse() {
        withAnimation(animation) {
            dragOffset = 0
            expandPlayer = false
        }
    }
}

// MARK: - Player Container

struct PlayerContainer: View {
    @Binding var config: PlayerContainerConfig
    var isExpandedSlot: Bool = false

    @Namespace private var namespace
    @EnvironmentObject var playerManager: MediaPlayerManager
    @EnvironmentObject var appearance: Appearance
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement

    var body: some View {
        if isExpandedSlot && config.attachExpandedPlayer {
            let expandPlayer = config.expandPlayer
            let isRestingExpanded = expandPlayer && config.dragOffset <= 0.5
            let minimisedRect = effectiveMinimisedRect()
            let minimumRadius = max(minimisedRect.height / 2, 24)
            let shape = ConcentricRectangle(
                corners: .concentric(minimum: .fixed(isRestingExpanded ? 0 : minimumRadius)),
                isUniform: true
            )

            GeometryReader { proxy in
                let safeArea = proxy.safeAreaInsets
                let size = CGSize(
                    width: proxy.size.width + safeArea.leading + safeArea.trailing,
                    height: proxy.size.height + safeArea.top + safeArea.bottom
                )

                ZStack {
                    if expandPlayer {
                        ExpandedPlayer(
                            size: size,
                            safeArea: safeArea,
                            namespace: namespace,
                            config: $config
                        ) {
                            toggleExpandedPlayer(status: false)
                        }
                        .geometryGroup()
                        .transition(.opacity)
                    }
                }
                .frame(
                    width: expandPlayer ? size.width : minimisedRect.width,
                    height: expandPlayer ? size.height : minimisedRect.height
                )
                .overlay(alignment: .top) {
                    if !expandPlayer {
                        MiniPlayer(
                            namespace: namespace,
                            forcedInlineCompact: config.isInlinePlacement
                        )
                        .frame(height: minimisedRect.height)
                        .geometryGroup()
                        .transition(.blurReplace)
                    }
                }
                .contentShape(shape)
                .clipShape(shape)
                .glassEffect(.regular, in: shape)
                .visualEffect { [config, minimisedRect] content, geo in
                    let globalRect = geo.frame(in: .global)
                    let isExpanded = config.expandPlayer
                    return content
                        .offset(y: config.dragOffset)
                        .offset(
                            x: isExpanded ? 0 : (minimisedRect.minX - globalRect.minX),
                            y: isExpanded ? 0 : (minimisedRect.minY - globalRect.minY)
                        )
                }
                .gesture(
                    DismissGesture { translation in
                        config.dragOffset = max(0, translation.y)
                    } onEnded: { velocity in
                        let projected = config.dragOffset + max(velocity.y / 5, 0)
                        if projected > (size.height * 0.32) {
                            toggleExpandedPlayer(status: false)
                        } else {
                            withAnimation(config.animation) {
                                config.dragOffset = 0
                            }
                        }
                    }
                )
                .ignoresSafeArea()
            }
        } else if !isExpandedSlot {
            MiniPlayer()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
                .opacity(config.attachExpandedPlayer ? 0 : 1)
                .allowsHitTesting(!config.attachExpandedPlayer)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .global)
                } action: { newRect in
                    guard !config.attachExpandedPlayer,
                          newRect.width > 0,
                          newRect.height > 0 else {
                        return
                    }
                    config.minimisedPlayerRect = newRect
                }
                .onAppear {
                    if !config.attachExpandedPlayer {
                        config.isInlinePlacement = (accessoryPlacement == .inline)
                    }
                }
                .onChange(of: accessoryPlacement) { _, newPlacement in
                    if !config.attachExpandedPlayer {
                        config.isInlinePlacement = (newPlacement == .inline)
                    }
                }
                .onTapGesture {
                    config.isInlinePlacement = (accessoryPlacement == .inline)
                    toggleExpandedPlayer(status: true)
                }
        }
    }

    private func effectiveMinimisedRect() -> CGRect {
        if config.minimisedPlayerRect.width > 0 && config.minimisedPlayerRect.height > 0 {
            return config.minimisedPlayerRect
        }
        return CGRect(x: 16, y: 720, width: 360, height: 54)
    }

    private func toggleExpandedPlayer(status: Bool) {
        if status {
            config.attachExpandedPlayer = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) {
                withAnimation(config.animation) {
                    config.expandPlayer = true
                    config.dragOffset = 0
                }
            }
        } else {
            withAnimation(config.animation, completionCriteria: .removed) {
                config.dragOffset = 0
                config.expandPlayer = false
            } completion: {
                config.attachExpandedPlayer = false
            }
        }
    }
}

// MARK: - Direction-Locked Vertical Dismiss Gesture

/// Uses UIPanGestureRecognizer with UIGestureRecognizerDelegate so horizontal drags
/// (timeline scrubbing, volume slider) never compete with vertical sheet dismissal.
fileprivate struct DismissGesture: UIGestureRecognizerRepresentable {
    var onChanged: (_ translation: CGPoint) -> Void
    var onEnded: (_ velocity: CGPoint) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            // Only engage on deliberate downward vertical gestures
            return velocity.y > 0 && abs(velocity.y) > abs(velocity.x) * 1.25
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var current = touch.view
            while let view = current {
                if view is UISlider || view is UIControl {
                    return false
                }
                current = view.superview
            }
            return true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let gesture = UIPanGestureRecognizer()
        gesture.delegate = context.coordinator
        return gesture
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {}

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let state = recognizer.state
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)

        switch state {
        case .began:
            break
        case .changed:
            onChanged(translation)
        case .ended, .cancelled, .failed:
            onEnded(velocity)
        default:
            break
        }
    }
}
