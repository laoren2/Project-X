//
//  FreeTrainingDetailViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2026/3/16.
//

import Foundation

class BikeFreeTrainingRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: BikeFreeTrainingRecordDetailInfo?
    
    @Published var basePath: [PathPoint] = []
    @Published var pathData: [BikeFreeTrainingPathPoint] = []
    @Published var samplePath: [BikeFreeTrainingSamplePathPoint] = []
    
    
    init(recordID: String) {
        self.recordID = recordID
        self.recordDetailInfo = nil
        queryRecordDetail()
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/training/bike/query_free_training_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeFreeTrainingRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = BikeFreeTrainingRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = BikePathPointTool.computeFreeTrainingSamplePoints(pathData: self.pathData)
                    }
                }
            default: break
            }
        }
    }
}

struct TrainingSettlementsInfo {
    let xp: Int
    let state_value: Int
    let cc_rewards: [CCUpdateResponse]
}

struct BikeFreeTrainingRecordDetailInfo {
    let duration: Double            // 原始成绩
    let settlements: TrainingSettlementsInfo            // 结算数据
    let buffInfos: [BikeGridBuffSnapshot]
    
    init(from detail: BikeFreeTrainingRecordDetailResponse) {
        self.duration = detail.duration
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
        var tempBuffInfos: [BikeGridBuffSnapshot] = []
        for buffJson in detail.triggered_buffs {
            if let gridX = buffJson["grid_x"]?.intValue,
               let gridY = buffJson["grid_y"]?.intValue,
               let conditionString = buffJson["condition_type"]?.stringValue,
               let conditionType = BikeGridConditionType(rawValue: conditionString),
               let rewardString = buffJson["reward_type"]?.stringValue,
               let rewardType = CCAssetType(rawValue: rewardString) {
                let info = BikeGridBuffSnapshot(
                    gridX: gridX,
                    gridY: gridY,
                    conditionType: conditionType,
                    rewardType: rewardType
                )
                tempBuffInfos.append(info)
            }
        }
        self.buffInfos = tempBuffInfos
    }
}

struct BikeGridBuffSnapshot: Identifiable {
    let id = UUID()
    let gridX: Int
    let gridY: Int
    let conditionType: BikeGridConditionType
    let rewardType: CCAssetType
}

struct BikeFreeTrainingRecordDetailResponse: Codable {
    let duration: Double                    // 训练时间
    let path: [BikeFreeTrainingPathPoint]   // 训练路径记录
    let settlements: JSONValue              // 训练结算
    let triggered_buffs: [JSONValue]        // buff 快照
}

struct BikeFreeTrainingSamplePathPoint {
    var speed_avg: Double
    let altitude_avg: Double
    let heart_rate_min: Double?
    let heart_rate_max: Double?
    let power_avg: Double?
    let pedal_cadence_avg: Double?
    let timestamp_min: TimeInterval
    let timestamp_max: TimeInterval
}


class RunningFreeTrainingRecordDetailViewModel: ObservableObject {
    let recordID: String
    @Published var recordDetailInfo: RunningFreeTrainingRecordDetailInfo?
    
    @Published var basePath: [PathPoint] = []
    @Published var pathData: [RunningFreeTrainingPathPoint] = []
    @Published var samplePath: [RunningFreeTrainingSamplePathPoint] = []
    
    
    init(recordID: String) {
        self.recordID = recordID
        self.recordDetailInfo = nil
        queryRecordDetail()
    }
    
    func queryRecordDetail() {
        guard var components = URLComponents(string: "/training/running/query_free_training_record_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningFreeTrainingRecordDetailResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.recordDetailInfo = RunningFreeTrainingRecordDetailInfo(from: unwrappedData)
                        self.pathData = unwrappedData.path
                        self.basePath = unwrappedData.path.map { $0.base }
                        self.samplePath = RunningPathPointTool.computeFreeTrainingSamplePoints(pathData: self.pathData)
                    }
                }
            default: break
            }
        }
    }
}

struct RunningFreeTrainingRecordDetailInfo {
    let duration: Double            // 原始成绩
    let settlements: TrainingSettlementsInfo            // 结算数据
    let buffInfos: [RunningGridBuffSnapshot]
    
    init(from detail: RunningFreeTrainingRecordDetailResponse) {
        self.duration = detail.duration
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
        var tempBuffInfos: [RunningGridBuffSnapshot] = []
        for buffJson in detail.triggered_buffs {
            if let gridX = buffJson["grid_x"]?.intValue,
               let gridY = buffJson["grid_y"]?.intValue,
               let conditionString = buffJson["condition_type"]?.stringValue,
               let conditionType = RunningGridConditionType(rawValue: conditionString),
               let rewardString = buffJson["reward_type"]?.stringValue,
               let rewardType = CCAssetType(rawValue: rewardString) {
                let info = RunningGridBuffSnapshot(
                    gridX: gridX,
                    gridY: gridY,
                    conditionType: conditionType,
                    rewardType: rewardType
                )
                tempBuffInfos.append(info)
            }
        }
        self.buffInfos = tempBuffInfos
    }
}

struct RunningGridBuffSnapshot: Identifiable {
    let id = UUID()
    let gridX: Int
    let gridY: Int
    let conditionType: RunningGridConditionType
    let rewardType: CCAssetType
}

struct RunningFreeTrainingRecordDetailResponse: Codable {
    let duration: Double                        // 训练时间
    let path: [RunningFreeTrainingPathPoint]    // 训练路径记录
    let settlements: JSONValue                  // 训练结算
    let triggered_buffs: [JSONValue]            // buff 快照
}

struct RunningFreeTrainingSamplePathPoint {
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
