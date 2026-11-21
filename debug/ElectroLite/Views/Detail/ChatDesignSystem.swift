import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Design Tokens

public enum OrchardDesign {
    public struct Spacing {
        public static let nano: CGFloat = 8
        public static let micro: CGFloat = 16
        public static let regular: CGFloat = 16
        public static let small: CGFloat = 24
        public static let standard: CGFloat = 32
        public static let medium: CGFloat = 48
        public static let large: CGFloat = 64
        public static let minimumTouchTarget: CGFloat = 44
    }

    public struct CornerRadius {
        public static let sheetTopRadius: CGFloat = 32

        /// Apple 2026 Corner Concentricity formula: R_inner = max(minimum, outer - padding)
        public static func concentric(outer: CGFloat, padding: CGFloat, minimum: CGFloat = 0) -> CGFloat {
            max(minimum, outer - padding)
        }
    }

    public struct Colors {
        public static let background = Color(uiColor: .systemBackground)
        public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
        public static let groupedBackground = Color(uiColor: .systemGroupedBackground)
        public static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)

        /// Primary brand text: #290B00 in light mode, #F6F5F3 in dark mode.
        public static let primaryText = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0xF6 / 255.0, green: 0xF5 / 255.0, blue: 0xF3 / 255.0, alpha: 1.0)
                : UIColor(red: 0x29 / 255.0, green: 0x0B / 255.0, blue: 0x00 / 255.0, alpha: 1.0)
        })
        public static let primaryAccent = primaryText
        public static let buttonSymbol = primaryAccent

        /// #FC3D39 — Sent messages routed over Bluetooth mesh.
        public static let bluetoothRed = Color(red: 0xFC / 255.0, green: 0x3D / 255.0, blue: 0x39 / 255.0)
        /// #147EFB — Sent messages routed over P2P / Signal / Nostr.
        public static let imessageBlue = Color(red: 0x14 / 255.0, green: 0x7E / 255.0, blue: 0xFB / 255.0)
        /// #F6F5F3 — Warm off-white for high-contrast controls inside colored bubbles.
        public static let offWhite = Color(red: 0xF6 / 255.0, green: 0xF5 / 255.0, blue: 0xF3 / 255.0)
    }

    public struct Typography {
        public static let prominentTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        public static let header = Font.system(.title2, design: .rounded, weight: .semibold)
        public static let body = Font.system(.body, design: .rounded, weight: .regular)
        public static let bodyStrong = Font.system(.body, design: .rounded, weight: .semibold)
        public static let caption = Font.system(.caption, design: .rounded, weight: .medium)
    }
}

// MARK: - Motion & Haptics

public enum OrchardMotion {
    public static let snappy = Animation.spring(duration: 0.3, bounce: 0)
    public static let enter = Animation.spring(duration: 0.4, bounce: 0)
    public static let exit = Animation.easeIn(duration: 0.15)
    public static let press = Animation.spring(duration: 0.15, bounce: 0)
    public static let standard = Animation.spring(duration: 0.35, bounce: 0)

    public enum HapticStyle: Sendable {
        case selection, light, medium, success, warning

        @MainActor
        public func fire() {
            #if os(iOS)
            switch self {
            case .selection: UISelectionFeedbackGenerator().selectionChanged()
            case .light: UIImpactFeedbackGenerator(style: .light).impactOccurred()
            case .medium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
            #endif
        }
    }

    @MainActor
    public static func perform(_ haptic: HapticStyle, animation: Animation = snappy, _ body: () -> Void) {
        haptic.fire()
        withAnimation(animation, body)
    }
}

// MARK: - Keyboard & Navigation Helpers

public extension View {
    /// Prevents taps on accessory buttons from resigning the active keyboard responder.
    func keepsKeyboardActiveOnTap() -> some View {
        self.accessibilityIdentifier("keepKeyboardActive")
    }

    /// Re-enables the native interactive edge-swipe pop gesture when `.navigationBarBackButtonHidden(true)` is active.
    func restoresSwipeBackGesture() -> some View {
        background(NavigationPopGestureEnabler())
    }
}

private struct NavigationPopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            guard let nav = controller.navigationController else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = true
            nav.interactivePopGestureRecognizer?.delegate = context.coordinator
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool { true }
    }
}
