//
//  NavigationManager.swift
//  sportsx
//
//  全局的path管理可能导致导航时SWiftUI重建导航视图，关键任务逻辑尽量不要使用onAppear和onDisappear，使用自定义Stable版本
//
//  Created by 任杰 on 2025/1/9.
//
//
import Foundation
import SwiftUI
import Combine


enum AppRoute: Hashable {
    case bikeRecordDetailView(recordID: String)
    case runningRecordDetailView(recordID: String)
    case competitionCardSelectView
    case competitionRealtimeView
    case sportTrainingView(sport: SportName)
    case sensorBindView
    case skillView
    case activityView
    case bikeRecordManagementView
    case bikeTeamManagementView
    case userSetUpView
    case instituteView
    case userView(id: String)
    case friendListView(id: String, selectedTab: Int)
    case userIntroEditView
    case realNameAuthView
    case identityAuthView
    case userSetUpAccountView
    case phoneBindView
    case appleBindView
    case bikeRankingListView(trackID: String, gender: Gender, isHistory: Bool = false)
    case bikeScoreRankingView(seasonName: String, seasonID: String, gender: Gender)
    case bikeTeamCreateView(trackID: String, competitionDate: Date)
    case bikeTeamJoinView(trackID: String)
    case bikeTeamManageView(teamID: String)
    case bikeTeamDetailView(teamID: String)
    case runningRecordManagementView
    case runningTeamManagementView
    case runningRankingListView(trackID: String, gender: Gender, isHistory: Bool = false)
    case runningScoreRankingView(seasonName: String, seasonID: String, gender: Gender)
    case runningTeamCreateView(trackID: String, competitionDate: Date)
    case runningTeamJoinView(trackID: String)
    case runningTeamManageView(teamID: String)
    case runningTeamDetailView(teamID: String)
    case mailBoxView
    case mailBoxDetailView(mailID: String)
    case subscriptionDetailView
    case iapHelpView
    case iapCouponView
#if DEBUG
    case adminPanelView
    case seasonBackendView
    case runningEventBackendView
    case runningTrackBackendView
    case runningRecordBackendView
    case bikeEventBackendView
    case bikeTrackBackendView
    case bikeRecordBackendView
    case regionSelectedView
    case cpAssetBackendView
    case cpAssetPriceBackendView
    case userAssetManageBackendView
    case magicCardBackendView
    case magicCardPriceBackendView
    case bikeMatchDebugView
#endif
    
