//
//  MagicCardManager.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import Foundation

struct MagicCard: Identifiable, Codable, Equatable {
    let id: String
    let modelID: String // 对应PredictionModel & MLModel
    let name: String
    let type: String
    let level: String
    let imageURL: String
    let compensationValue: Double
}

class MagicCardManager: ObservableObject {
    static let shared = MagicCardManager()
    
    var availableCards: [MagicCard] = []
    var selectedCards: [MagicCard] = []
    
    private init() {
        //fetchUserCards()
    }
    
    func fetchUserCards() async {
        // 模拟网络请求
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { // 模拟延迟
            let fetchedCards = [
                MagicCard(id: "card1", modelID: "model_001", name: "Fire Dragon", type: "Dragon", level: "5", imageURL: "Ads", compensationValue: 0),
                MagicCard(id: "card2", modelID: "model_001", name: "Water Serpent", type: "Serpent", level: "3", imageURL: "Ads", compensationValue: 0),
                MagicCard(id: "card3", modelID: "model_002", name: "Earth Golem", type: "Golem", level: "4", imageURL: "Ads", compensationValue: 0),
                MagicCard(id: "card4", modelID: "model_003", name: "Wind Phoenix", type: "Phoenix", level: "2", imageURL: "Ads", compensationValue: 0),
                MagicCard(id: "card5", modelID: "model_003", name: "Lightning Tiger", type: "Tiger", level: "6", imageURL: "Ads", compensationValue: 0),
                // 添加更多卡片
            ]
            DispatchQueue.main.async {
                self.availableCards = fetchedCards
            }
        }
    }
    
    func SelectedCards(_ cards: [MagicCard]) {
        guard cards.count <= 3 else {
            print("最多选择3个卡片")
            return
        }
        self.selectedCards = cards
    }
    
    /*func saveSelectedCards(_ cards: [MagicCard]) {
        self.selectedCards = cards
        // 保存到UserDefaults
        if let data = try? JSONEncoder().encode(cards) {
            UserDefaults.standard.set(data, forKey: "selectedCards")
        }
    }
    
    func loadSelectedCards() {
        if let data = UserDefaults.standard.data(forKey: "selectedCards"),
           let cards = try? JSONDecoder().decode([MagicCard].self, from: data) {
            self.selectedCards = cards
        }
    }*/
}
