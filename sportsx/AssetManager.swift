//
//  AssetManager.swift
//  sportsx
//
//  集中管理虚拟货币的充值提现与消费
//
//  Created by 任杰 on 2025/3/13.
//

import Foundation


class AssetManager: ObservableObject {
    // ccasset资产
    @Published var coin: Int = 0
    @Published var coupon: Int = 0
    @Published var voucher: Int = 0
    @Published var stone1: Int = 0
    @Published var stone2: Int = 0
    @Published var stone3: Int = 0
    
    // cpasset资产
    @Published var cpassets: [CPAssetUserInfo] = []
    
    // 装备卡资产
    @Published var magicCards: [MagicCard] = []
    
    static let shared = AssetManager()
    
    private init() {}
    
    @MainActor
    func updateCCAsset(type: CCAssetType, newBalance: Int) {
        switch type {
        case .coin:
            coin = newBalance
        case .coupon:
            coupon = newBalance
        case .voucher:
            voucher = newBalance
        case .stone1:
            stone1 = newBalance
        case .stone2:
            stone2 = newBalance
        case .stone3:
            stone3 = newBalance
        }
    }
    
    @MainActor
    func updateCPAsset(assetID: String, newBalance: Int) {
        if let index = cpassets.firstIndex(where: { $0.asset_id == assetID }) {
            if newBalance > 0 {
                cpassets[index].amount = newBalance
            } else {
                cpassets.remove(at: index)
            }
        } else {
            queryCPAsset(with: assetID)
        }
    }
    
    func purchaseCPWithCC(assetID: String, amount: Int) {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "cpasset_id": assetID,
            "cpamount": "\(amount)"
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/asset/buy_cpasset", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: CC_CP_PurchaseResultResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.updateCCAsset(type: unwrappedData.ccasset_type, newBalance: unwrappedData.new_ccamount)
                        self.updateCPAsset(assetID: unwrappedData.cpasset_id, newBalance: unwrappedData.new_cpamount)
                    }
                }
            default: break
            }
        }
    }
    
    // 购买装备卡
    func purchaseMCWithCC(cardID: String) {
        guard var components = URLComponents(string: "/asset/buy_equip_card") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_def_id", value: cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: CC_MC_PurchaseResultResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.updateCCAsset(type: unwrappedData.ccasset_type, newBalance: unwrappedData.new_ccamount)
                        self.magicCards.append(MagicCard(from: unwrappedData.card))
                    }
                }
            default: break
            }
        }
    }
    
    // 销毁装备卡
    func destroyMagicCard(cardID: String) async {
        guard var components = URLComponents(string: "/asset/destroy_equip_card") else { return }
        components.queryItems = [
            URLQueryItem(name: "card_id", value: cardID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: UpgradePriceResponse.self, showLoadingToast: true, showSuccessToast: true, showErrorToast: true)
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                await MainActor.run {
                    for price in unwrappedData.prices {
                        updateCCAsset(type: price.ccasset_type, newBalance: price.new_ccamount)
                    }
                    if let index = magicCards.firstIndex(where: { $0.cardID == cardID }) {
                        magicCards.remove(at: index)
                    }
                }
            }
        default: break
        }
    }
    
    func queryCPAsset(with assetID: String) {
        guard var components = URLComponents(string: "/asset/query_user_cpasset") else { return }
        components.queryItems = [
            URLQueryItem(name: "asset_id", value: assetID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetUserInfoDTO.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    let cpAsset = CPAssetUserInfo(from: unwrappedData)
                    if cpAsset.amount > 0 {
                        DispatchQueue.main.async {
                            self.cpassets.insert(cpAsset, at: 0)
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func queryCCAssets() {
        let request = APIRequest(path: "/asset/query_user_ccassets", method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CCAssetResponse.self) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.coin = unwrappedData.coin_amount
                        self.coupon = unwrappedData.coupon_amount
                        self.voucher = unwrappedData.voucher_amount
                        self.stone1 = unwrappedData.stone1_amount
                        self.stone2 = unwrappedData.stone2_amount
                        self.stone3 = unwrappedData.stone3_amount
                    }
                }
            default: break
            }
        }
    }
    
    func queryCPAssets(withLoadingToast: Bool) async {
        await MainActor.run {
            cpassets.removeAll()
        }
        let request = APIRequest(path: "/asset/query_user_cpassets", method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: CPAssetUserResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                await MainActor.run {
                    for asset in unwrappedData.assets {
                        if asset.amount > 0 {
                            cpassets.append(CPAssetUserInfo(from: asset))
                        }
                    }
                }
            }
        default: break
        }
    }
    
    func queryMagicCards(withLoadingToast: Bool) async {
        await MainActor.run {
            magicCards.removeAll()
        }
        let request = APIRequest(path: "/asset/query_user_equip_cards", method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: MagicCardUserResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                await MainActor.run {
                    for card in unwrappedData.cards {
                        magicCards.append(MagicCard(from: card))
                    }
                }
            }
        default: break
        }
    }
    
    func resetAll() {
        coin = 0
        coupon = 0
        voucher = 0
        stone1 = 0
        stone2 = 0
        stone3 = 0
        cpassets = []
        magicCards = []
    }
    
    func fetchBalance() {
        // 调用 API 获取最新余额
    }
    
    func recharge(amount: Int) {
        // 处理充值请求，成功后更新coin
    }
    
    func withdraw(amount: Int) {
        // 处理提现请求
    }
}

