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
    
    // 用来做全局的按钮防抖
    @Published var isButtonLocked = false
    
    // 设备当前定位
    var location: String? = nil
    //var ipCountryCode: String = "未知"
    
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
    var refreshRankInfo: Bool = false
    
    // 用户页刷新时机
    var refreshUserView: Bool = false
    var refreshMailStatus: Bool = false
    
    // 首页刷新时机
    var refreshHomeView: Bool = false
    
    func refreshAll() {
        refreshShopView = true
        refreshStoreHouseView = true
        refreshCompetitionView = true
        refreshRecordManageView = true
        refreshTeamManageView = true
        refreshUserView = true
        refreshHomeView = true
    }
}
