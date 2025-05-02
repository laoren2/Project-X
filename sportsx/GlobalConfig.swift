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
    
    // 示例
    var location: String = "未知"
}
