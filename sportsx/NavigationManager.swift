//
//  NavigationManager.swift
//  sportsx
//
//  Created by 任杰 on 2025/1/9.
//

import Foundation
import SwiftUI

class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var path = NavigationPath()
    
    private init() {}
    
    // 直接导航到目标页面
    func NavigationTo(des: String) {
        let cnt = findIndex(des: des) - 1
        if cnt >= 0 {
            path.removeLast(cnt)
        } else {
            print("Navigation failed")
        }
    }
    
    // 计算path中目标页面是倒数第几个
    func findIndex(des: String) -> Int {
        do {
            // 编码 NavigationPath 为 JSON 数据
            let data = try JSONEncoder().encode(path.codable)
            
            // 将 JSON 数据解码为数组
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as! [String]
            
            // 查找 "B" 的索引
            if let index = jsonObject.firstIndex(of: "\"\(des)\"") {
                return (index + 1) / 2 // 返回与 "B" 相关的 "Swift.String" 的索引
            } else {
                return -1
            }
        } catch {
            print("Error handling NavigationPath: \(error)")
            return -1
        }
    }
}
