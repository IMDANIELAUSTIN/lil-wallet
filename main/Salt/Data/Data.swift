//
//  Data.swift
//  Salt
//
//
//  Created and All Rights Reserved by Daniel Lee Austin on Oct/21/2026.


import Foundation
import CoreGraphics
import SocketIO
import Combine
import SwiftUI

private struct ParsedTokenPayload: Sendable {
    let id: String
    let name: String
    let symbol: String
    let quantity: String?
    let priceValue: Double?
    let relativeChange: Double?
    let iconURL: String?
}

private struct ParsedTransactionPayload: Sendable {
    let id: String
    let token: ParsedTokenPayload?
    let value: Double?
    let price: Double?
    let type: String
    let minedAt: Int
    let hash: String
    let status: String
    let blockNumber: Int
    let addressFrom: String?
    let addressTo: String?
    let feeValue: Double?
    let feePrice: Double?
}

@MainActor
class Wallet: ObservableObject {
    @AppStorage("currentWalletAddress") var currentWalletAddress: String = ""
    @AppStorage("openSeaAPIKey") var openSeaAPIKey: String = ""
    @Published var network = Network()
    @Published var value: Double = 0
    @Published var tokens: [Token] = []
    @Published var objects: [OpenSeaAsset] = []
    @Published var transactions: [Transaction] = []
    
    // loading states
    @Published var loadingPortfolio = true
    @Published var loadingTokens = true
    @Published var loadingObjects = true
    @Published var loadingTransactions = true
    @Published var transactionCategories: [String: String] = (UserDefaults.standard.dictionary(forKey: "transactionCategories") as? [String: String]) ?? [:]
    @Published var transactionMerchants: [String: String] = (UserDefaults.standard.dictionary(forKey: "transactionMerchants") as? [String: String]) ?? [:]
    @Published var portfolioTokenOrder: [String] = (UserDefaults.standard.stringArray(forKey: "portfolioTokenOrder")) ?? []
    
    private var fallbackTask: Task<Void, Never>?
    
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
    
    init() {
        reload(reset: false, refresh: false)
    }
    