enum CCAssetType: String, Codable, CaseIterable {
    case coin = "coin"
    case coupon = "coupon"
    case voucher = "voucher"
    case stone1 = "stone1"
    case stone2 = "stone2"
    case stone3 = "stone3"
    
    var iconName: String {
        switch self {
        case .coin:
            return "bitcoinsign.circle"
        case .coupon:
            return "creditcard"
        case .voucher:
            return "giftcard"
        case .stone1:
            return "suit.diamond"
        case .stone2:
            return "suit.diamond.fill"
        case .stone3:
            return "questionmark.diamond.fill"
        }
    }
}

struct AssetUpdateResponse: Codable {
    let ccassets: [CCUpdateResponse]
    let cpassets: [CPAssetResponse]
    let equip_cards: [MagicCardUserDTO]
}

struct CPAssetUserInfo: Identifiable {
    var id: String {asset_id}
    let asset_id: String
    let name: String
    let description: String
    let image_url: String
    var amount: Int
    
    init(from asset: CPAssetUserInfoDTO) {
        self.asset_id = asset.asset_id
        self.name = asset.name
        self.description = asset.description
        self.image_url = asset.image_url
        self.amount = asset.amount
    }
}

struct CPAssetUserInfoDTO: Codable {
    let asset_id: String
    let name: String
    let description: String
    let image_url: String
    let amount: Int
}

struct CPAssetUserResponse: Codable {
    let assets: [CPAssetUserInfoDTO]
}

struct CPAssetShopInfo: Identifiable {
    var id: String {asset_id}
    let asset_id: String
    let name: String
    let description: String
    let image_url: String
    let ccassetType: CCAssetType
    let price: Int
    
    init(from asset: CPAssetShopInfoDTO) {
        self.asset_id = asset.asset_id
        self.name = asset.name
        self.description = asset.description
        self.image_url = asset.image_url
        self.ccassetType = asset.ccasset_type
        self.price = asset.price
    }
}

struct CPAssetShopInfoDTO: Codable {
    let asset_id: String
    let name: String
    let description: String
    let image_url: String
    let ccasset_type: CCAssetType
    let price: Int
}

struct CPAssetShopResponse: Codable {
    let assets: [CPAssetShopInfoDTO]
}

struct CCAssetResponse: Codable {
    let coin_amount: Int
    let coupon_amount: Int
    let voucher_amount: Int
    let stone1_amount: Int
    let stone2_amount: Int
    let stone3_amount: Int
}

struct CPAssetResponse: Codable {
    let asset_id: String
    let new_balance: Int
}

class CC_CC_PurchaseResultResponse: Codable {
    let decrease_type: CCAssetType
    let decrease_amount: Int
    let increase_type: CCAssetType
    let increase_amount: Int
}

class CC_CP_PurchaseResultResponse: Codable {
    let ccasset_type: CCAssetType
    let new_ccamount: Int
    let cpasset_id: String
    let new_cpamount: Int
}

