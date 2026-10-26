import SwiftUI
import LinkPresentation
import ImageIO
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Identifiable URL Batch Wrapper

public struct IdentifiableURL: Identifiable {
    public let id: UUID
    public let urls: [URL]
    public let startIndex: Int

    public var url: URL { urls[min(startIndex, urls.count - 1)] }

    public init(id: UUID = UUID(), url: URL) {
        self.init(id: id, urls: [url], startIndex: 0)
    }

    public init(id: UUID = UUID(), urls: [URL], startIndex: Int = 0) {
        self.id = id
        self.urls = urls.isEmpty ? [URL(fileURLWithPath: "/dev/null")] : urls
        self.startIndex = startIndex
    }
}

// MARK: - Async Off-Main-Thread Disk Image Thumbnail

public struct DiskImageThumbnail: View {
    public let url: URL
    public var fill: Bool = true
    @State private var image: UIImage?

    private static let cache = NSCache<NSURL, UIImage>()

    public init(url: URL, fill: Bool = true) {
        self.url = url
        self.fill = fill
    }

    public var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    ProgressView()
                }
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        let loaded: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url), let img = UIImage(data: data) else { return nil }
            return img
        }.value
        if let loaded {
            Self.cache.setObject(loaded, forKey: url as NSURL)
            image = loaded
        }
    }
}

// MARK: - Fanned Photo Stack Bubble (ImageStackBubble)

public struct ImageStackBubble: View {
    public let urls: [URL]
    public let isSender: Bool
    public let namespace: Namespace.ID
    public let geometryID: String
    public let isHeroSource: Bool
    public let onTap: () -> Void

    private static let cardWidth: CGFloat = 180
    private static let cardHeight: CGFloat = 240
    private static let cardCornerRadius: CGFloat = 20
    private static let scaleStep: CGFloat = 0.84
    private static let angleStep: Double = 16
    private static let maxDealtCards = 2

    private var dealtCount: Int { min(urls.count - 1, Self.maxDealtCards) }
    private var fanBleed: CGFloat { dealtCount > 0 ? 56 : 0 }
    private var bottomBleed: CGFloat { dealtCount > 0 ? 24 : 0 }

    public init(
        urls: [URL],
        isSender: Bool,
        namespace: Namespace.ID,
        geometryID: String,
        isHeroSource: Bool,
        onTap: @escaping () -> Void
    ) {
        self.urls = urls
        self.isSender = isSender
        self.namespace = namespace
        self.geometryID = geometryID
        self.isHeroSource = isHeroSource
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                ForEach(Array((1...Self.maxDealtCards).reversed()), id: \.self) { depth in
                    if depth <= dealtCount {
                        card(url: urls[depth], depth: depth)
                    }
                }
                topCard
            }
            .padding(.leading, isSender ? 0 : fanBleed)
            .padding(.trailing, isSender ? fanBleed : 0)
            .padding(.bottom, bottomBleed)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(urls.count == 1 ? "Photo" : "\(urls.count) photos")
        .accessibilityHint("Opens the photo viewer")
        .accessibilityAddTraits(.isButton)
    }

    private var topCard: some View {
        DiskImageThumbnail(url: urls[0])
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
            }
            .matchedGeometryEffect(id: geometryID, in: namespace, isSource: isHeroSource)
            .opacity(isHeroSource ? 1 : 0)
    }

    private func card(url: URL, depth: Int) -> some View {
        let scale = pow(Self.scaleStep, CGFloat(depth))
        let magnitude = Self.angleStep * Double(depth)
        let angle = isSender ? magnitude : -magnitude

        return DiskImageThumbnail(url: url)
            .frame(width: Self.cardWidth, height: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.3), lineWidth: 0.5)
            }
            .scaleEffect(scale, anchor: .bottom)
            .rotationEffect(.degrees(angle), anchor: .bottom)
    }
}

// MARK: - Full-Screen Hero Photo Viewer (ChatMediaViewer)

public struct ChatMediaViewer: View {
    public let urls: [URL]
    public let startIndex: Int
    public let namespace: Namespace.ID
    public let geometryID: String
    public var onReply: (() -> Void)?
    public let onClose: () -> Void

    @State private var showsChrome = true
    @State private var dragOffset: CGSize = .zero
    @State private var index: Int

    private static let dismissThreshold: CGFloat = 120
    private static let pageThreshold: CGFloat = 60

    public init(
        urls: [URL],
        startIndex: Int = 0,
        namespace: Namespace.ID,
        geometryID: String,
        onReply: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.urls = urls
        self.startIndex = startIndex
        self.namespace = namespace
        self.geometryID = geometryID
        self.onReply = onReply
        self.onClose = onClose
        _index = State(initialValue: startIndex)
    }

    private var url: URL { urls[min(index, urls.count - 1)] }
    private var isHeroPaired: Bool { index == startIndex }

    private var backdropOpacity: Double {
        let travel = abs(dragOffset.height)
        return max(0.4, 1 - Double(travel / 400))
    }