    func formatCurrency(value: Double) -> String {
        Self.currencyFormatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    func formatAddress(address: String) -> String {
        guard address.count > 10 else { return address }
        return address.prefix(6) + "..." + address.suffix(4)
    }
    
    func category(for transaction: Transaction) -> TransactionCategory? {
        guard let raw = transactionCategories[transaction.id] else { return nil }
        return TransactionCategory(rawValue: raw)
    }
    
    func setCategory(_ category: TransactionCategory?, for transaction: Transaction) {
        if let category {
            transactionCategories[transaction.id] = category.rawValue
        } else {
            transactionCategories.removeValue(forKey: transaction.id)
        }
        UserDefaults.standard.set(transactionCategories, forKey: "transactionCategories")
    }
    
    func merchantName(for transaction: Transaction) -> String {
        if let custom = transactionMerchants[transaction.id], !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return transaction.merchantName ?? "Name of Business"
    }
    
    func setMerchantName(_ name: String, for transaction: Transaction) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            transactionMerchants.removeValue(forKey: transaction.id)
        } else {
            transactionMerchants[transaction.id] = trimmed
        }
        UserDefaults.standard.set(transactionMerchants, forKey: "transactionMerchants")
    }
    
    func applySavedTokenOrder(_ list: [Token]) -> [Token] {
        let alphabetical = list.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !portfolioTokenOrder.isEmpty else {
            return alphabetical
        }
        let orderIndex = Dictionary(uniqueKeysWithValues: portfolioTokenOrder.enumerated().map { ($1, $0) })
        return alphabetical.sorted { lhs, rhs in
            switch (orderIndex[lhs.id], orderIndex[rhs.id]) {
            case let (lIdx?, rIdx?):
                return lIdx < rIdx
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }
    
    func moveTokens(fromOffsets source: IndexSet, toOffset destination: Int) {
        tokens.move(fromOffsets: source, toOffset: destination)
        portfolioTokenOrder = tokens.map(\.id)
        UserDefaults.standard.set(portfolioTokenOrder, forKey: "portfolioTokenOrder")
    }
    
    func reorderToken(dragged: Token, target: Token) {
        guard dragged.id != target.id,
              let fromIndex = tokens.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = tokens.firstIndex(where: { $0.id == target.id }) else {
            return
        }
        tokens.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
        portfolioTokenOrder = tokens.map(\.id)
        UserDefaults.standard.set(portfolioTokenOrder, forKey: "portfolioTokenOrder")
    }
    
    func reload(reset: Bool, refresh: Bool) {
        fallbackTask?.cancel()
        
        if reset {
            network.disconnect()
            
            self.loadingTokens = true
            self.loadingObjects = true
            self.loadingPortfolio = true
            self.loadingTransactions = true
            
            self.value = 0
            self.tokens = []
            self.objects = []
            self.transactions = []
            network.connect()
        }
        
        if refresh {
            network.disconnect()
            // refresh wallet
            network.connect()
        }
        
        guard !self.currentWalletAddress.isEmpty else {
            self.loadingTokens = false
            self.loadingPortfolio = false
            self.loadingTransactions = false
            self.loadingObjects = false
            return
        }
        
        // reload wallet after updating address
        addressSocket.off(clientEvent: .connect)
        addressSocket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.fetchAssets()
            }
        }
        
        if addressSocket.status == .connected {
            self.fetchAssets()
        } else {
            network.connect()
        }
        
        // Schedule fallback if legacy Zerion v4 socket does not respond within 3.5s
        self.fallbackTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            guard let self = self, !Task.isCancelled else { return }
            if refresh || self.loadingTokens || self.loadingPortfolio || self.loadingTransactions {
                await self.fetchFallbackWalletData()
            }
        }
        
        self.fetchObjects()
    }
    
    func fetchAssets() {
        guard !self.currentWalletAddress.isEmpty else {
            self.loadingTokens = false
            self.loadingPortfolio = false
            self.loadingTransactions = false
            return
        }
        
        addressSocket.emit("get", ["scope": ["assets", "portfolio", "transactions"], "payload": ["address": self.currentWalletAddress, "currency": "usd"]])

        addressSocket.off("received address assets")
        addressSocket.on("received address assets") { [weak self] data, _ in
            var parsedTokens: [ParsedTokenPayload] = []
            if let array = data as? [[String: Any]],
               let firstDict = array.first,
               let payload = firstDict["payload"] as? [String: Any],
               let assets = payload["assets"] as? [String: Any] {
                for asset in assets {
                    guard let assetContainer = asset.value as? [String: Any],
                          let assetData = assetContainer["asset"] as? [String: Any],
                          let priceData = assetData["price"] as? [String: Any] else {
                        continue
                    }
                    let id = (assetData["id"] as? String) ?? UUID().uuidString
                    let name = (assetData["name"] as? String) ?? "Token"
                    let symbol = (assetData["symbol"] as? String) ?? ""
                    let quantity: String
                    if let qStr = assetContainer["quantity"] as? String {
                        quantity = qStr
                    } else if let qNum = assetContainer["quantity"] as? NSNumber {
                        quantity = qNum.stringValue
                    } else {
                        quantity = "0"
                    }
                    let priceValue = (priceData["value"] as? NSNumber)?.doubleValue
                    let relativeChange = (priceData["relative_change_24h"] as? NSNumber)?.doubleValue
                    let iconURL = assetData["icon_url"] as? String
                    parsedTokens.append(
                        ParsedTokenPayload(
                            id: id,
                            name: name,
                            symbol: symbol,
                            quantity: quantity,
                            priceValue: priceValue,
                            relativeChange: relativeChange,
                            iconURL: iconURL
                        )
                    )
                }
            }
            let finalTokens = parsedTokens
            Task { @MainActor [weak self] in
                guard let self = self, !finalTokens.isEmpty else { return }
                let mappedTokens = finalTokens.map { item in
                    Token(
                        id: item.id,
                        name: item.name,
                        symbol: item.symbol,
                        quantity: item.quantity,
                        price: Price(
                            value: item.priceValue ?? 0,
                            relative_change: item.relativeChange ?? 0
                        ),
                        iconURL: item.iconURL
                    )
                }
                withAnimation(.default) {
                    self.tokens = self.applySavedTokenOrder(mappedTokens)
                }
                self.loadingTokens = false
            }
        }
        
        addressSocket.off("received address portfolio")
        addressSocket.on("received address portfolio") { [weak self] data, _ in
            var parsedTotal: Double? = nil
            if let array = data as? [[String: Any]],
               let firstDict = array.first,
               let payload = firstDict["payload"] as? [String: Any],
               let portfolio = payload["portfolio"] as? [String: Any],
               let totalValue = portfolio["total_value"] as? NSNumber {
                parsedTotal = totalValue.doubleValue
            }
            let finalTotal = parsedTotal
            Task { @MainActor [weak self] in
                guard let self = self, let finalTotal = finalTotal else { return }
                withAnimation(.default) {
                    self.value = finalTotal
                }
                self.loadingPortfolio = false
            }
        }
        
        addressSocket.off("received address transactions")
        addressSocket.on("received address transactions") { [weak self] data, _ in
            var parsedTransactions: [ParsedTransactionPayload] = []
            if let array = data as? [[String: Any]],
               let firstDict = array.first,
               let payload = firstDict["payload"] as? [String: Any],
               let transactions = payload["transactions"] as? [[String: Any]] {
                for transactionData in transactions {
                    let id = (transactionData["id"] as? String) ?? UUID().uuidString
                    let changes = transactionData["changes"] as? [[String: Any]]
                    let asset = changes?.first
                    
                    var parsedToken: ParsedTokenPayload? = nil
                    if let assetObject = asset?["asset"] as? [String: Any] {
                        parsedToken = ParsedTokenPayload(
                            id: (assetObject["id"] as? String) ?? "0",
                            name: (assetObject["name"] as? String) ?? "",
                            symbol: (assetObject["symbol"] as? String) ?? "",
                            quantity: nil,
                            priceValue: nil,
                            relativeChange: nil,
                            iconURL: assetObject["icon_url"] as? String
                        )
                    }
                    
                    let value = (asset?["value"] as? NSNumber)?.doubleValue
                    let price = (asset?["price"] as? NSNumber)?.doubleValue
                    let type = (transactionData["type"] as? String) ?? "transfer"
                    let minedAt = (transactionData["mined_at"] as? Int) ?? Int(Date().timeIntervalSince1970)
                    let hash = (transactionData["hash"] as? String) ?? ""
                    let status = (transactionData["status"] as? String) ?? "confirmed"
                    let blockNumber = (transactionData["block_number"] as? Int) ?? 0
                    let addressFrom = transactionData["address_from"] as? String
                    let addressTo = transactionData["address_to"] as? String
                    
                    var feeVal: Double? = nil
                    var feePr: Double? = nil
                    if let feeObject = transactionData["fee"] as? [String: Any] {
                        feeVal = (feeObject["value"] as? NSNumber)?.doubleValue
                        feePr = (feeObject["price"] as? NSNumber)?.doubleValue
                    }
                    
                    parsedTransactions.append(
                        ParsedTransactionPayload(
                            id: id,
                            token: parsedToken,
                            value: value,
                            price: price,
                            type: type,
                            minedAt: minedAt,
                            hash: hash,
                            status: status,
                            blockNumber: blockNumber,
                            addressFrom: addressFrom,
                            addressTo: addressTo,
                            feeValue: feeVal,
                            feePrice: feePr
                        )
                    )
                }
            }
            let finalTransactions = parsedTransactions
            Task { @MainActor [weak self] in
                guard let self = self, !finalTransactions.isEmpty else { return }
                self.transactions = finalTransactions.map { item in
                    let tok: Token?
                    if let t = item.token {
                        tok = Token(id: t.id, name: t.name, symbol: t.symbol, quantity: nil, price: nil, iconURL: t.iconURL)
                    } else {
                        tok = nil
                    }
                    let feeObj: Fee?
                    if item.feeValue != nil || item.feePrice != nil {
                        feeObj = Fee(value: item.feeValue ?? 0, price: item.feePrice ?? 0)
                    } else {
                        feeObj = nil
                    }
                    return Transaction(
                        id: item.id,
                        token: tok,
                        value: item.value,
                        price: item.price,
                        type: item.type,
                        mined_at: item.minedAt,
                        hash: item.hash,
                        status: item.status,
                        block_number: item.blockNumber,
                        address_from: item.addressFrom,
                        address_to: item.addressTo,
                        fee: feeObj
                    )
                }
                self.loadingTransactions = false
            }
        }
    }
    
    /// Fallback pipeline when Zerion's 2021 v4 demo WebSocket is unreachable:
    /// Fetches live ETH balance via public Ethereum JSON-RPC + live ETH USD price via CoinGecko,
    /// and populates fallback demo tokens/transactions so the app remains fully functional.
    private func fetchFallbackWalletData() async {
        let address = self.currentWalletAddress
        guard !address.isEmpty else {
            self.loadingTokens = false
            self.loadingPortfolio = false
            self.loadingTransactions = false
            return
        }
        
        var weiString: String? = nil
        if let rpcURL = URL(string: "https://ethereum-rpc.publicnode.com") {
            var rpcRequest = URLRequest(url: rpcURL)
            rpcRequest.httpMethod = "POST"
            rpcRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            rpcRequest.timeoutInterval = 5
            let rpcPayload: [String: Any] = [
                "jsonrpc": "2.0",
                "method": "eth_getBalance",
                "params": [address, "latest"],
                "id": 1
            ]
            rpcRequest.httpBody = try? JSONSerialization.data(withJSONObject: rpcPayload)
            if let (data, _) = try? await URLSession.shared.data(for: rpcRequest),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let hexResult = json["result"] as? String {
                let cleanHex = hexResult.hasPrefix("0x") ? String(hexResult.dropFirst(2)) : hexResult
                if let weiVal = Double("0x" + cleanHex) {
                    weiString = String(format: "%.0f", weiVal)
                }
            }
        }
        
        var ethPrice: Double? = nil
        var ethChange: Double? = nil
        if let priceURL = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd&include_24hr_change=true") {
            var priceReq = URLRequest(url: priceURL)
            priceReq.timeoutInterval = 4
            if let (priceData, _) = try? await URLSession.shared.data(for: priceReq),
               let priceJson = try? JSONSerialization.jsonObject(with: priceData) as? [String: Any],
               let ethDict = priceJson["ethereum"] as? [String: Any] {
                ethPrice = ethDict["usd"] as? Double
                ethChange = ethDict["usd_24h_change"] as? Double
            }
        }
        
        applyDemoWalletData(ethWeiBalance: weiString, ethPriceUSD: ethPrice, ethChange24h: ethChange)
    }
    
    private func applyDemoWalletData(ethWeiBalance: String?, ethPriceUSD: Double?, ethChange24h: Double?) {
        let priceUSD = ethPriceUSD ?? 2650.00
        let change24h = ethChange24h ?? 2.45
        let ethQuantityWei: String
        if let ethWeiBalance = ethWeiBalance, (Double(ethWeiBalance) ?? 0) > 0 {
            ethQuantityWei = ethWeiBalance
        } else {
            ethQuantityWei = "1450000000000000000" // 1.45 ETH demo fallback
        }
        
        let ethToken = Token(
            id: "eth",
            name: "Ethereum",
            symbol: "ETH",
            quantity: ethQuantityWei,
            price: Price(value: priceUSD, relative_change: change24h),
            iconURL: "https://assets.coingecko.com/coins/images/279/small/ethereum.png"
        )
        
        let usdcToken = Token(
            id: "0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
            name: "USD Coin",
            symbol: "USDC",
            quantity: "1250000000000000000000",
            price: Price(value: 1.00, relative_change: 0.01),
            iconURL: "https://assets.coingecko.com/coins/images/6319/small/usdc.png"
        )
        
        let ensToken = Token(
            id: "0xc18360217d8f7ab5e7c516566761ea12ce7f9d72",
            name: "Ethereum Name Service",
            symbol: "ENS",
            quantity: "42000000000000000000",
            price: Price(value: 19.80, relative_change: 4.12),
            iconURL: "https://assets.coingecko.com/coins/images/19785/small/acatxTm8_400x400.jpg"
        )
        
        let tokenList = self.applySavedTokenOrder([ethToken, usdcToken, ensToken])
        let total = tokenList.reduce(0.0) { $0 + $1.value() }
        withAnimation(.default) {
            self.tokens = tokenList
            self.value = total
        }
        self.loadingTokens = false
        self.loadingPortfolio = false
        
            if self.loadingTransactions {
            let now = Int(Date().timeIntervalSince1970)
            self.transactions = [
                Transaction(
                    id: "tx-1",
                    token: ethToken,
                    value: 0.5 * oneETHinWEI,
                    price: priceUSD,
                    type: "receive",
                    mined_at: now - 3600 * 6,
                    hash: "0x5f9d8c1e7b2a4d3c9f0e1a2b3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d",
                    status: "confirmed",
                    block_number: 21045120,
                    address_from: "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045",
                    address_to: self.currentWalletAddress,
                    fee: Fee(value: 0.00042 * oneETHinWEI, price: priceUSD),
                    network: "Ethereum",
                    merchantName: "Name of Business"
                ),
                Transaction(
                    id: "tx-2",
                    token: usdcToken,
                    value: 250.0 * oneETHinWEI,
                    price: 1.00,
                    type: "send",
                    mined_at: now - 86400 * 2,
                    hash: "0x8a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b",
                    status: "confirmed",
                    block_number: 21031890,
                    address_from: self.currentWalletAddress,
                    address_to: "0x1db3439a222c519ab44bb1144fc28167b4fa6ee6",
                    fee: Fee(value: 0.00031 * oneETHinWEI, price: priceUSD),
                    network: "Base",
                    merchantName: "Name of Business"
                )
            ]
            self.loadingTransactions = false
        }
    }
    
    func fetchObjects() {
        guard !self.currentWalletAddress.isEmpty else {
            self.loadingObjects = false
            return
        }
        
        let apiKey = self.openSeaAPIKey
        let address = self.currentWalletAddress
        let urlString: String
        if !apiKey.isEmpty {
            urlString = "https://api.opensea.io/api/v2/chain/ethereum/account/\(address)/nfts?limit=50"
        } else {
            urlString = "https://api.opensea.io/api/v1/assets?limit=50&format=json&owner=\(address)"
        }
        
        guard let url = URL(string: urlString) else {
            self.objects = Self.demoObjects()
            self.loadingObjects = false
            return
        }
                
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let (data, _) = try? await URLSession.shared.data(for: request) {
                if let decodedV1 = try? JSONDecoder().decode(OpenSeaAssetsResponse.self, from: data), !decodedV1.assets.isEmpty {
                    self.objects = decodedV1.assets
                    self.loadingObjects = false
                    return
                }
                if let decodedV2 = try? JSONDecoder().decode(OpenSeaV2NFTsResponse.self, from: data), !decodedV2.nfts.isEmpty {
                    self.objects = decodedV2.nfts.map { $0.toOpenSeaAsset() }
                    self.loadingObjects = false
                    return
                }
            }
            self.objects = Self.demoObjects()
            self.loadingObjects = false
        }
    }
    
    var playableMediaItems: [MediaItem] {
        objects.compactMap { $0.resolvedMediaItem() }
    }

    static func demoObjects() -> [OpenSeaAsset] {
        let svg1 = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 400" width="100%" height="100%">
          <rect width="400" height="400" fill="#111111"/>
          <circle cx="200" cy="200" r="110" fill="none" stroke="#ffffff" stroke-width="12"/>
          <rect x="145" y="145" width="110" height="110" rx="18" fill="#ffffff"/>
        </svg>
        """
        let svgDataURL = "data:image/svg+xml;utf8," + (svg1.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
        
        return [
            OpenSeaAsset(
                id: 2001,
                image_url: "https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop",
                name: "Salt Cast Ep. 14",
                external_link: "https://opensea.io",
                traits: [
                    OpenSeaAssetTrait(trait_type: "Media Type", value: "Video Podcast"),
                    OpenSeaAssetTrait(trait_type: "Host", value: "Daniel Austin"),
                    OpenSeaAssetTrait(trait_type: "Date", value: "11/18/2026"),
                    OpenSeaAssetTrait(trait_type: "Resolution", value: "1080p 16:9")
                ],
                description: "A deep-dive video podcast exploring sovereign digital media, playable NFTs, and native Spatial/Liquid Glass playback.",
                permalink: "https://opensea.io",
                animation_url: "https://devstreaming-cdn.apple.com/videos/wwdc/2015/413eflf3lrh1tyo/413/hls_vod_mvp.m3u8",
                creator_name: "Daniel Austin",
                release_date: "11/18/2026",
                media_kind_hint: .videoPodcast,
                audio_format: "Stereo",
                transcript_or_lyrics: """
                [00:00] Welcome back to Salt Cast Episode 14. Today we're exploring what happens when on-chain objects stop being static thumbnails and become living video podcasts, cinema cuts, and master-quality music releases.

                [01:15] With adaptive HLS video and seamless audio-only switching, you can watch full 16:9 episodes right inside your wallet or tap Turn Video Off to keep listening while you walk.

                [03:40] Every token carries verifiable provenance, chapter markers, and creator splits — all presented with native iOS playback and Lock Screen controls.
                """,
                chapters: [
                    MediaChapter(id: "ch-1", title: "Introduction", startTime: 0),
                    MediaChapter(id: "ch-2", title: "Playable On-Chain Media", startTime: 75),
                    MediaChapter(id: "ch-3", title: "Video & Audio-Only Flow", startTime: 220),
                    MediaChapter(id: "ch-4", title: "Closing Thoughts", startTime: 420)
                ],
                collection_name: "Salt Cast",
                token_standard: "ERC-721",
                contract_address: "0x7A4c9F3e2B1d8E6a5C4b3A2f1E0d9C8b7A6F5E4D",
                network: "Ethereum"
            ),
            OpenSeaAsset(
                id: 2002,
                image_url: "https://images.unsplash.com/photo-1557672172-298e090bd0f1?w=800&auto=format&fit=crop",
                name: "View From A Blue Moon",
                external_link: "https://opensea.io",
                traits: [
                    OpenSeaAssetTrait(trait_type: "Media Type", value: "Video"),
                    OpenSeaAssetTrait(trait_type: "Director", value: "Blake Vincent Kueny"),
                    OpenSeaAssetTrait(trait_type: "Date", value: "11/12/2026"),
                    OpenSeaAssetTrait(trait_type: "Aspect Ratio", value: "16:9")
                ],
                description: "Collector edition 16:9 cinema short minted as an interactive video NFT.",
                permalink: "https://opensea.io",
                animation_url: "https://cdn.plyr.io/static/demo/View_From_A_Blue_Moon_Trailer-576p.mp4",
                creator_name: "Blake Vincent Kueny",
                release_date: "11/12/2026",
                media_kind_hint: .video,
                audio_format: "Stereo",
                transcript_or_lyrics: "Shot in sweeping 16:9 cinema framing across the Pacific — collector edition digital film token with full-screen and Picture-in-Picture playback.",
                chapters: [
                    MediaChapter(id: "bm-1", title: "Opening Horizon", startTime: 0),
                    MediaChapter(id: "bm-2", title: "First Swell", startTime: 35),
                    MediaChapter(id: "bm-3", title: "Finale", startTime: 85)
                ],
                collection_name: "Salt Cinema",
                token_standard: "ERC-721",
                contract_address: "0x4E8a1D2c3B4f5A6e7D8c9B0a1F2e3D4c5B6a7E8F",
                network: "Base"
            ),
            OpenSeaAsset(
                id: 2003,
                image_url: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=800&auto=format&fit=crop",
                name: "Midnight Signal",
                external_link: "https://opensea.io",
                traits: [
                    OpenSeaAssetTrait(trait_type: "Media Type", value: "Song"),
                    OpenSeaAssetTrait(trait_type: "Artist", value: "Aurelia Wave"),
                    OpenSeaAssetTrait(trait_type: "Audio Format", value: "Stereo"),
                    OpenSeaAssetTrait(trait_type: "Edition", value: "1 / 100")
                ],
                description: "Original electronic single mastered for stereo playback and collected directly on-chain.",
                permalink: "https://opensea.io",
                animation_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
                creator_name: "Aurelia Wave",
                release_date: nil,
                media_kind_hint: .song,
                audio_format: "Stereo",
                transcript_or_lyrics: """
                Static hums across the skyline
                Neon waves in silver light
                Every pulse a distant echo
                Carried softly through the night

                Hold the frequency unbroken
                Let the warm horizon glow
                Midnight signal in the stereo
                Moving steady, moving slow
                """,
                chapters: [],
                collection_name: "Aurelia Editions",
                token_standard: "ERC-1155",
                contract_address: "0x9C1b2E3f4A5d6C7b8E9f0A1b2C3d4E5f6A7b8C9D",
                network: "Ethereum"
            ),
            OpenSeaAsset(
                id: 2004,
                image_url: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=800&auto=format&fit=crop",
                name: "Glass Horizon",
                external_link: "https://opensea.io",
                traits: [
                    OpenSeaAssetTrait(trait_type: "Media Type", value: "Song"),
                    OpenSeaAssetTrait(trait_type: "Artist", value: "Solstice Collective"),
                    OpenSeaAssetTrait(trait_type: "Audio Format", value: "Lossless"),
                    OpenSeaAssetTrait(trait_type: "Edition", value: "Genesis")
                ],
                description: "Ambient synth edition paired with lossless mastering and collector provenance.",
                permalink: "https://opensea.io",
                animation_url: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
                creator_name: "Solstice Collective",
                release_date: nil,
                media_kind_hint: .song,
                audio_format: "Lossless",
                transcript_or_lyrics: """
                Refractions on the morning glass
                Chords dissolve as shadows pass
                Quiet rhythm in the room
                Analog and crystal bloom
                """,
                chapters: [],
                collection_name: "Solstice Masters",
                token_standard: "ERC-721",
                contract_address: "0x3F2e1D0c9B8a7F6e5D4c3B2a1F0e9D8c7B6a5F4E",
                network: "Ethereum"
            ),
            OpenSeaAsset(
                id: 1001,
                image_url: "https://i.seadn.io/gae/Ju9CkWtV-1Okvf45wo8UctR-M9He2PjILP0oOvxE89AyiPPGtrR3gysu1Zgy0hjd2xKIgjJJtWIc0ybj4Vd7wv8t3pxDGHoJBzDB?w=500&auto=format",
                name: "Salt Orb #01",
                external_link: "https://opensea.io",
                traits: [
                    OpenSeaAssetTrait(trait_type: "Edition", value: "Genesis"),
                    OpenSeaAssetTrait(trait_type: "Palette", value: "Monochrome")
                ],
                description: "A minimalist on-chain digital object for Salt.",
                permalink: "https://opensea.io",
                collection_name: "Salt Objects",
                token_standard: "ERC-721",
                contract_address: "0x1A2b3C4d5E6f7A8b9C0d1E2f3A4b5C6d7E8f9A0B",
                network: "Ethereum"
            ),
            OpenSeaAsset(
                id: 1002,
                image_url: svgDataURL,
                name: "Square on Circle #42",
                external_link: "https://opensea.io",
                traits: [
                    OpenSeaAssetTrait(trait_type: "Format", value: "SVG"),
                    OpenSeaAssetTrait(trait_type: "Geometry", value: "Square + Circle")
                ],
                description: "Vector emblem inspired by the Salt mark.",
                permalink: "https://opensea.io",
                collection_name: "Salt Objects",
                token_standard: "ERC-721",
                contract_address: "0x1A2b3C4d5E6f7A8b9C0d1E2f3A4b5C6d7E8f9A0B",
                network: "Ethereum"
            )
        ]
    }
}

let oneETHinWEI: Double = 1000000000000000000 // 18 decimals to divide amounts by

struct ReverseENSLookupResponse: Codable, Sendable {
    var address: String
}

struct OpenSeaAssetsResponse: Codable, Sendable {
    var assets: [OpenSeaAsset]
}

struct OpenSeaV2NFTsResponse: Codable, Sendable {
    var nfts: [OpenSeaV2NFT]
}

struct OpenSeaV2NFT: Codable, Sendable {
    var identifier: String?
    var name: String?
    var description: String?
    var image_url: String?
    var display_image_url: String?
    var animation_url: String?
    var display_animation_url: String?
    var collection: String?
    var contract: String?
    var token_standard: String?
    var updated_at: String?
    var opensea_url: String?
    
    func toOpenSeaAsset() -> OpenSeaAsset {
        let numericId = Int(identifier ?? "") ?? abs((identifier ?? UUID().uuidString).hashValue)
        let formattedDate = Self.formatISODate(updated_at)
        let formattedCollection = collection?.replacingOccurrences(of: "-", with: " ").capitalized
        return OpenSeaAsset(
            id: numericId,
            image_url: display_image_url ?? image_url ?? "",
            name: name,
            external_link: opensea_url,
            traits: [],
            description: description,
            permalink: opensea_url ?? "https://opensea.io",
            animation_url: display_animation_url ?? animation_url,
            creator_name: formattedCollection,
            release_date: formattedDate,
            collection_name: formattedCollection,
            token_standard: token_standard?.uppercased(),
            contract_address: contract,
            network: "Ethereum"
        )
    }

    private static func formatISODate(_ iso: String?) -> String? {
        guard let iso, !iso.isEmpty else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = parser.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}

struct OpenSeaAsset: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let image_url: String
    let name: String?
    let external_link: String?
    let traits: [OpenSeaAssetTrait]
    let description: String?
    let permalink: String
    let animation_url: String?
    let creator_name: String?
    let release_date: String?
    let media_kind_hint: NFTMediaKind?
    let audio_format: String?
    let transcript_or_lyrics: String?
    let chapters: [MediaChapter]
    let collection_name: String?
    let token_standard: String?
    let contract_address: String?
    let network: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case image_url
        case name
        case external_link
        case traits
        case description
        case permalink
        case animation_url
        case creator_name
        case release_date
        case media_kind_hint
        case audio_format
        case transcript_or_lyrics
        case chapters
        case collection_name
        case token_standard
        case contract_address
        case network
    }
    
    init(
        id: Int,
        image_url: String,
        name: String?,
        external_link: String?,
        traits: [OpenSeaAssetTrait],
        description: String?,
        permalink: String,
        animation_url: String? = nil,
        creator_name: String? = nil,
        release_date: String? = nil,
        media_kind_hint: NFTMediaKind? = nil,
        audio_format: String? = nil,
        transcript_or_lyrics: String? = nil,
        chapters: [MediaChapter] = [],
        collection_name: String? = nil,
        token_standard: String? = nil,
        contract_address: String? = nil,
        network: String? = "Ethereum"
    ) {
        self.id = id
        self.image_url = image_url
        self.name = name
        self.external_link = external_link
        self.traits = traits
        self.description = description
        self.permalink = permalink
        self.animation_url = animation_url
        self.creator_name = creator_name
        self.release_date = release_date
        self.media_kind_hint = media_kind_hint
        self.audio_format = audio_format
        self.transcript_or_lyrics = transcript_or_lyrics
        self.chapters = chapters
        self.collection_name = collection_name
        self.token_standard = token_standard
        self.contract_address = contract_address
        self.network = network
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(Int.self, forKey: .id)) ?? Int.random(in: 1...999_999)
        self.image_url = (try? container.decodeIfPresent(String.self, forKey: .image_url)) ?? ""
        self.name = try? container.decodeIfPresent(String.self, forKey: .name)
        self.external_link = try? container.decodeIfPresent(String.self, forKey: .external_link)
        self.traits = (try? container.decodeIfPresent([OpenSeaAssetTrait].self, forKey: .traits)) ?? []
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.permalink = (try? container.decodeIfPresent(String.self, forKey: .permalink)) ?? "https://opensea.io"
        self.animation_url = try? container.decodeIfPresent(String.self, forKey: .animation_url)
        self.creator_name = try? container.decodeIfPresent(String.self, forKey: .creator_name)
        self.release_date = try? container.decodeIfPresent(String.self, forKey: .release_date)
        self.media_kind_hint = try? container.decodeIfPresent(NFTMediaKind.self, forKey: .media_kind_hint)
        self.audio_format = try? container.decodeIfPresent(String.self, forKey: .audio_format)
        self.transcript_or_lyrics = try? container.decodeIfPresent(String.self, forKey: .transcript_or_lyrics)
        self.chapters = (try? container.decodeIfPresent([MediaChapter].self, forKey: .chapters)) ?? []
        self.collection_name = try? container.decodeIfPresent(String.self, forKey: .collection_name)
        self.token_standard = try? container.decodeIfPresent(String.self, forKey: .token_standard)
        self.contract_address = try? container.decodeIfPresent(String.self, forKey: .contract_address)
        self.network = (try? container.decodeIfPresent(String.self, forKey: .network)) ?? "Ethereum"
    }
    
    func isSVG() -> Bool {
        return self.image_url.lowercased().hasSuffix("svg") || self.image_url.hasPrefix("data:image/svg+xml")
    }

    var isPlayableMedia: Bool {
        resolvedMediaItem() != nil
    }

    func resolvedMediaItem() -> MediaItem? {
        guard let streamURL = MediaURLResolver.resolve(animation_url) else { return nil }
        guard let kind = MediaURLResolver.inferMediaKind(
            streamURL: streamURL,
            explicitHint: media_kind_hint,
            traits: traits,
            description: description
        ) else {
            return nil
        }

        let traitCreator = traitValue(matching: ["artist", "host", "director", "creator", "author", "producer"])
        let creator = (creator_name?.isEmpty == false ? creator_name : nil)
            ?? traitCreator
            ?? (kind.usesPodcastSkipControls ? "Unknown Host" : "Unknown Artist")

        let traitDate = traitValue(matching: ["date", "release date", "published", "air date"])
        let dateText = (release_date?.isEmpty == false ? release_date : nil) ?? traitDate

        let traitAudioFormat = traitValue(matching: ["audio format", "audio", "quality", "format"])
        let qualityBadge: String = {
            if let audio_format, !audio_format.isEmpty { return audio_format }
            if let traitAudioFormat, !traitAudioFormat.isEmpty,
               ["stereo", "lossless", "spatial", "dolby atmos", "hi-res", "mono"].contains(traitAudioFormat.lowercased()) {
                return traitAudioFormat
            }
            return "Stereo"
        }()

        let artworkURL = MediaURLResolver.resolve(image_url)
        let permalinkURL = URL(string: permalink)

        return MediaItem(
            id: "nft-\(id)",
            assetID: id,
            kind: kind,
            title: name ?? "Untitled",
            creator: creator,
            releaseDateText: dateText,
            artworkURL: artworkURL,
            streamURL: streamURL,
            audioFallbackURL: nil,
            durationHint: nil,
            audioQualityBadge: qualityBadge,
            lyricsOrTranscript: transcript_or_lyrics,
            chapters: chapters,
            permalinkURL: permalinkURL,
            sourceAsset: self
        )
    }

    private func traitValue(matching keys: [String]) -> String? {
        for key in keys {
            if let match = traits.first(where: { $0.trait_type.lowercased() == key }), !match.value.isEmpty {
                return match.value
            }
        }
        return nil
    }
}

struct OpenSeaAssetTrait: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(trait_type)-\(value)" }
    var trait_type: String
    var value: String
    
    enum CodingKeys: String, CodingKey {
        case trait_type
        case value
    }
    
    init(trait_type: String, value: String) {
        self.trait_type = trait_type
        self.value = value
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.trait_type = (try? container.decode(String.self, forKey: .trait_type)) ?? "Property"
        if let strValue = try? container.decode(String.self, forKey: .value) {
            self.value = strValue
        } else if let intValue = try? container.decode(Int.self, forKey: .value) {
            self.value = "\(intValue)"
        } else if let doubleValue = try? container.decode(Double.self, forKey: .value) {
            self.value = "\(doubleValue)"
        } else {
            self.value = ""
        }
    }
}

struct Token: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let name: String
    let symbol: String
    let quantity: String?
    let price: Price?
    let iconURL: String?
    
    func value() -> Double {
        guard let priceValue = self.price?.value, self.quantity != nil else {
            return 0
        }
        return priceValue * self.tokenQuantity()
    }
    
    func tokenQuantity() -> Double {
        guard let quantity = self.quantity else { return 0 }
        return (Double(quantity) ?? 0) / oneETHinWEI
    }
    
    func percentChange() -> String {
        if let relativeChange = self.price?.relative_change {
            return String(format: "%.2f%%", relativeChange)
        } else {
            return "0%"
        }
    }
}

struct Price: Equatable, Hashable, Sendable {
    let value: Double
    let relative_change: Double
}

struct Fee: Sendable {
    let value: Double
    let price: Double
    
    func feePrice() -> Double {
        return self.price * self.feeValue()
    }
    
    func feeValue() -> Double {
        return self.value / oneETHinWEI
    }
}

enum TransactionCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case foodAndDrinks = "Food & Drinks"
    case entertainment = "Entertainment"
    case shopping = "Shopping"
    case travel = "Travel"
    case health = "Health"
    case transportation = "Transportation"
    case services = "Services"
    
    var id: String { rawValue }
    
    var symbolName: String {
        switch self {
        case .foodAndDrinks: return "fork.knife"
        case .entertainment: return "star.fill"
        case .shopping: return "bag.fill"
        case .travel: return "airplane"
        case .health: return "heart.fill"
        case .transportation: return "car.fill"
        case .services: return "storefront.fill"
        }
    }
    
    var uiColor: UIColor {
        switch self {
        case .foodAndDrinks:
            return UIColor(red: 0.97, green: 0.56, blue: 0.23, alpha: 1.0)
        case .entertainment:
            return UIColor(red: 0.95, green: 0.39, blue: 0.79, alpha: 1.0)
        case .shopping:
            return UIColor(red: 0.96, green: 0.74, blue: 0.15, alpha: 1.0)
        case .travel:
            return UIColor(red: 0.13, green: 0.79, blue: 0.20, alpha: 1.0)
        case .health:
            return UIColor(red: 0.99, green: 0.34, blue: 0.32, alpha: 1.0)
        case .transportation:
            return UIColor(red: 0.17, green: 0.56, blue: 1.00, alpha: 1.0)
        case .services:
            return UIColor(red: 0.59, green: 0.45, blue: 1.00, alpha: 1.0)
        }
    }
    
    @MainActor
    private static var cachedMenuIcons: [TransactionCategory: UIImage] = [:]
    
    @MainActor
    var menuIcon: UIImage {
        if let cached = Self.cachedMenuIcons[self] {
            return cached
        }
        let rendered = badgeIcon(size: 28)
        Self.cachedMenuIcons[self] = rendered
        return rendered
    }
    
    @MainActor
    func badgeIcon(size: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        let img = renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            let cornerRadius = size * 0.25
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            uiColor.setFill()
            path.fill()
            
            let pointSize = size * 0.46
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
            if self == .shopping {
                // Draw the two-bag shopping icon (taller bag behind on left, wider bag in front on right)
                let cgContext = context.cgContext
                cgContext.saveGState()
                UIColor.white.setFill()
                UIColor.white.setStroke()
                
                // Back bag (left, taller)
                let backRect = CGRect(x: size * 0.23, y: size * 0.34, width: size * 0.32, height: size * 0.38)
                let backBag = UIBezierPath(roundedRect: backRect, cornerRadius: size * 0.04)
                backBag.fill()
                
                // Back bag handle
                let backHandle = UIBezierPath(
                    arcCenter: CGPoint(x: backRect.midX, y: backRect.minY),
                    radius: size * 0.075,
                    startAngle: .pi,
                    endAngle: 0,
                    clockwise: true
                )
                backHandle.lineWidth = max(1.4, size * 0.055)
                backHandle.stroke()
                
                // Cutout around front bag for separation
                let frontRect = CGRect(x: size * 0.41, y: size * 0.44, width: size * 0.36, height: size * 0.29)
                let cutoutRect = frontRect.insetBy(dx: -size * 0.035, dy: -size * 0.035)
                let cutoutBag = UIBezierPath(roundedRect: cutoutRect, cornerRadius: size * 0.05)
                uiColor.setFill()
                cutoutBag.fill()
                
                // Front bag (right, wider)
                UIColor.white.setFill()
                let frontBag = UIBezierPath(roundedRect: frontRect, cornerRadius: size * 0.04)
                frontBag.fill()
                
                // Horizontal accent line across front bag
                uiColor.setStroke()
                let flapLine = UIBezierPath()
                flapLine.lineWidth = max(1.1, size * 0.04)
                flapLine.move(to: CGPoint(x: frontRect.minX + size * 0.03, y: frontRect.minY + frontRect.height * 0.42))
                flapLine.addLine(to: CGPoint(x: frontRect.maxX - size * 0.03, y: frontRect.minY + frontRect.height * 0.42))
                flapLine.stroke()
                
                // Front bag handle
                UIColor.white.setStroke()
                let frontHandle = UIBezierPath(
                    arcCenter: CGPoint(x: frontRect.midX, y: frontRect.minY),
                    radius: size * 0.065,
                    startAngle: .pi,
                    endAngle: 0,
                    clockwise: true
                )
                frontHandle.lineWidth = max(1.3, size * 0.05)
                frontHandle.stroke()
                cgContext.restoreGState()
            } else if let symbol = UIImage(systemName: symbolName, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let cgContext = context.cgContext
                cgContext.saveGState()
                cgContext.translateBy(x: size / 2, y: size / 2)
                if self == .travel {
                    cgContext.rotate(by: -.pi / 4)
                }
                let symSize = symbol.size
                let drawRect = CGRect(x: -symSize.width / 2, y: -symSize.height / 2, width: symSize.width, height: symSize.height)
                symbol.draw(in: drawRect)
                
                if self == .health {
                    // Draw ECG heartbeat line across the white heart
                    uiColor.setStroke()
                    let ecg = UIBezierPath()
                    ecg.lineWidth = max(1.3, size * 0.05)
                    ecg.lineCapStyle = .round
                    ecg.lineJoinStyle = .round
                    let w = symSize.width * 0.38
                    let h = symSize.height * 0.22
                    ecg.move(to: CGPoint(x: -w, y: 0))
                    ecg.addLine(to: CGPoint(x: -w * 0.35, y: 0))
                    ecg.addLine(to: CGPoint(x: -w * 0.15, y: -h))
                    ecg.addLine(to: CGPoint(x: w * 0.12, y: h * 0.85))
                    ecg.addLine(to: CGPoint(x: w * 0.32, y: 0))
                    ecg.addLine(to: CGPoint(x: w, y: 0))
                    ecg.stroke()
                }
                cgContext.restoreGState()
            }
        }
        return img.withRenderingMode(.alwaysOriginal)
    }
}

struct Transaction: Identifiable, Sendable {
    let id: String
    let token: Token?
    let value: Double?
    let price: Double?
    let type: String
    let mined_at: Int
    let hash: String
    let status: String
    let block_number: Int
    let address_from: String?
    let address_to: String?
    let fee: Fee?
    var network: String = "Base"
    var merchantName: String? = "Name of Business"
    
    func transactionQuantity() -> Double {
        return (self.value ?? 0) / oneETHinWEI
    }

    func transactionValue() -> Double {
        guard let price = self.price, self.value != nil else {
            return 0
        }
        return price * self.transactionQuantity()
    }
    
    func fullTotalValue() -> Double {
        return transactionValue() + (fee?.feePrice() ?? 0)
    }
    
    func title() -> String {
        return "\(self.type.capitalized) \(self.token?.symbol.uppercased() ?? "")"
    }
}

nonisolated(unsafe) let manager = SocketManager(
    socketURL: URL(string: "wss://api-v4.zerion.io")!,
    config: [
        .log(false),
        .extraHeaders(["Origin": "https://localhost:3000"]),
        .forceWebsockets(true),
        .connectParams(["api_token": "Demo.ukEVQp6L5vfgxcz4sBke7XvS873GMYHy"]),
        .version(.two),
        .secure(true)
    ]
)

nonisolated(unsafe) let socket = manager.defaultSocket
nonisolated(unsafe) let addressSocket = manager.socket(forNamespace: "/address")

@MainActor
class Network: ObservableObject {
    init() {
        connect()
    }
    
    func connect() {
        addressSocket.connect()
    }
    
    func disconnect() {
        addressSocket.disconnect()
        addressSocket.removeAllHandlers()
    }
}
