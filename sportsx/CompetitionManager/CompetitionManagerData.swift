//
//  CompetitionManagerData.swift
//  sportsx
//
//  集中管理比赛状态
//
//  Created by 任杰 on 2024/12/31.
//

import Foundation

class CompetitionManagerData: ObservableObject {
    static let shared = CompetitionManagerData() // 单例模式
        
    @Published var isRecording: Bool = false
    
    private init() {}
}