class CC_MC_PurchaseResultResponse: Codable {
    let ccasset_type: CCAssetType
    let new_ccamount: Int
    let card: MagicCardUserDTO
}

struct CCUpdateResponse: Codable, Identifiable {
    var id: String { ccasset_type.rawValue }
    let ccasset_type: CCAssetType
    let new_ccamount: Int
}

// 外设的传感器类型
enum SensorType: String, Codable {
    case AW = "applewatch"
    
    var displayName: String {
        switch self {
        case .AW: return "Apple Watch"
        }
    }
    
    var iconName: String {
        switch self {
        case .AW: return "applewatch"
        }
    }
}

struct MagicCardDef {
    let cardID: String
    //let typeName: String
    let defID: String
    let params: JSONValue
}

struct MagicCard: Identifiable, Equatable {
    let id: UUID
    let cardID: String
    let defID: String
    let name: String
    let sportType: SportName
    let level: Int              // 1-10级
    let levelSkill1: Int?       // 0-5级，level=3时解锁
    let levelSkill2: Int?       // 0-5级，level=6时解锁
    let levelSkill3: Int?       // 0-5级，level=10时解锁
    let imageURL: String
    // 传感器类型要求
    let sensorType: [SensorType]
    // 传感器绑定位置要求
    // |---  +   +   +   +   +    +  |
    //       |   |   |   |   |    |
    //      WST  RF  LF  RH  LH  PHONE
    let sensorLocation: Int?
    let lucky: Double
    let rarity: String
    let description: String
    let descriptionSkill1: String?
    let descriptionSkill2: String?
    let descriptionSkill3: String?
    let version: AppVersion
    
    let tags: [String]          // 过滤条件
    let cardDef: MagicCardDef
    
    init(from card: MagicCardUserDTO) {
        self.id = UUID()
        self.cardID = card.card_id
        self.defID = card.def_id
        self.name = card.name
        self.sportType = card.sport_type
        self.level = card.level
        self.levelSkill1 = card.levelSkill1
        self.levelSkill2 = card.levelSkill2
        self.levelSkill3 = card.levelSkill3
        self.imageURL = card.image_url
        if let sensorStrings = card.effect_def["sensor_type"]?.arrayValue?.compactMap({ $0.stringValue }) {
            self.sensorType = sensorStrings.compactMap { SensorType(rawValue: $0) }
        } else {
            self.sensorType = []
        }
        let location = card.effect_def["sensor_location"]?.intValue
        self.sensorLocation = location
        self.lucky = card.lucky
        self.rarity = card.rarity
        
        // 处理card.effect_def，将所有description中{{}}对应的值乘以multiplier
        var finalJsonValue: JSONValue = card.effect_def
        let baseKeys = card.description.extractKeys()       // 提取 {{xxx.xx}}
        finalJsonValue.applyingMultiplier(for: baseKeys, multiplier: card.multiplier)
        self.description = card.description.rendered(with: finalJsonValue)
        
        if let des1 = card.description_skill1, let mul = card.multiplier_skill1 {
            let skill1Keys = des1.extractKeys()
            finalJsonValue.applyingMultiplier(for: skill1Keys, multiplier: mul)
            self.descriptionSkill1 = des1.rendered(with: finalJsonValue)
        } else {
            self.descriptionSkill1 = nil
        }
        if let des2 = card.description_skill2, let mul = card.multiplier_skill2 {
            let skill2Keys = des2.extractKeys()
            finalJsonValue.applyingMultiplier(for: skill2Keys, multiplier: mul)
            self.descriptionSkill2 = des2.rendered(with: finalJsonValue)
        } else {
            self.descriptionSkill2 = nil
        }
        if let des3 = card.description_skill3, let mul = card.multiplier_skill3 {
            let skill3Keys = des3.extractKeys()
            finalJsonValue.applyingMultiplier(for: skill3Keys, multiplier: mul)
            self.descriptionSkill3 = des3.rendered(with: finalJsonValue)
        } else {
            self.descriptionSkill3 = nil
        }
        self.version = AppVersion(card.version)
        self.tags = card.tags
        self.cardDef = MagicCardDef(cardID: card.card_id, defID: card.def_id, params: finalJsonValue)
    }
    
