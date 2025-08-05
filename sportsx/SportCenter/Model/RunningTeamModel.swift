//
//  RunningTeamModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/5.
//

import Foundation

struct RunningTeamUpdateResponse: Codable {
    let title: String
    let description: String
    let competition_date: String
}

struct RunningTeamAppliedCardDTO: Codable {
    let team_id: String
    let leader_id: String
    let leader_name: String
    let leader_avatar_url: String
    let title: String
    let description: String
    let member_count: Int
    let max_member_size: Int
    let region_name: String
    let event_name: String
    let track_name: String
    let competition_date: String
}

struct RunningTeamAppliedResponse: Codable {
    let teams: [RunningTeamAppliedCardDTO]
}

struct RunningTeamAppliedCard: Identifiable, Equatable {
    var id: String { team_id }
    let team_id: String
    let leader_id: String
    let leader_name: String
    let leader_avatar_url: String
    let title: String
    let description: String
    let member_count: Int
    let max_member_size: Int
    let region_name: String
    let event_name: String
    let track_name: String
    let competition_date: Date?
    
    init(from team: RunningTeamAppliedCardDTO) {
        self.team_id = team.team_id
        self.leader_id = team.leader_id
        self.leader_name = team.leader_name
        self.leader_avatar_url = team.leader_avatar_url
        self.title = team.title
        self.description = team.description
        self.member_count = team.member_count
        self.max_member_size = team.max_member_size
        self.region_name = team.region_name
        self.event_name = team.event_name
        self.track_name = team.track_name
        self.competition_date = ISO8601DateFormatter().date(from: team.competition_date)
    }
    
    static func == (lhs: RunningTeamAppliedCard, rhs: RunningTeamAppliedCard) -> Bool {
        return lhs.team_id == rhs.team_id
    }
}

struct RunningTeamCardDTO: Codable {
    let team_id: String
    let leader_id: String
    let leader_name: String
    let leader_avatar_url: String
    let title: String
    let member_count: Int
    let max_member_size: Int
    let team_code: String
    let region_name: String
    let event_name: String
    let track_name: String
    let is_public: Bool
    let status: TeamStatus
    let competition_date: String
}

struct RunningTeamResponse: Codable {
    let teams: [RunningTeamCardDTO]
}

struct RunningTeamCard: Identifiable, Equatable {
    var id: String { team_id }
    let team_id: String
    let leader_id: String
    let leader_name: String
    let leader_avatar_url: String
    var title: String
    var member_count: Int
    let max_member_size: Int
    let team_code: String
    let region_name: String
    let event_name: String
    let track_name: String
    var is_public: Bool
    var status: TeamStatus
    var competition_date: Date?
    
    init(from team: RunningTeamCardDTO) {
        self.team_id = team.team_id
        self.leader_id = team.leader_id
        self.leader_name = team.leader_name
        self.leader_avatar_url = team.leader_avatar_url
        self.title = team.title
        self.member_count = team.member_count
        self.max_member_size = team.max_member_size
        self.team_code = team.team_code
        self.region_name = team.region_name
        self.event_name = team.event_name
        self.track_name = team.track_name
        self.is_public = team.is_public
        self.status = team.status
        self.competition_date = ISO8601DateFormatter().date(from: team.competition_date)
    }
    
    static func == (lhs: RunningTeamCard, rhs: RunningTeamCard) -> Bool {
        return lhs.team_id == rhs.team_id
    }
}

struct RunningTeamManageDTO: Codable {
    let team_id: String
    let title: String
    let description: String
    let max_member_size: Int
    let team_code: String
    let region_name: String
    let event_name: String
    let track_name: String
    let track_end_date: String
    let is_public: Bool
    let status: TeamStatus
    let created_at: String
    let competition_date: String
    let members: [RunningTeamMemberDTO]
    let request_members: [RunningTeamAppliedMemberDTO]
}

struct RunningTeamManageInfo: Identifiable {
    var id: String { team_id }
    let team_id: String
    var title: String
    var description: String
    let max_member_size: Int
    let team_code: String
    let region_name: String
    let event_name: String
    let track_name: String
    let track_end_date: Date?
    let is_public: Bool
    let is_locked: Bool
    let is_ready: Bool
    let created_at: Date?
    var competition_date: Date?
    
