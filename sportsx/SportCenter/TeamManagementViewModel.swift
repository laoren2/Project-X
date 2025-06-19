//
//  TeamManagementViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/24.
//

import Foundation
import CoreLocation
import SwiftUI

// 队伍成员结构(服务端最好添加一个标记用来标记member是否完成了比赛，避免从大量record中查询)
struct TeamMember: Identifiable {
    let id = UUID()
    let userID: String? // server userid
    let name: String // 用户昵称
    let avatar: String // 头像
    let isLeader: Bool
    let joinTime: Date
    var isRegistered: Bool
}

struct TeamMemberDTO: Codable {
    var userID: String?       // 用户ID
    var joinTime: Date        // 加入时间
    var isRegistered: Bool    // 是否已报名
}

struct TeamDTO: Codable {
    var teamID: String?             // 队伍ID（服务端生成）
    var captainID: String           // 队长userID
    var title: String               // 团队名称
    var description: String         // 团队描述
    var maxMembers: Int             // 团队最大人数
    var members: [TeamMemberDTO]    // 成员列表
    var teamCode: String?           // 队伍码（服务端生成）
    var eventID: String             // 比赛id
    var trackID: String             // 赛道id
    var createdAt: Date?            // 创建时间(服务端记录)
    var updatedAt: Date?            // 更新时间(服务端记录)
    var competitionDate: Date       // 比赛时间
    var pendingRequests: [TeamMemberDTO]   // 等待批准的用户ID
    var isPublic: Bool              // 是否公开
    var realCompetitionDate: Date?  // 实际的比赛开始时间（队伍中第一个成员开始比赛的时间，服务端写入）
    var isLocked: Bool              // 是否锁定（锁定后无法被申请和加入）
    var status: TeamStatus          // 队伍的当前状态
}



// 队伍结构
struct Team: Identifiable {
    let id: UUID
    let teamID: String? // server teamid
    let captainID: String // 队长用户id
    let captainName: String // 队长昵称
    let captainAvatar: String // 队长头像
    var title: String
    var description: String
    var maxMembers: Int
    var members: [TeamMember]
    let teamCode: String // 队伍码
    let eventName: String
    let trackName: String
    //let trackID: Int
    //let eventID: Int
    let creationDate: Date?
    let competitionDate: Date
    var pendingRequests: [TeamMember] // 申请加入的用户
    var isPublic: Bool
    var realCompetitionDate: Date?
    var isLocked: Bool
    var status: TeamStatus
    // 队伍的当前状态（仅用于控制客户端视图中的开关）
    var statusIsPrepared: Bool {
        return status == .prepared
    }
    
    // 当前成员数
    var currentMemberCount: Int {
        return members.count
    }
    
    // 是否已满
    var isFull: Int {
        return members.count >= maxMembers ? 1 : 0
    }
    
    // 针对用户的type
    func getRelationship(for userId: String) -> TeamRelationship {
        if userId == captainID {
            return .created
        } else if members.contains(where: { $0.userID == userId }) {
            return .joined
        } else if pendingRequests.contains(where: { $0.userID == userId }) {
            return .applied
        } else {
            return .unrelated
        }
    }
    
    init(
        id: UUID = UUID(),
        teamID: String? = nil,
        captainID: String,
        captainName: String,
        captainAvatar: String,
        title: String,
        description: String,
        maxMembers: Int,
        members: [TeamMember],
        teamCode: String,
        eventName: String,
        trackName: String,
        //trackID: Int,
        //eventID: Int,
        creationDate: Date? = nil,
        competitionDate: Date,
        pendingRequests: [TeamMember],
        isPublic: Bool = false,
        realCompetitionDate: Date? = nil,
        isLocked: Bool = false,
        status: TeamStatus = .prepared
    ) {
        self.id = id
        self.teamID = teamID
        self.captainID = captainID
        self.captainName = captainName
        self.captainAvatar = captainAvatar
        self.title = title
        self.description = description
        self.maxMembers = maxMembers
        self.members = members
        self.teamCode = teamCode
        self.eventName = eventName
        self.trackName = trackName
        //self.trackID = trackID
        //self.eventID = eventID
        self.creationDate = creationDate
        self.competitionDate = competitionDate
        self.pendingRequests = pendingRequests
        self.isPublic = isPublic
        self.realCompetitionDate = realCompetitionDate
        self.isLocked = isLocked
        self.status = status
    }
}

enum TeamRelationship {
    case created    // 我创建的
    case joined     // 我加入的
    case applied    // 我申请的
    case unrelated  // 与我无关的
}

enum TeamStatus: Codable {
    case prepared   // 准备状态，无法开始比赛
    case ready      // 就绪状态，可以开始比赛
    case recording  // 进行状态，比赛进行中
}

class TeamManagementViewModel: ObservableObject {
    let user = UserManager.shared
    
    // 所有队伍列表
    @Published var myCreatedTeams: [Team] = []
    @Published var myJoinedTeams: [Team] = []
    @Published var myAppliedTeams: [Team] = []
    
    let competitionManager = CompetitionManager.shared
    
    // 选中的队伍（用于详情展示）
    
    @Published var selectedTeamDetail: Team?
    @Published var selectedTeamManage: Team?
    
