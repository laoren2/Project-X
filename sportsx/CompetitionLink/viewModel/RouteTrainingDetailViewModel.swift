//
//  RouteTrainingDetailViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2026/5/7.
//

import Foundation

class BikeRouteTrainingRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: BikeRouteTrainingRecordDetailInfo?
    
    @Published var basePath: [PathPoint] = []
    @Published var pathData: [BikeRouteTrainingPathPoint] = []
    @Published var samplePath: [BikeRouteTrainingSamplePathPoint] = []
    
    
    init(recordID: String) {
        self.recordID = recordID
        self.recordDetailInfo = nil
        queryRecordDetail()
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/training/bike/query_route_training_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRouteTrainingRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = BikeRouteTrainingRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = BikePathPointTool.computeRouteTrainingSamplePoints(pathData: self.pathData)
                    }
                }
            default: break
            }
        }
    }
}

struct BikeRouteTrainingRecordDetailInfo {
    let originalTime: Double            // 原始成绩
    let finalTime: Double               // 有效成绩
    let penaltyTime: Double             // 总罚时
    let cardBonus: [CardBonusInfo]
    let totalCardTime: Double           // 总卡牌时间收益
    let settlements: TrainingSettlementsInfo            // 结算数据
    
    init(from detail: BikeRouteTrainingRecordDetailResponse) {
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.penaltyTime = detail.penalty_time
        
        var myBonus: [CardBonusInfo] = []
        for bonus in detail.card_bonus {
            myBonus.append(
                CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
            )
        }
        self.cardBonus = myBonus
        
        var cardTime: Double = 0
        for card_bonus in detail.card_bonus {
            cardTime += card_bonus.bonus_time
        }
        self.totalCardTime = cardTime
        
        var xp: Int = 0
        var state_value: Int = 0
        var temp_assets: [CCUpdateResponse] = []
        if let amount = detail.settlements["xp"]?.intValue {
            xp = amount
        }
        if let amount = detail.settlements["training_state"]?.intValue {
            state_value = amount
        }
        for type in CCAssetType.allCases {
            if let amount = detail.settlements["\(type.rawValue)"]?.intValue {
                temp_assets.append(CCUpdateResponse(ccasset_type: type, new_ccamount: amount))
            }
        }
        self.settlements = TrainingSettlementsInfo(xp: xp, state_value: state_value, cc_rewards: temp_assets)
    }
}

struct BikeRouteTrainingRecordDetailResponse: Codable {
    let original_time: Double                   // 原始成绩
    let final_time: Double                      // 有效成绩 （ = 原始成绩 + 总罚时 - 所有卡牌的奖励时间 ）
    let penalty_time: Double                    // 总罚时
    let path: [BikeRouteTrainingPathPoint]      // 训练路径记录
    let card_bonus: [CardBonusDTO]              // 所有卡牌的奖励时间
    let settlements: JSONValue                  // 比赛结算
}

struct BikeRouteTrainingSamplePathPoint {
    var speed_avg: Double
    let altitude_avg: Double
    let heart_rate_min: Double?
    let heart_rate_max: Double?
    let power_avg: Double?
    let pedal_cadence_avg: Double?
    let timestamp_min: TimeInterval
    let timestamp_max: TimeInterval
}

class RunningRouteTrainingRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: RunningRouteTrainingRecordDetailInfo?
    
    @Published var basePath: [PathPoint] = []
    @Published var pathData: [RunningRouteTrainingPathPoint] = []
    @Published var samplePath: [RunningRouteTrainingSamplePathPoint] = []
    
    
    init(recordID: String) {
        self.recordID = recordID
        self.recordDetailInfo = nil
        queryRecordDetail()
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/training/running/query_route_training_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRouteTrainingRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = RunningRouteTrainingRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = RunningPathPointTool.computeRouteTrainingSamplePoints(pathData: self.pathData)
                    }
                }
            default: break
            }
        }
    }
}

struct RunningRouteTrainingRecordDetailInfo {
    let originalTime: Double            // 原始成绩
    let finalTime: Double               // 有效成绩
    let penaltyTime: Double             // 总罚时
    let cardBonus: [CardBonusInfo]
    let totalCardTime: Double           // 总卡牌时间收益
    let settlements: TrainingSettlementsInfo            // 结算数据
    
    init(from detail: RunningRouteTrainingRecordDetailResponse) {
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.penaltyTime = detail.penalty_time
        
        var myBonus: [CardBonusInfo] = []
        for bonus in detail.card_bonus {
            myBonus.append(
                CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
            )
        }
        self.cardBonus = myBonus
        
        var cardTime: Double = 0
        for card_bonus in detail.card_bonus {
            cardTime += card_bonus.bonus_time
        }
        self.totalCardTime = cardTime
        
        var xp: Int = 0
        var state_value: Int = 0
        var temp_assets: [CCUpdateResponse] = []
        if let amount = detail.settlements["xp"]?.intValue {
            xp = amount
        }
        if let amount = detail.settlements["training_state"]?.intValue {
            state_value = amount
        }
        for type in CCAssetType.allCases {
            if let amount = detail.settlements["\(type.rawValue)"]?.intValue {
                temp_assets.append(CCUpdateResponse(ccasset_type: type, new_ccamount: amount))
            }
        }
        self.settlements = TrainingSettlementsInfo(xp: xp, state_value: state_value, cc_rewards: temp_assets)
    }
}

struct RunningRouteTrainingRecordDetailResponse: Codable {
    let original_time: Double                   // 原始成绩
    let final_time: Double                      // 有效成绩 （ = 原始成绩 + 总罚时 - 所有卡牌的奖励时间 ）
    let penalty_time: Double                    // 总罚时
    let path: [RunningRouteTrainingPathPoint]      // 训练路径记录
    let card_bonus: [CardBonusDTO]              // 所有卡牌的奖励时间
    let settlements: JSONValue                  // 比赛结算
}

struct RunningRouteTrainingSamplePathPoint {
    var speed_avg: Double
    let altitude_avg: Double
    let heart_rate_min: Double?
    let heart_rate_max: Double?
    let power_avg: Double?
    let step_cadence_avg: Double?
    let vertical_amplitude_avg: Double?
    let touchdown_time_avg: Double?
    let step_size_avg: Double?
    let timestamp_min: TimeInterval
    let timestamp_max: TimeInterval
}
