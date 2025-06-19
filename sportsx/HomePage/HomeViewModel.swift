//
//  HomeViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/20.
//

import Foundation
import Combine
import CoreLocation
import MapKit
import SwiftUI


class HomeViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var isTodaySigned: Bool = false
    @Published var signedInDays: [Bool] = Array(repeating: false, count: 7)
    
    let appState = AppState.shared
    let userManager = UserManager.shared

    var ads: [Ad] = [
        Ad(imageURL: "/resources/placeholder/season.png"),
        Ad(imageURL: "https://example.com/ad3.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg"),
        Ad(imageURL: "https://s2.loli.net/2024/12/31/ZqR3uWdXTtUELsB.jpg")
    ]
    
    var business: [Ad] = [
        Ad(imageURL: "/resources/placeholder/season.png"),
        Ad(imageURL: "/resources/placeholder/season.png"),
        Ad(imageURL: "https://example.com/ad3.jpg")
    ]
    
    // 功能组件数据
    let features = [
        FeatureComponent(iconName: "star.fill", title: "技巧", destination: .skillView),
        FeatureComponent(iconName: "star.fill", title: "活动", destination: .activityView)
        //FeatureComponent(iconName: "star.fill", title: "钱包2", destination: "navigateToWallet"),
        //FeatureComponent(iconName: "star.fill", title: "钱包3", destination: "navigateToWallet")
        //Feature(iconName: "star.fill", title: "功能5", destination: "navigateToWallet")
    ]

    override init() {
        super.init()
    }
    
    deinit {
        //deleteLocationSubscription()
    }
    
    func isSignedIn(day: Int) -> Bool {
        return signedInDays[day]
    }
        
    func signInToday() {
        let today = Calendar.current.component(.weekday, from: Date()) - 1
        signedInDays[today] = true
        isTodaySigned = true
    }
    
    func fetchSignInStatus() {
        // todo
        isTodaySigned = isSignedIn(day: Calendar.current.component(.weekday, from: Date()) - 1)
    }
}

struct LeaderboardEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let user_id: String
    let nickname: String
    let best_time: TimeInterval
    let avatarImageURL: String
    let predictBonus: Int
    
    init(id: UUID = UUID(), user_id: String = "null", nickname: String = "null", best_time: TimeInterval = 0.0, avatarImageURL: String, predictBonus: Int = 0) {
        self.id = id
        self.user_id = user_id
        self.nickname = nickname
        self.best_time = best_time
        self.avatarImageURL = avatarImageURL
        self.predictBonus = predictBonus
    }
    
    static func == (lhs: LeaderboardEntry, rhs: LeaderboardEntry) -> Bool {
        return lhs.user_id == rhs.user_id
    }
}

struct Ad: Identifiable {
    let id = UUID()
    let imageURL: String
}

struct FeatureComponent: Identifiable {
    let id = UUID()
    let iconName: String
    let title: String
    let destination: AppRoute
}