    // 提示信息
    @Published var showAlert = false
    @Published var showCardAlert = false    // 控制teamManageCard弹出的alert
    var alertMessage = ""
    
    // 当前选择的Tab
    @Published var selectedTab = 0
    
    // 从SportCenterViewModel获取我的队伍信息
    func fetchTeamInfo() {
        // 实际情况下，这里应该从服务器获取数据
        // 模拟网络请求获取数据
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.myCreatedTeams = self.competitionManager.myCreatedTeams
            self.myJoinedTeams = self.competitionManager.myJoinedTeams
            self.myAppliedTeams = self.competitionManager.myAppliedTeams
        }
    }
    
    
    
    // 处理队员申请
    func handleMemberRequest(memberId: UUID, isApproved: Bool) {
        // 这里应该向服务器发起请求
        // 模拟处理申请
        if let team = selectedTeamManage {
            guard let index = myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            guard let createIndex = competitionManager.myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            
            var teamCopy = team
            
            if let requestIndex = teamCopy.pendingRequests.firstIndex(where: { $0.id == memberId }) {
                if isApproved {
                    // 如果批准，将用户从申请列表移动到成员列表
                    let member = teamCopy.pendingRequests[requestIndex]
                    teamCopy.members.append(member)
                    teamCopy.pendingRequests.remove(at: requestIndex)
                    selectedTeamManage?.members.append(member)
                    selectedTeamManage?.pendingRequests.remove(at: requestIndex)
                } else {
                    // 如果拒绝，从申请列表移除
                    teamCopy.pendingRequests.remove(at: requestIndex)
                    selectedTeamManage?.pendingRequests.remove(at: requestIndex)
                }
            }
            
            // 更新队伍信息
            myCreatedTeams[index] = teamCopy
            competitionManager.myCreatedTeams[createIndex] = teamCopy
            
            if team.isPublic {
                guard let availableIndex = competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) else { return }
                competitionManager.availableTeams[availableIndex] = teamCopy
            }
        }
    }
    
    // 移除队员
    func removeMember(memberId: UUID) {
        // 这里应该向服务器发起请求
        // 模拟移除队员
        if let team = selectedTeamManage {
            guard let index = myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            guard let createIndex = competitionManager.myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            
            
            var teamCopy = team
            
            // 从队伍中移除成员
            if let memberIndex = teamCopy.members.firstIndex(where: { $0.id == memberId }) {
                teamCopy.members.remove(at: memberIndex)
                selectedTeamManage?.members.remove(at: memberIndex)
            }
            
            // 更新队伍信息
            myCreatedTeams[index] = teamCopy
            competitionManager.myCreatedTeams[createIndex] = teamCopy
            
            if team.isPublic {
                guard let availableIndex = competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) else { return }
                competitionManager.availableTeams[availableIndex] = teamCopy
            }
        }
    }
    
    func updateTeamPublicStatus(isPublic: Bool) {
        if let team = selectedTeamManage {
            guard let index = myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            guard let createIndex = competitionManager.myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            
            myCreatedTeams[index].isPublic = isPublic
            competitionManager.myCreatedTeams[createIndex].isPublic = isPublic
            
            if !isPublic {
                guard let index = competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) else { return }
                competitionManager.availableTeams.remove(at: index)
            } else {
                if competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) == nil {
                    competitionManager.availableTeams.append(team)
                }
            }
        }
        selectedTeamManage?.isPublic = isPublic
    }
    
    func updateTeamLockStatus(isLocked: Bool) {
        if let team = selectedTeamManage {
            guard let index = myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            guard let createIndex = competitionManager.myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            
            myCreatedTeams[index].isLocked = isLocked
            competitionManager.myCreatedTeams[createIndex].isLocked = isLocked
            if let availableIndex = competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) {
                competitionManager.availableTeams[availableIndex].isLocked = isLocked
            }
        }
        selectedTeamManage?.isLocked = isLocked
    }
    
    func updateTeamStatus() {
        if let team = selectedTeamManage {
            if !team.isLocked {
                alertMessage = "请锁定队伍"
                showAlert = true
                return
            }
            if !team.pendingRequests.isEmpty {
                alertMessage = "请处理剩余的申请信息"
                showAlert = true
                return
            }
            if team.members.contains(where: { $0.isRegistered == false }) {
                alertMessage = "请保证所有队员均报名成功"
                showAlert = true
                return
            }
            // 检查设置的比赛时间是否有效（需要迟于当前时间）
            if team.competitionDate < Date() {
                alertMessage = "比赛时间不可早于当前时间，请调整队伍的比赛时间"
                showAlert = true
                return
            }
            
            guard let index = myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            guard let createIndex = competitionManager.myCreatedTeams.firstIndex(where: { $0.id == team.id }) else { return }
            
            myCreatedTeams[index].status = .ready
            competitionManager.myCreatedTeams[createIndex].status = .ready
            if let availableIndex = competitionManager.availableTeams.firstIndex(where: { $0.id == team.id }) {
                competitionManager.availableTeams[availableIndex].status = .ready
            }
        }
        selectedTeamManage?.status = .ready
        print("statusIsPrepared: \(String(describing: selectedTeamManage?.statusIsPrepared)) status: \(String(describing: selectedTeamManage?.status))")
    }
}
