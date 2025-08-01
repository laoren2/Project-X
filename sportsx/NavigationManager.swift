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
    case competitionResultView
    case competitionCardSelectView
    case competitionRealtimeView
    case sensorBindView
    case skillView
    case activityView
    case recordManagementView
    case teamManagementView
    case userSetUpView
    case instituteView
    case userView(id: String, needBack: Bool)
    case friendListView(id: String, selectedTab: Int)
    case userIntroEditView
    case realNameAuthView
    case identityAuthView
    case userSetUpAccountView
    case adminPanelView
    case seasonBackendView
    case runningEventBackendView
    case runningTrackBackendView
    case bikeEventBackendView
    case bikeTrackBackendView
    case regionSelectedView
    
    var string: String {
        switch self {
        case .competitionResultView: 
            return "competitionResultView"
        case .competitionCardSelectView: 
            return "competitionCardSelectView"
        case .competitionRealtimeView:
            return "competitionRealtimeView"
        case .sensorBindView:
            return "sensorBindView"
        case .skillView:
            return "skillView"
        case .activityView:
            return "activityView"
        case .recordManagementView:
            return "recordManagementView"
        case .teamManagementView:
            return "teamManagementView"
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
        case .adminPanelView:
            return "adminPanelView"
        case .seasonBackendView:
            return "seasonBackendView"
        case .runningEventBackendView:
            return "runningEventBackendView"
        case .runningTrackBackendView:
            return "runningTrackBackendView"
        case .bikeEventBackendView:
            return "bikeEventBackendView"
        case .bikeTrackBackendView:
            return "bikeTrackBackendView"
        case .regionSelectedView:
            return "regionSelectedView"
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
