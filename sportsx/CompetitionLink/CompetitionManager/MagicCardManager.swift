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
    let lucky: Float
    let energy: Int
    let grade: String
    let description: String
}

// todo: 添加card前对device binding情况进行检查
class MagicCardManager: ObservableObject {
    static let shared = MagicCardManager()
    
    @Published var availableCards: [MagicCard] = []
    
    
    private init() {
        //fetchUserCards()
    }
    
    // todo
    func fetchUserCards() {
        // 模拟网络请求
        //var tempCards: [MagicCard] = []
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            //guard let self = self else { return }
            let fetchedCards = [
                MagicCard(id: "card1", modelID: "model_001", name: "Fire Dragon", type: "团队", level: "5", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 86.7, energy: 91, grade: "B+", description: "test"),
                MagicCard(id: "card2", modelID: "model_001", name: "Water Serpent", type: "魔法", level: "3", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000001, lucky: 31.2, energy: 80, grade: "B", description: "test"),
                MagicCard(id: "card3", modelID: "model_002", name: "Earth Golem", type: "动作", level: "4", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000010, lucky: 96.5, energy: 100, grade: "S", description: "test"),
                MagicCard(id: "card4", modelID: "model_003", name: "Wind Phoenix", type: "动作", level: "2", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000101, lucky: 81.9, energy: 100, grade: "A-", description: "test"),
                MagicCard(id: "card5", modelID: "model_003", name: "Lightning Tiger", type: "陷阱", level: "6", imageURL: "Ads", compensationValue: 0, sensorLocation: 0b000101, lucky: 50.0, energy: 32, grade: "C-", description: "test"),
                // 添加更多卡片
            ]
            DispatchQueue.main.async {
                self.availableCards = fetchedCards
            }
            //self.sensorRequest = 1
        }
    }
    
    
    
    
}
