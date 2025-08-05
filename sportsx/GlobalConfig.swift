//
//  GlobalConfig.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/27.
//

import Foundation


class GlobalConfig: ObservableObject {
    static let shared = GlobalConfig()
    
    private init () {}
    
    var location: String = "未知"
    
    // record管理页刷新时机
    var refreshRecordManageView: Bool = false
    
    // team管理页面刷新时机
    var refreshTeamManageView: Bool = false
    
    // 商店页刷新时机
    var refreshShopView: Bool = false
    
    // 仓库页刷新时机
    var refreshStoreHouseView: Bool = false
    
    // 比赛页刷新时机
    var refreshCompetitionView: Bool = false
    
    func refreshAll() {
        refreshShopView = true
        refreshStoreHouseView = true
        refreshCompetitionView = true
        refreshRecordManageView = true
        refreshTeamManageView = true
    }
}
