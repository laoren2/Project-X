//
//  RecordDetailViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/11.
//

import Foundation

class BikeRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: BikeRecordDetailInfo?
    
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
        
        NetworkService.sendRequest(with: request, decodingType: BikeRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = BikeRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = self.computeSamplePoints()
                    }
                }
            default: break
            }
        }
    }
    
    func computeSamplePoints() -> [BikeSamplePathPoint] {
        guard !pathData.isEmpty else { return [] }
        if pathData.count <= 80 {
            // 当点数不超过80时，直接将每个点转换为区间相同的TestSamplePathPoint
            return pathData.map { p in
                BikeSamplePathPoint(
                    speed_avg: p.base.speed > 0 ? 3.6 * p.base.speed : 0,
                    altitude_avg: p.base.altitude,
                    heart_rate_min: p.base.heart_rate,
                    heart_rate_max: p.base.heart_rate,
                    power_avg: p.power,
                    pedal_cadence_avg: p.pedal_cadence,
                    timestamp_min: p.base.timestamp,
                    timestamp_max: p.base.timestamp
                )
            }
        }
        // 当点数超过80时，按时间段采样，将数据划分为80段
        let minTime = pathData.first!.base.timestamp
        let maxTime = pathData.last!.base.timestamp
        let interval = (maxTime - minTime) / 80.0
        var segments: [[BikePathPoint]] = Array(repeating: [], count: 80)
        
        for point in pathData {
            let index = min(Int((point.base.timestamp - minTime) / interval), 79)
            segments[index].append(point)
        }
        
        return segments.map { segment in
            if segment.isEmpty {
                return BikeSamplePathPoint(
                    speed_avg: 0,
                    altitude_avg: 0,
                    heart_rate_min: nil,
                    heart_rate_max: nil,
                    power_avg: nil,
                    pedal_cadence_avg: nil,
                    timestamp_min: 0,
                    timestamp_max: 0
                )
            } else {
                // 1. 计算路径总长度（单位：米）
                var totalDistance: Double = 0
                for i in 0..<(segment.count - 1) {
                    let p1 = segment[i]
                    let p2 = segment[i + 1]
                    totalDistance += GeographyTool.haversineDistance(
                        lat1: p1.base.lat, lon1: p1.base.lon,
                        lat2: p2.base.lat, lon2: p2.base.lon
                    )
                }
                
                // 2. 计算时间差
                let duration = max(segment.last!.base.timestamp - segment.first!.base.timestamp, 0.0001)
                
                // 3. 平均速度（km/h）
                let avgSpeed = (totalDistance / duration) * 3.6
                
                // 4. 海拔、心率和时间戳
                let altitudes = segment.map { $0.base.altitude }
                let heartRates = segment.compactMap { $0.base.heart_rate }
                let timestamps = segment.map { $0.base.timestamp }
                
                // 5. 功率和踏频
                let powers = segment.compactMap { $0.power }
                let pedalCadences = segment.compactMap { $0.pedal_cadence }
                
                return BikeSamplePathPoint(
                    speed_avg: avgSpeed,
                    altitude_avg: altitudes.reduce(0, +) / Double(altitudes.count),
                    heart_rate_min: heartRates.min(),
                    heart_rate_max: heartRates.max(),
                    power_avg: powers.reduce(0, +) / Double(powers.count),
                    pedal_cadence_avg: pedalCadences.reduce(0, +) / Double(pedalCadences.count),
                    timestamp_min: timestamps.min() ?? 0,
                    timestamp_max: timestamps.max() ?? 0
                )
            }
        }
    }
}

class RunningRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: RunningRecordDetailInfo?
    
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
    let status: CompetitionStatus
    let originalTime: Double            // 原始成绩
    let finalTime: Double               // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let isFinishComputed: Bool          // 有效成绩是否还在后台计算中
    let cardBonus: [CardBonusInfo]      // 所有卡牌的奖励时间
    let teamMemberScores: [MemberScoreInfo]     // 组队模式下的队友成绩
    
    init(from detail: BikeRecordDetailResponse) {
        self.status = detail.status
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.isFinishComputed = true
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
    let status: CompetitionStatus
    let originalTime: Double            // 原始成绩
    let finalTime: Double               // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let isFinishComputed: Bool          // 有效成绩是否还在后台计算中
    let basePath: [PathPoint]
    let path: [RunningPathPoint]        // 比赛路径记录
    let cardBonus: [CardBonusInfo]      // 所有卡牌的奖励时间
    let teamMemberScores: [MemberScoreInfo]     // 组队模式下的队友成绩
    
    init(from detail: RunningRecordDetailResponse) {
        self.status = detail.status
        self.originalTime = detail.original_time
        self.finalTime = detail.final_time
        self.isFinishComputed = true
        self.path = detail.path
        self.basePath = detail.path.map { $0.base }
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
    let status: CompetitionStatus
    let original_time: Double           // 原始成绩
    let final_time: Double              // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let path: [BikePathPoint]               // 比赛路径记录
    let card_bonus: [CardBonusDTO]      // 所有卡牌的奖励时间
    let team_member_scores: [MemberScoreDTO]
}

struct RunningRecordDetailResponse: Codable {
    let status: CompetitionStatus
    let original_time: Double           // 原始成绩
    let final_time: Double              // 有效成绩 （ = 原始成绩 - 所有卡牌的奖励时间 ）
    let path: [RunningPathPoint]               // 比赛路径记录
    let card_bonus: [CardBonusDTO]      // 所有卡牌的奖励时间
    let team_member_scores: [MemberScoreDTO]
}

struct BikeSamplePathPoint {
    let speed_avg: Double
    let altitude_avg: Double
    let heart_rate_min: Double?
    let heart_rate_max: Double?
    let power_avg: Double?
    let pedal_cadence_avg: Double?
    let timestamp_min: TimeInterval
    let timestamp_max: TimeInterval
}

struct RunningSamplePathPoint {
    let speed_avg: Double
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
