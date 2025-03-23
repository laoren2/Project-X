//
//  CompetitionManagementViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import Foundation
import SwiftUI
import Combine

class CompetitionManagementViewModel: ObservableObject {
    @Published var selectedTab: Int = 0  // 0: 未完成, 1: 已完成
    
    private let currencyManager = CurrencyManager.shared
    private let competitionManager = CompetitionManager.shared

    // 比赛记录
    @Published var competitionRecords: [CompetitionRecord] = []
    
    // 未完成的比赛
    @Published var incompleteCompetitions: [CompetitionRecord] = []
    
    // 已完成的比赛
    @Published var completedCompetitions: [CompetitionRecord] = []
    

    
    func fetchCompetitionRecords() {
        competitionRecords = competitionManager.competitionRecords
        incompleteCompetitions = competitionRecords.filter{ $0.status == .incomplete }.sorted(by: { $0.initDate > $1.initDate })
        completedCompetitions = competitionRecords.filter { $0.status == .completed }.sorted(by: { $0.startDate ?? $0.initDate > $1.startDate ?? $1.initDate })
    }
    
    // 取消比赛报名
    func cancelCompetition(id: UUID) {
        if let index = incompleteCompetitions.firstIndex(where: { $0.id == id }) {
            let fee = incompleteCompetitions[index].fee
            incompleteCompetitions.remove(at: index)  // 删除记录
            competitionManager.deleteCompetitionRecord(id: id, status: .incomplete) // 模拟服务端删除操作
            currencyManager.reward(currency: "coinB", amount: fee)
        }
        
        //incompleteCompetitions.removeAll { $0.id == id }
    }
    
    func feedback(record: CompetitionRecord) {
        print("对id: \(record.id) 提出疑问")
    }
}
