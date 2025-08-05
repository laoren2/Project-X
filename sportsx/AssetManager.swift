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
    
    // cpasset资产
    @Published var cpassets: [CPAssetUserInfo] = []
    
    // 装备卡资产
    @Published var equipCards: [EquipCardUserInfo] = []
    
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

enum CCAssetType: String, Codable {
    case coin = "coin"
    case coupon = "coupon"
    case voucher = "voucher"
    
    var iconName: String {
        switch self {
        case .coin:
            return "bitcoinsign.circle"
        case .coupon:
            return "creditcard"
        case .voucher:
            return "giftcard"
        }
    }
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

struct EquipCardUserInfo {
    
}

struct EquipCardShopInfo {
    
}
