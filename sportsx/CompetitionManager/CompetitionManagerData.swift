//
//  CompetitionManagerData.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/31.
//

import Foundation

class CompetitionManagerData {
    static let shared = CompetitionManagerData() // 单例模式
        
    var isRecording: Bool = false
    
    private init() {}
}