    // 暂时复用MagicCardView和DetailView来展示商店卡牌信息
    // todo: 视图层面拆开
    init(withShopCard card: MagicCardShop) {
        self.id = UUID()
        self.cardID = card.def_id
        self.defID = card.def_id
        self.name = card.name
        self.sportType = card.sportType
        self.level = 0
        self.levelSkill1 = nil
        self.levelSkill2 = nil
        self.levelSkill3 = nil
        self.imageURL = card.imageURL
        self.sensorType = card.sensorType
        self.sensorLocation = card.sensorLocation
        self.lucky = -1
        self.rarity = card.rarity
        self.description = card.description
        self.descriptionSkill1 = card.descriptionSkill1
        self.descriptionSkill2 = card.descriptionSkill2
        self.descriptionSkill3 = card.descriptionSkill3
        self.version = card.version
        // 用不到cardDef和tags
        self.tags = []
        self.cardDef = MagicCardDef(cardID: "example_id", defID: "example_def_id", params: .null)
    }
    
    static func == (lhs: MagicCard, rhs: MagicCard) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MagicCardUserDTO: Codable {
    let card_id: String
    let def_id: String
    let name: String
    let sport_type: SportName
    let level: Int              // 1-10级
    let levelSkill1: Int?       // 0-5级，level=3时解锁
    let levelSkill2: Int?       // 0-5级，level=6时解锁
    let levelSkill3: Int?       // 0-5级，level=10时解锁
    let image_url: String
    let lucky: Double
    let rarity: String
    let description: String
    let description_skill1: String?
    let description_skill2: String?
    let description_skill3: String?
    let multiplier: Double
    let multiplier_skill1: Double?
    let multiplier_skill2: Double?
    let multiplier_skill3: Double?
    let version: String
    
    //let type_name: String
    let tags: [String]
    let effect_def: JSONValue
}

struct MagicCardUserResponse: Codable {
    let cards: [MagicCardUserDTO]
}

struct MagicCardShop: Identifiable, Equatable {
    let id: UUID
    let def_id: String
    let name: String
    let sportType: SportName
    let imageURL: String
    let sensorType: [SensorType]
    let sensorLocation: Int?
    let rarity: String
    let description: String
    let descriptionSkill1: String?
    let descriptionSkill2: String?
    let descriptionSkill3: String?
    let version: AppVersion
    let ccasset_type: CCAssetType
    let price: Int
    
    init(from card: MagicCardShopDTO) {
        self.id = UUID()
        self.def_id = card.def_id
        self.name = card.name
        self.sportType = card.sport_type
        self.imageURL = card.image_url
        if let sensorStrings = card.effect_config["sensor_type"]?.arrayValue?.compactMap({ $0.stringValue }) {
            self.sensorType = sensorStrings.compactMap { SensorType(rawValue: $0) }
        } else {
            self.sensorType = []
        }
        let location = card.effect_config["sensor_location"]?.intValue
        self.sensorLocation = location
        self.rarity = card.rarity
        self.description = card.description.rendered(with: card.effect_config)
        if let description1 = card.skill1_description {
            self.descriptionSkill1 = description1.rendered(with: card.effect_config)
        } else {
            self.descriptionSkill1 = nil
        }
        if let description2 = card.skill2_description {
            self.descriptionSkill2 = description2.rendered(with: card.effect_config)
        } else {
            self.descriptionSkill2 = nil
        }
        if let description3 = card.skill3_description {
            self.descriptionSkill3 = description3.rendered(with: card.effect_config)
        } else {
            self.descriptionSkill3 = nil
        }
        self.version = AppVersion(card.version)
        self.ccasset_type = card.ccasset_type
        self.price = card.price
    }
    
    static func == (lhs: MagicCardShop, rhs: MagicCardShop) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MagicCardShopDTO: Codable {
    let def_id: String
    let name: String
    let sport_type: SportName
    let image_url: String
    let rarity: String
    let description: String
    let skill1_description: String?
    let skill2_description: String?
    let skill3_description: String?
    let version: String
    let effect_config: JSONValue
    
    let ccasset_type: CCAssetType
    let price: Int
}

struct MagicCardShopResponse: Codable {
    let cards: [MagicCardShopDTO]
}
