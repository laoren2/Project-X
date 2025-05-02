//
//  NavigationManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//
//
import Foundation
import SwiftUI


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
    case friendListView(selectedTab: Int)
    case userIntroEditView
    case realNameAuthView
    case identityAuthView
    
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
    
    // 可供 NavigationStack 绑定
    var binding: Binding<[AppRoute]> {
        Binding(
            get: { self.path },
            set: { [weak self] newValue in
                self?.lock.lock()
                self?.path = newValue
                self?.lock.unlock()
            }
        )
    }
    
    private init() {}
    
    func append(_ route: AppRoute) {
        lock.lock()
        path.append(route)
        lock.unlock()
    }

    func removeLast(_ count: Int = 1) {
        guard count >= 0 else { return }
        
        lock.lock()
        if path.count >= count {
            path.removeLast(count)
        }
        lock.unlock()
    }
    
    // 直接导航到path内目标页面（有重复页面则导航到第一个出现的页面）
    func NavigationTo(des: String) {
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
    
    
}
