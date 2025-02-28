//
//  NavigationManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//

import Foundation

class NavigationManager: ObservableObject {
    
    @Published var navigateToCompetition: Bool = false // 导航至比赛详情页
    @Published var navigateToSensorBindView: Bool = false // 导航至设备绑定详情页
    
}