    private var dragScale: CGFloat {
        let travel = abs(dragOffset.height)
        return max(0.85, 1 - travel / 1200)
    }

    public var body: some View {
        ZStack {
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showsChrome.toggle()
                    }
                }

            DiskImageThumbnail(url: url, fill: false)
                .id(url)
                .matchedGeometryEffect(id: geometryID, in: namespace, isSource: isHeroPaired)
                .transition(.opacity)
                .offset(dragOffset)
                .scaleEffect(dragScale)
                .ignoresSafeArea()
                .gesture(dismissDrag)
        }
        .overlay(alignment: .top) {
            if showsChrome {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .glassEffect(.clear.interactive(), in: .circle)
                            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
        .overlay(alignment: .bottom) {
            if showsChrome {
                VStack(spacing: 12) {
                    if urls.count > 1 {
                        HStack(spacing: 8) {
                            ForEach(urls.indices, id: \.self) { position in
                                Circle()
                                    .fill(position == index ? Color.white : Color.white.opacity(0.35))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.clear.interactive(), in: .capsule)
                        .animation(OrchardMotion.snappy, value: index)
                    }

                    HStack {
                        if let onReply {
                            Button {
                                close()
                                onReply()
                            } label: {
                                barIcon("arrowshape.turn.up.left")
                            }
                        }
                        Spacer()
                        ShareLink(item: url) {
                            barIcon("square.and.arrow.up")
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    private func barIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .glassEffect(.clear.interactive(), in: .circle)
            .overlay(Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
            .contentShape(Circle())
    }

    private var dismissDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = CGSize(width: value.translation.width / 3, height: value.translation.height)
            }
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dx) > abs(dy), abs(dx) > Self.pageThreshold, urls.count > 1 {
                    let next = index + (dx < 0 ? 1 : -1)
                    if urls.indices.contains(next) {
                        withAnimation(OrchardMotion.snappy) {
                            index = next
                            dragOffset = .zero
                        }
                    }
                } else if abs(dy) > Self.dismissThreshold {
                    close()
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            onClose()
        }
    }
}

// MARK: - Rich Link Preview (ChatLinkDetector & ChatLinkPreview)

private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T
    init(_ v: T) { value = v }
}

@MainActor
public final class LinkPreviewCache {
    public static let shared = LinkPreviewCache()
    private var cache: [URL: LPLinkMetadata] = [:]
    private var inFlight: Set<URL> = []

    public func cached(_ url: URL) -> LPLinkMetadata? { cache[url] }

    public func fetch(_ url: URL, onFetched: @escaping (LPLinkMetadata) -> Void) {
        if let existing = cache[url] { onFetched(existing); return }
        guard !inFlight.contains(url) else { return }
        inFlight.insert(url)
        let provider = LPMetadataProvider()
        let boxedOnFetched = UncheckedBox(onFetched)
        provider.startFetchingMetadata(for: url) { [weak self] metadata, error in
            let boxedMetadata = metadata.map(UncheckedBox.init)
            Task { @MainActor in
                self?.inFlight.remove(url)
                guard let self, let boxedMetadata, error == nil else { return }
                self.cache[url] = boxedMetadata.value
                boxedOnFetched.value(boxedMetadata.value)
            }
        }
    }
}

public enum ChatLinkDetector {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    public static func firstLink(in text: String) -> URL? {
        guard let detector else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = detector.firstMatch(in: text, range: range),
              let url = match.url, let scheme = url.scheme,
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    public static func isMapLink(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host.contains("maps.apple.com")
            || host.contains("maps.google.")
            || (host.contains("google.com") && url.path.hasPrefix("/maps"))
            || (host.contains("goo.gl") && url.path.hasPrefix("/maps"))
            || host.contains("waze.com")
    }
}

public struct ChatLinkPreview: View {
    public let url: URL
    @Environment(\.openURL) private var openURL
    @State private var metadata: LPLinkMetadata?

    public init(url: URL) {
        self.url = url
    }

    private var previewHeight: CGFloat {
        ChatLinkDetector.isMapLink(url) ? 160 : 90
    }

    public var body: some View {
        Group {
            if let metadata {
                LinkPreviewRepresentable(metadata: metadata)
                    .frame(height: previewHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    Image(systemName: ChatLinkDetector.isMapLink(url) ? "mappin.and.ellipse" : "link")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.quaternary, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ChatLinkDetector.isMapLink(url) ? "Shared Location" : (url.host ?? url.absoluteString))
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(url.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { openURL(url) }
        .onAppear {
            if let cached = LinkPreviewCache.shared.cached(url) {
                metadata = cached
            } else {
                LinkPreviewCache.shared.fetch(url) { fetched in metadata = fetched }
            }
        }
    }
}

private struct LinkPreviewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        view.sizeToFit()
        return view
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        if uiView.metadata.originalURL != metadata.originalURL {
            uiView.metadata = metadata
        }
    }
}
