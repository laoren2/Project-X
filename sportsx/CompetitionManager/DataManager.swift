//
//  DataManager.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import Foundation
import Combine


class DataManager: ObservableObject {
    @Published var dataWindow: [CompetitionData] = []
    private var dataLock = NSLock()
    
    func addData(_ data: CompetitionData) {
        dataLock.lock()
        dataWindow.append(data)
        // 清理过时的数据，保留最近60秒或指定条数的数据
        // 这里根据条数管理
        if dataWindow.count > 1200 { // 假设最多保留1200条数据（60秒 / 0.05秒 = 1200条）
            dataWindow.removeFirst(dataWindow.count - 1200)
        }
        dataLock.unlock()
    }
    
    func getLastSamples(count: Int) -> [CompetitionData] {
        dataLock.lock()
        let total = dataWindow.count
        let startIndex = max(total - count, 0)
        let recentData = Array(dataWindow[startIndex..<total])
        dataLock.unlock()
        return recentData
    }
}


