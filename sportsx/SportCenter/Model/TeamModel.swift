//
//  TeamModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/5.
//

import Foundation


enum TeamRelationship {
    case created    // 我创建的
    case joined     // 我加入的
    case applied    // 我申请的
}

enum TeamStatus: String, Codable {
    case prepared   // 准备状态，可正常管理队伍
    case locked     // 锁定状态，队伍报名完毕且信息不可更改
    case ready      // 就绪状态，可以开始比赛
    case recording  // 进行状态，比赛进行中
    case completed  // 已结束
}

struct TeamCreatedResponse: Codable {
    let team_code: String
    let asset_id: String
    let new_balance: Int
}