    var string: String {
        switch self {
        case .bikeRecordDetailView:
            return "bikeRecordDetailView"
        case .runningRecordDetailView:
            return "runningRecordDetailView"
        case .competitionCardSelectView:
            return "competitionCardSelectView"
        case .competitionRealtimeView:
            return "competitionRealtimeView"
        case .sportTrainingView:
            return "sportTrainingView"
        case .sensorBindView:
            return "sensorBindView"
        case .skillView:
            return "skillView"
        case .activityView:
            return "activityView"
        case .bikeRecordManagementView:
            return "bikeRecordManagementView"
        case .bikeTeamManagementView:
            return "bikeTeamManagementView"
        case .userSetUpView:
            return "userSetUpView"
        case .instituteView:
            return "instituteView"
        case .userView:
            return "userView"
        case .friendListView:
            return "friendListView"
        case .userIntroEditView:
            return "userIntroEditView"
        case .realNameAuthView:
            return "realNameAuthView"
        case .identityAuthView:
            return "identityAuthView"
        case .userSetUpAccountView:
            return "userSetUpAccountView"
        case .phoneBindView:
            return "phoneBindView"
        case .appleBindView:
            return "appleBindView"
        case .bikeRankingListView:
            return "bikeRankingListView"
        case .bikeScoreRankingView:
            return "bikeScoreRankingView"
        case .bikeTeamCreateView:
            return "bikeTeamCreateView"
        case .bikeTeamJoinView:
            return "bikeTeamJoinView"
        case .bikeTeamManageView:
            return "bikeTeamManageView"
        case .bikeTeamDetailView:
            return "bikeTeamDetailView"
        case .runningRecordManagementView:
            return "runningRecordManagementView"
        case .runningTeamManagementView:
            return "runningTeamManagementView"
        case .runningRankingListView:
            return "runningRankingListView"
        case .runningScoreRankingView:
            return "runningScoreRankingView"
        case .runningTeamCreateView:
            return "runningTeamCreateView"
        case .runningTeamJoinView:
            return "runningTeamJoinView"
        case .runningTeamManageView:
            return "runningTeamManageView"
        case .runningTeamDetailView:
            return "runningTeamDetailView"
        case .mailBoxView:
            return "mailBoxView"
        case .mailBoxDetailView:
            return "mailBoxDetailView"
        case .subscriptionDetailView:
            return "subscriptionDetailView"
        case .iapHelpView:
            return "iapHelpView"
        case .iapCouponView:
            return "iapCouponView"
#if DEBUG
        case .adminPanelView:
            return "adminPanelView"
        case .seasonBackendView:
            return "seasonBackendView"
        case .runningEventBackendView:
            return "runningEventBackendView"
        case .runningTrackBackendView:
            return "runningTrackBackendView"
        case .runningRecordBackendView:
            return "runningRecordBackendView"
        case .bikeEventBackendView:
            return "bikeEventBackendView"
        case .bikeTrackBackendView:
            return "bikeTrackBackendView"
        case .bikeRecordBackendView:
            return "bikeRecordBackendView"
        case .regionSelectedView:
            return "regionSelectedView"
        case .cpAssetBackendView:
            return "cpAssetBackendView"
        case .cpAssetPriceBackendView:
            return "cpAssetPriceBackendView"
        case .userAssetManageBackendView:
            return "userAssetManageBackendView"
        case .magicCardBackendView:
            return "magicCardBackendView"
        case .magicCardPriceBackendView:
            return "magicCardPriceBackendView"
        case .bikeMatchDebugView:
            return "bikeMatchDebugView"
#endif
        }
    }
}

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    private let lock = NSLock()
    
    // 处理所有页面的导航
    @Published private(set) var path: [AppRoute] = []
    
    // 主页tab的导航
    @Published var selectedTab: Tab = .home
    
    // 运动选择侧边栏
    @Published var showSideBar: Bool = false
    
    // 组队底部sheet
    @Published var showTeamRegisterSheet: Bool = false
    
    // 运动中心状态
    @Published var isTrainingView: Bool = false
    
    // 可供 NavigationStack 绑定
    var binding: Binding<[AppRoute]> {
        Binding(
            get: {
                //print("path didget")
                return self.path
            },
            set: { [weak self] newValue in
                //print("path didset")
                self?.lock.lock()
                
                defer { self?.lock.unlock() }

                if self?.path != newValue {
                    self?.path = newValue
                }
            }
        )
    }
    
    func append(_ route: AppRoute) {
        //print("path append")
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        lock.lock()
        path.append(route)
        lock.unlock()
    }

    func removeLast(_ count: Int = 1) {
        //print("path removeLast")
        guard count >= 0 else { return }
        
        lock.lock()
        if path.count >= count {
            path.removeLast(count)
        }
        lock.unlock()
    }
    
    // 直接导航到path内目标页面（有重复页面则导航到第一个出现的页面）
    func NavigationTo(des: String) {
        //print("path navigationTo")
        if let index = path.firstIndex(where: { $0.string == des }) {
            let cnt = path.count - index - 1
            if cnt >= 0 {
                path.removeLast(cnt)
            } else {
                print("Navigation failed")
            }
        } else {
            print("Navigation des not found")
        }
    }
    
    func backToHome() {
        selectedTab = .home
        removeLast(path.count)
    }
}
