//
//  RecordDetailViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/11.
//

import Foundation

class BikeRaceRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: BikeRaceRecordDetailInfo?
    
    @Published var basePath: [PathPoint] = []
    @Published var pathData: [BikePathPoint] = []
    @Published var samplePath: [BikeSamplePathPoint] = []
    
    
    init(recordID: String) {
        self.recordID = recordID
        self.recordDetailInfo = nil
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/competition/bike/query_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        if UserManager.shared.isLoggedIn {
            components.queryItems?.append(URLQueryItem(name: "user_id", value: UserManager.shared.user.userID))
        }
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRaceRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = BikeRaceRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = BikePathPointTool.computeRaceSamplePoints(pathData: self.pathData)
                    }
                }
            default: break
            }
        }
    }
}

class RunningRaceRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: RunningRaceRecordDetailInfo?
    
    @Published var basePath: [PathPoint] = []
    @Published var pathData: [RunningPathPoint] = []
    @Published var samplePath: [RunningSamplePathPoint] = []
    
    init(recordID: String) {
        self.recordID = recordID
        self.recordDetailInfo = nil
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/competition/running/query_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        if UserManager.shared.isLoggedIn {
            components.queryItems?.append(URLQueryItem(name: "user_id", value: UserManager.shared.user.userID))
        }
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRaceRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = RunningRaceRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = RunningPathPointTool.computeRaceSamplePoints(pathData: self.pathData)
                    }
                }
            default: break
            }
        }
    }
}

struct RaceSettlementsInfo {
    let xp: Int
    let ccassets: [CCUpdateResponse]
}

struct BikeRaceRecordDetailInfo {
    let status: CompetitionStatus
    let originalTime: Double            // 原始成绩
    let finalTime: Double               // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let isFinishComputed: Bool          // 有效成绩是否还在后台计算中
    let cardBonus: [CardBonusInfo]      // 我的卡牌奖励
    let extraCardBonus: [CardBonusInfo]      // 其他卡牌奖励
    let teamMemberScores: [MemberScoreInfo]     // 组队模式下的队友成绩
    let settlements: RaceSettlementsInfo            // 结算数据
    let familiarityTime: Double         // 熟悉度收益时间
    let trainingStateTime: Double       // 训练状态收益时间
    let totalCardTime: Double           // 总卡牌时间收益
    
    init(from detail: BikeRaceRecordDetailResponse) {
        self.status = detail.status
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.isFinishComputed = detail.is_finish_computed
        var myBonus: [CardBonusInfo] = []
        var otherBonus: [CardBonusInfo] = []
        for bonus in detail.card_bonus {
            if bonus.user_id == UserManager.shared.user.userID {
                myBonus.append(
                    CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
                )
            } else {
                otherBonus.append(
                    CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
                )
            }
        }
        self.cardBonus = myBonus
        self.extraCardBonus = otherBonus
        var scores: [MemberScoreInfo] = []
        for score in detail.team_member_scores {
            scores.append(MemberScoreInfo(from: score))
        }
        self.teamMemberScores = scores
        
        var temp_assets: [CCUpdateResponse] = []
        var xp: Int = 0
        if let settlements = detail.settlements {
            for type in CCAssetType.allCases {
                if let amount = settlements["\(type.rawValue)"]?.intValue {
                    temp_assets.append(CCUpdateResponse(ccasset_type: type, new_ccamount: amount))
                }
            }
            if let amount = settlements["xp"]?.intValue {
                xp = amount
            }
        }
        self.settlements = RaceSettlementsInfo(xp: xp, ccassets: temp_assets)
        self.familiarityTime = detail.familiarity_time
        self.trainingStateTime = detail.training_state_time
        var cardTime: Double = 0
        for card_bonus in detail.card_bonus {
            cardTime += card_bonus.bonus_time
        }
        self.totalCardTime = cardTime
    }
}

struct RunningRaceRecordDetailInfo {
    let status: CompetitionStatus
    let originalTime: Double            // 原始成绩
    let finalTime: Double               // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let isFinishComputed: Bool          // 有效成绩是否还在后台计算中
    let cardBonus: [CardBonusInfo]      // 我的卡牌奖励
    let extraCardBonus: [CardBonusInfo]      // 其他卡牌奖励
    let teamMemberScores: [MemberScoreInfo]     // 组队模式下的队友成绩
    let settlements: RaceSettlementsInfo            // 结算数据
    let familiarityTime: Double         // 熟悉度收益时间
    let trainingStateTime: Double       // 训练状态收益时间
    let totalCardTime: Double
    
