//
//  RecordDetailViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/11.
//

import Foundation

class BikeRecordDetailViewModel: ObservableObject {
    let recordID: String
    let userID: String
    @Published var recordDetailInfo: BikeRecordDetailInfo?
    
    init(recordID: String, userID: String) {
        self.recordID = recordID
        self.userID = userID
        self.recordDetailInfo = nil
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/competition/bike/query_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID),
            URLQueryItem(name: "user_id", value: userID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = BikeRecordDetailInfo(from: unwrappedData)
                    }
                }
            default: break
            }
        }
    }
}

class RunningRecordDetailViewModel: ObservableObject {
    let recordID: String
    let userID: String
    @Published var recordDetailInfo: RunningRecordDetailInfo?
    
    init(recordID: String, userID: String) {
        self.recordID = recordID
        self.userID = userID
        self.recordDetailInfo = nil
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/competition/running/query_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID),
            URLQueryItem(name: "user_id", value: userID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = RunningRecordDetailInfo(from: unwrappedData)
                    }
                }
            default: break
            }
        }
    }
}

struct BikeRecordDetailInfo {
    let originalTime: Double        // 原始成绩
    let finalTime: Double           // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let isFinishComputed: Bool      // 有效成绩是否还在后台计算中
    let path: [PathPoint]           // 比赛路径记录
    let cardBonus: [CardBonusInfo]  // 所有卡牌的奖励时间
    let teamMemberScores: [MemberScoreInfo]     // 组队模式下的队友成绩
    
    init(from detail: BikeRecordDetailResponse) {
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.isFinishComputed = true
        self.path = detail.path
        var cardBonus: [CardBonusInfo] = []
        for bonus in detail.card_bonus {
            cardBonus.append(
                CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
            )
        }
        self.cardBonus = cardBonus
        var scores: [MemberScoreInfo] = []
        for score in detail.team_member_scores {
            scores.append(MemberScoreInfo(from: score))
        }
        self.teamMemberScores = scores
    }
}

struct RunningRecordDetailInfo {
    let originalTime: Double        // 原始成绩
    let finalTime: Double           // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let isFinishComputed: Bool      // 有效成绩是否还在后台计算中
    let path: [PathPoint]           // 比赛路径记录
    let cardBonus: [CardBonusInfo]  // 所有卡牌的奖励时间
    let teamMemberScores: [MemberScoreInfo]     // 组队模式下的队友成绩
    
    init(from detail: RunningRecordDetailResponse) {
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.isFinishComputed = true
        self.path = detail.path
        var cardBonus: [CardBonusInfo] = []
        for bonus in detail.card_bonus {
            cardBonus.append(
                CardBonusInfo(card: MagicCard(from: bonus.card), bonusTime: bonus.bonus_time)
            )
        }
        self.cardBonus = cardBonus
        var scores: [MemberScoreInfo] = []
        for score in detail.team_member_scores {
            scores.append(MemberScoreInfo(from: score))
        }
        self.teamMemberScores = scores
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
}

struct MemberScoreDTO: Codable {
    let user_info: PersonInfoDTO
    let status: CompetitionStatus
    let final_time: Double?
}

struct BikeRecordDetailResponse: Codable {
    let original_time: Double           // 原始成绩
    let final_time: Double              // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let path: [PathPoint]               // 比赛路径记录
    let card_bonus: [CardBonusDTO]      // 所有卡牌的奖励时间
    let team_member_scores: [MemberScoreDTO]
}

struct RunningRecordDetailResponse: Codable {
    let original_time: Double           // 原始成绩
    let final_time: Double              // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let path: [PathPoint]               // 比赛路径记录
    let card_bonus: [CardBonusDTO]      // 所有卡牌的奖励时间
    let team_member_scores: [MemberScoreDTO]
}
