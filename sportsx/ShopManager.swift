//
//  ShopManager.swift
//  sportsx
//
//  Created by 任杰 on 2026/1/13.
//

import Foundation


class ShopManager: ObservableObject {
    @Published var cpassets: [CPAssetShopInfo] = []
    @Published var magicCards: [MagicCardShop] = []
    
    @Published var selectedAsset: CommonAssetShopInfo? = nil
    
    static let shared = ShopManager()
    
    private init() {}
    
    func queryCPAssets(withLoadingToast: Bool) async {
        await MainActor.run {
            selectedAsset = nil
        }
        let request = APIRequest(path: "/asset/query_cpassets_on_shelves", method: .get)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: CPAssetShopResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                let newAssets = unwrappedData.assets.map { CPAssetShopInfo(from: $0) }
                await MainActor.run {
                    cpassets = newAssets
                }
            }
        case .failure:
            await MainActor.run {
                cpassets = []
            }
        }
    }
    
    func queryMagicCards(withLoadingToast: Bool) async {
        await MainActor.run {
            selectedAsset = nil
        }
        let request = APIRequest(path: "/asset/query_equip_cards_on_shelves", method: .get)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: MagicCardShopResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                let newCards = unwrappedData.cards.map { MagicCardShop(from: $0) }
                await MainActor.run {
                    magicCards = newCards
                }
            }
        case .failure:
            await MainActor.run {
                magicCards = []
            }
        }
    }
}