    init(from detail: RunningRaceRecordDetailResponse) {
        self.status = detail.status
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.isFinishComputed = detail.is_finish_computed
        var myBonus: [CardBonusInfo] = []
        var otherBonus: [CardBonusInfo] = []
        for bonus in detail.card_bonus {
            if bonus.user_id == UserManager.shared.user.userID {
                myBonus.append(
                    CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
                )
            } else {
                otherBonus.append(
                    CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
                )
            }
        }
        self.cardBonus = myBonus
        self.extraCardBonus = otherBonus
        var scores: [MemberScoreInfo] = []
        for score in detail.team_member_scores {
            scores.append(MemberScoreInfo(from: score))
        }
        self.teamMemberScores = scores
        
        var temp_assets: [CCUpdateResponse] = []
        var xp: Int = 0
        if let settlements = detail.settlements {
            for type in CCAssetType.allCases {
                if let amount = settlements["\(type.rawValue)"]?.intValue {
                    temp_assets.append(CCUpdateResponse(ccasset_type: type, new_ccamount: amount))
                }
            }
            if let amount = settlements["xp"]?.intValue {
                xp = amount
            }
        }
        self.settlements = RaceSettlementsInfo(xp: xp, ccassets: temp_assets)
        self.familiarityTime = detail.familiarity_time
        self.trainingStateTime = detail.training_state_time
        var cardTime: Double = 0
        for card_bonus in detail.card_bonus {
            cardTime += card_bonus.bonus_time
        }
        self.totalCardTime = cardTime
    }
}

struct CardBonusInfo: Identifiable {
    var id: String { card.cardID }
    let card: MagicCard
    let bonusTime: Double
}

struct MemberScoreInfo: Identifiable {
    var id: String { userInfo.userID }
    let userInfo: PersonInfoCard
    let status: CompetitionStatus
    let finalTime: Double?
    
    init(from detail: MemberScoreDTO) {
        self.userInfo = PersonInfoCard(from: detail.user_info)
        self.status = detail.status
        self.finalTime = detail.final_time
    }
}

struct CardBonusDTO: Codable {
    let card: MagicCardUserDTO
    let bonus_time: Double
    let user_id: String
}

struct MemberScoreDTO: Codable {
    let user_info: PersonInfoDTO
    let status: CompetitionStatus
    let final_time: Double?
}

struct BikeRaceRecordDetailResponse: Codable {
    let status: CompetitionStatus
    let original_time: Double           // 原始成绩
    let final_time: Double              // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let is_finish_computed: Bool        // 是否已完成有效成绩计算
    let path: [BikePathPoint]           // 比赛路径记录
    let card_bonus: [CardBonusDTO]      // 所有卡牌的奖励时间
    let team_member_scores: [MemberScoreDTO]    // 队友成绩
    let settlements: JSONValue?         // 比赛结算
    let familiarity_time: Double        // 熟悉度收益时间
    let training_state_time: Double     // 训练状态收益时间
}

struct RunningRaceRecordDetailResponse: Codable {
    let status: CompetitionStatus
    let original_time: Double           // 原始成绩
    let final_time: Double              // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let is_finish_computed: Bool        // 是否已完成有效成绩计算
    let path: [RunningPathPoint]        // 比赛路径记录
    let card_bonus: [CardBonusDTO]      // 所有卡牌的奖励时间
    let team_member_scores: [MemberScoreDTO]    // 队友成绩
    let settlements: JSONValue?         // 比赛结算
    let familiarity_time: Double        // 熟悉度收益时间
    let training_state_time: Double     // 训练状态收益时间
}

struct BikeSamplePathPoint {
    var speed_avg: Double
    let altitude_avg: Double
    let heart_rate_min: Double?
    let heart_rate_max: Double?
    let power_avg: Double?
    let pedal_cadence_avg: Double?
    let pedal_count_avg: Double
    let timestamp_min: TimeInterval
    let timestamp_max: TimeInterval
}

struct RunningSamplePathPoint {
    var speed_avg: Double
    let altitude_avg: Double
    let heart_rate_min: Double?
    let heart_rate_max: Double?
    let power_avg: Double?
    let step_cadence_avg: Double?
    let vertical_amplitude_avg: Double?
    let touchdown_time_avg: Double?
    let step_size_avg: Double?
    let estimate_step_count_avg: Double
    let timestamp_min: TimeInterval
    let timestamp_max: TimeInterval
}