    init(from team: RunningTeamManageDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.team_id = team.team_id
        self.title = team.title
        self.description = team.description
        self.max_member_size = team.max_member_size
        self.team_code = team.team_code
        self.region_name = team.region_name
        self.event_name = team.event_name
        self.track_name = team.track_name
        self.track_end_date = ISO8601DateFormatter().date(from: team.track_end_date)
        self.is_public = team.is_public
        self.is_locked = team.status != .prepared
        self.is_ready = (team.status != .prepared && team.status != .locked)
        self.created_at = formatter.date(from: team.created_at)
        self.competition_date = ISO8601DateFormatter().date(from: team.competition_date)
    }
}

struct RunningTeamDetailDTO: Codable {
    let team_id: String
    let title: String
    let description: String
    let max_member_size: Int
    let team_code: String
    let region_name: String
    let event_name: String
    let track_name: String
    let is_public: Bool
    let status: TeamStatus
    let created_at: String
    let competition_date: String
    let members: [RunningTeamMemberDTO]
}

struct RunningTeamDetailInfo: Identifiable {
    var id: String { team_id }
    let team_id: String
    let title: String
    let description: String
    let max_member_size: Int
    let team_code: String
    let region_name: String
    let event_name: String
    let track_name: String
    let is_public: Bool
    let status: TeamStatus
    let created_at: Date?
    let competition_date: Date?
    let members: [RunningTeamMember]
    
    init(from team: RunningTeamDetailDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.team_id = team.team_id
        self.title = team.title
        self.description = team.description
        self.max_member_size = team.max_member_size
        self.team_code = team.team_code
        self.region_name = team.region_name
        self.event_name = team.event_name
        self.track_name = team.track_name
        self.is_public = team.is_public
        self.status = team.status
        self.created_at = formatter.date(from: team.created_at)
        self.competition_date = ISO8601DateFormatter().date(from: team.competition_date)
        var members: [RunningTeamMember] = []
        for member in team.members {
            members.append(RunningTeamMember(from: member))
        }
        self.members = members
    }
}

struct RunningTeamMemberUpdateResponse: Codable {
    let members: [RunningTeamMemberDTO]
}

struct RunningTeamMemberDTO: Codable {
    let member_id: String
    let user_id: String
    let nick_name: String
    let avatar_url: String
    let join_date: String
    let is_registered: Bool
    let is_leader: Bool
}

struct RunningTeamMember: Identifiable, Equatable {
    var id: String { member_id }
    let member_id: String
    let user_id: String
    let nick_name: String
    let avatar_url: String
    let join_date: Date?
    let is_registered: Bool
    let is_leader: Bool
    
    init(from team: RunningTeamMemberDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.member_id = team.member_id
        self.user_id = team.user_id
        self.nick_name = team.nick_name
        self.avatar_url = team.avatar_url
        self.join_date = formatter.date(from: team.join_date)
        self.is_registered = team.is_registered
        self.is_leader = team.is_leader
    }
    
    static func == (lhs: RunningTeamMember, rhs: RunningTeamMember) -> Bool {
        return lhs.member_id == rhs.member_id
    }
}

struct RunningTeamAppliedMemberDTO: Codable {
    let member_id: String
    let user_id: String
    let nick_name: String
    let avatar_url: String
    let introduction: String?
    let join_date: String
}

struct RunningTeamAppliedMember: Identifiable, Equatable {
    var id: String { member_id }
    let member_id: String
    let user_id: String
    let nick_name: String
    let avatar_url: String
    let introduction: String?
    let join_date: Date?
    
    init(from team: RunningTeamAppliedMemberDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.member_id = team.member_id
        self.user_id = team.user_id
        self.nick_name = team.nick_name
        self.avatar_url = team.avatar_url
        self.introduction = team.introduction
        self.join_date = formatter.date(from: team.join_date)
    }
    
    static func == (lhs: RunningTeamAppliedMember, rhs: RunningTeamAppliedMember) -> Bool {
        return lhs.member_id == rhs.member_id
    }
}
