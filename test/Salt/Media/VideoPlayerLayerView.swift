//
//  VideoPlayerLayerView.swift
//  Salt
//
//  Clean AVPlayerLayer host for full-bleed 16:9 video & video podcasts with
//  Picture-in-Picture (AVPictureInPictureController) and native fullscreen support.
//

import SwiftUI
import AVFoundation
import AVKit
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Inline 16:9 Video Layer Host

final class PlayerLayerHostView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        // Safe because layerClass is overridden to AVPlayerLayer
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspect
    }
}

struct VideoPlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    var videoGravity: AVLayerVideoGravity = .resizeAspect
    var onAttachPiPController: ((AVPictureInPictureController?) -> Void)?

    final class Coordinator: NSObject, AVPictureInPictureControllerDelegate {
        var pipController: AVPictureInPictureController?
        weak var attachedLayer: AVPlayerLayer?

        func attachPiPIfPossible(to playerLayer: AVPlayerLayer, callback: ((AVPictureInPictureController?) -> Void)?) {
            guard attachedLayer !== playerLayer else { return }
            attachedLayer = playerLayer

            if AVPictureInPictureController.isPictureInPictureSupported() {
                let controller = AVPictureInPictureController(playerLayer: playerLayer)
                controller?.delegate = self
                controller?.canStartPictureInPictureAutomaticallyFromInline = true
                pipController = controller
                callback?(controller)
            } else {
                pipController = nil
                callback?(nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerLayerHostView {
        let view = PlayerLayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = videoGravity
        context.coordinator.attachPiPIfPossible(to: view.playerLayer, callback: onAttachPiPController)
        return view
    }

    func updateUIView(_ uiView: PlayerLayerHostView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
        if uiView.playerLayer.videoGravity != videoGravity {
            uiView.playerLayer.videoGravity = videoGravity
        }
        context.coordinator.attachPiPIfPossible(to: uiView.playerLayer, callback: onAttachPiPController)
    }

    static func dismantleUIView(_ uiView: PlayerLayerHostView, coordinator: Coordinator) {
        // Detach only the display layer so the shared AVPlayer keeps audio playing uninterrupted
        if coordinator.pipController?.isPictureInPictureActive != true {
            uiView.playerLayer.player = nil
        }
    }
}

// MARK: - Fullscreen Landscape Video Player

struct FullscreenVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.showsPlaybackControls = true
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
