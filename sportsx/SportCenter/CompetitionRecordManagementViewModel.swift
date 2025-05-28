//
//  CompetitionRecordManagementViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/9/7.
//

import Foundation
import SwiftUI
import Combine

class CompetitionRecordManagementViewModel: ObservableObject {
    @Published var selectedTab: Int = 0  // 0: 未完成, 1: 已完成
    
    // 提示信息
    @Published var showAlert = false
    @Published var alertMessage = ""
    
    private let currencyManager = CurrencyManager.shared
    private let competitionManager = CompetitionManager.shared
    private let navigationManager = NavigationManager.shared

    // 比赛记录
    @Published var competitionRecords: [CompetitionRecord] = []
    
    // 未完成的比赛
    @Published var incompleteCompetitions: [CompetitionRecord] = []
    
    // 已完成的比赛
    @Published var completedCompetitions: [CompetitionRecord] = []
    
    let user = UserManager.shared
    

    
    func fetchCompetitionRecords() {
        competitionRecords = competitionManager.competitionRecords
        incompleteCompetitions = competitionRecords.filter{ $0.status == .incomplete }.sorted(
            by: { $0.initDate > $1.initDate }
        )
        completedCompetitions = competitionRecords.filter{ $0.status == .completed }.sorted(
            by: { $0.startDate ?? $0.initDate > $1.startDate ?? $1.initDate }
        )
    }
    
    // 开始比赛
    func startCompetition(record: CompetitionRecord) {
        // 组队模式下不能开始比赛的情况
        if record.isTeamCompetition {
            let joinedTeams = competitionManager.myJoinedTeams + competitionManager.myCreatedTeams
            if let index = joinedTeams.firstIndex(where: { $0.teamCode == record.teamCode }) {
                // 队伍未进入比赛状态
                if joinedTeams[index].status == .prepared {
                    alertMessage = "队伍当前不处于比赛状态，无法开始比赛"
                    showAlert = true
                    return
                }
                // 队伍已开始比赛，用户超过有效时间
                if let timestamp = competitionManager.getTeamTimestampInSeconds(teamCode: record.teamCode ?? "未知"), timestamp > competitionManager.teamJoinTimeWindow {
                    alertMessage = "您已超出可加入的有效时间，无法开始比赛"
                    showAlert = true
                    return
                }
            }
        }
        // 防止重复开始同一比赛
        if let isRepeat = record.startDate {
            alertMessage = "您已参加过此比赛，无法重复参加"
            showAlert = true
            return
        }
        // 进入比赛链路
        competitionManager.resetCompetitionRecord(record: record)
        navigationManager.append(.competitionCardSelectView)
    }
    
    // 取消比赛报名
    func cancelCompetition(record: CompetitionRecord) {
        // 组队模式下检查team的状态
        if record.isTeamCompetition {
            let allJoinedTeams = competitionManager.myCreatedTeams + competitionManager.myJoinedTeams
            if let index = allJoinedTeams.firstIndex(where: {$0.teamCode == record.teamCode}), !allJoinedTeams[index].statusIsPrepared {
                alertMessage = "队伍处于比赛状态，无法取消报名"
                showAlert = true
                return
            }
        }
        
        if let index = incompleteCompetitions.firstIndex(where: { $0.id == record.id }) {
            incompleteCompetitions.remove(at: index)  // 删除记录
        }
        
        competitionManager.deleteCompetitionRecord(id: record.id, status: .incomplete) // 模拟服务端删除操作
        currencyManager.reward(currency: "coinB", amount: record.fee)
        
        // 在该队伍中调整用户的报名状态
        if let indexCreated = competitionManager.myCreatedTeams.firstIndex(where: {$0.teamCode == record.teamCode}) {
            if let userIndex = competitionManager.myCreatedTeams[indexCreated].members.firstIndex(where: {$0.userID == user.user.userID}) {
                competitionManager.myCreatedTeams[indexCreated].members[userIndex].isRegistered = false
            }
        }
        if let indexJoined = competitionManager.myJoinedTeams.firstIndex(where: {$0.teamCode == record.teamCode}) {
            if let userIndex = competitionManager.myJoinedTeams[indexJoined].members.firstIndex(where: {$0.userID == user.user.userID}) {
                competitionManager.myJoinedTeams[indexJoined].members[userIndex].isRegistered = false
            }
        }
    }
    
    func feedback(record: CompetitionRecord) {
        print("对id: \(record.id) 提出疑问")
    }
}
