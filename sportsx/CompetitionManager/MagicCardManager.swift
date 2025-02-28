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
    // sensorLocation记录传感器设备要求
    // |---  +   +   +   +   +    +  |
    //       |   |   |   |   |    |
    //      WST  RF  LF  RH  LH  PHONE
    let sensorLocation: Int
}

// todo: 添加card前对device binding情况进行检查
class MagicCardManager: ObservableObject {
    static let shared = MagicCardManager()
    
    var availableCards: [MagicCard] = []
    @Published var selectedCards: [MagicCard] = []
    var sensorRequest: Int = 0
    
    private init() {
        //fetchUserCards()
    }
    
    // todo
    func fetchUserCards() async {
        // 模拟网络请求
        //var tempCards: [MagicCard] = []
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            //guard let self = self else { return }
            let fetchedCards = [
                MagicCard(id: "card1", modelID: "model_001", name: "Fire Dragon", type: "Dragon", level: "5", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001),
                MagicCard(id: "card2", modelID: "model_001", name: "Water Serpent", type: "Serpent", level: "3", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001),
                MagicCard(id: "card3", modelID: "model_002", name: "Earth Golem", type: "Golem", level: "4", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000010),
                MagicCard(id: "card4", modelID: "model_003", name: "Wind Phoenix", type: "Phoenix", level: "2", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000101),
                MagicCard(id: "card5", modelID: "model_003", name: "Lightning Tiger", type: "Tiger", level: "6", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000101),
                // 添加更多卡片
            ]
            self.availableCards = fetchedCards
            //self.sensorRequest = 1
        }
    }
    
    func SelectedCards(_ cards: [MagicCard]) {
        guard cards.count <= 3 else {
            print("最多选择3个卡片")
            return
        }
        for card in cards {
            sensorRequest |= card.sensorLocation
        }
        self.selectedCards = cards
    }
    
    func resetAll() {
        selectedCards.removeAll()
        sensorRequest = 0
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
