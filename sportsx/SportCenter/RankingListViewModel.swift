//
//  RankingListViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/13.
//

import Foundation


class BikeRankingListViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var rankingListEntries: [BikeRankingListEntry] = []
    @Published var gender: Gender = .male
    @Published var selfRankInfo: BikeUserRankCard?
    
    let trackID: String
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 20
    var timeStamp: String?
    
    var lastRefreshTimeStamp: Date?
    
    
    init(trackID: String) {
        self.trackID = trackID
    }
    
    func refresh(enforce: Bool = false) {
        if !enforce {
            // 时间截流
            if let lastRefreshTimeStamp = lastRefreshTimeStamp, Date().timeIntervalSince(lastRefreshTimeStamp) < 3 {
                return
            }
        }
        lastRefreshTimeStamp = Date()
        
        queryRankInfo()
        queryRankingList(reset: true)
    }
    
    func queryRankInfo() {
        guard var components = URLComponents(string: "/competition/bike/query_me_rank") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeUserRankInfoDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.selfRankInfo = BikeUserRankCard(from: unwrappedData)
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.selfRankInfo = nil
                }
            }
        }
    }
    
    func queryRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
            timeStamp = nil
        }
        queryRankingList()
    }
    
    func queryRankingList() {
        guard var components = URLComponents(string: "/competition/bike/query_leaderboads") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID),
            URLQueryItem(name: "gender", value: gender.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        if let time = timeStamp {
            components.queryItems?.append(URLQueryItem(name: "time_stamp", value: time))
        }
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRankingListResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for entry in unwrappedData.entries {
                            self.rankingListEntries.append(BikeRankingListEntry(from: entry))
                        }
                        self.timeStamp = unwrappedData.time_stamp
                        if unwrappedData.entries.count < self.pageSize {
                            self.hasMore = false
                        } else {
                            self.hasMore = true
                            self.page += 1
                        }
                    }
                }
            default: break
            }
        }
    }
}


struct BikeRankingListResponse: Codable {
    let entries: [BikeRankingListInfo]
    let time_stamp: String?
}

//struct RunningRankingListResponse: Codable {
    
//}

struct BikeRankingListInfo: Codable {
    let record_id: String
    let user_info: PersonInfoDTO
    let duration_seconds: Double
}

struct BikeRankingListEntry: Identifiable, Equatable {
    var id: String { userID }
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let score: Double
    let recordID: String
    
    init(
        userID: String,
        nickname: String,
        avatarImageURL: String,
        score: Double,
        recordID: String
    ) {
        self.userID = userID
        self.nickname = nickname
        self.avatarImageURL = avatarImageURL
        self.score = score
        self.recordID = recordID
    }
    
    init(from bikeEntry: BikeRankingListInfo) {
        self.userID = bikeEntry.user_info.user_id
        self.nickname = bikeEntry.user_info.nickname
        self.avatarImageURL = bikeEntry.user_info.avatar_image_url
        self.score = bikeEntry.duration_seconds
        self.recordID = bikeEntry.record_id
    }
    
    /*init(from runningEntry: RunningRankingListInfo) {
        self.user_id = bikeEntry.user_info.user_id
        self.nickname = bikeEntry.user_info.nickname
        self.avatarImageURL = bikeEntry.user_info.avatar_image_url
        self.score = bikeEntry.duration_seconds
    }*/
    
    static func == (lhs: BikeRankingListEntry, rhs: BikeRankingListEntry) -> Bool {
        return lhs.userID == rhs.userID
    }
}



class RunningRankingListViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var rankingListEntries: [RunningRankingListEntry] = []
    @Published var gender: Gender = .male
    @Published var selfRankInfo: RunningUserRankCard?

    let trackID: String
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 20
    var timeStamp: String?
    
    var lastRefreshTimeStamp: Date?
    
    
    init(trackID: String) {
        self.trackID = trackID
    }
    
    func refresh(enforce: Bool = false) {
        if !enforce {
            // 时间截流
            if let lastRefreshTimeStamp = lastRefreshTimeStamp, Date().timeIntervalSince(lastRefreshTimeStamp) < 3 {
                return
            }
        }
        lastRefreshTimeStamp = Date()
        
        queryRankInfo()
        queryRankingList(reset: true)
    }
    
    func queryRankInfo() {
        guard var components = URLComponents(string: "/competition/running/query_me_rank") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningUserRankInfoDTO.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.selfRankInfo = RunningUserRankCard(from: unwrappedData)
                    }
                }
            case .failure:
                DispatchQueue.main.async {
                    self.selfRankInfo = nil
                }
            }
        }
    }
    
    func queryRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
            timeStamp = nil
        }
        queryRankingList()
    }
    
    func queryRankingList() {
        guard var components = URLComponents(string: "/competition/running/query_leaderboads") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID),
            URLQueryItem(name: "gender", value: gender.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        if let time = timeStamp {
            components.queryItems?.append(URLQueryItem(name: "time_stamp", value: time))
        }
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRankingListResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for entry in unwrappedData.entries {
                            self.rankingListEntries.append(RunningRankingListEntry(from: entry))
                        }
                        self.timeStamp = unwrappedData.time_stamp
                        if unwrappedData.entries.count < self.pageSize {
                            self.hasMore = false
                        } else {
                            self.hasMore = true
                            self.page += 1
                        }
                    }
                }
            default: break
            }
        }
    }
}


struct RunningRankingListResponse: Codable {
    let entries: [RunningRankingListInfo]
    let time_stamp: String?
}

//struct RunningRankingListResponse: Codable {
    
//}

struct RunningRankingListInfo: Codable {
    let record_id: String
    let user_info: PersonInfoDTO
    let duration_seconds: Double
}

struct RunningRankingListEntry: Identifiable, Equatable {
    var id: String { userID }
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let score: Double
    let recordID: String
    
    init(
        userID: String,
        nickname: String,
        avatarImageURL: String,
        score: Double,
        recordID: String
    ) {
        self.userID = userID
        self.nickname = nickname
        self.avatarImageURL = avatarImageURL
        self.score = score
        self.recordID = recordID
    }
    
    init(from runningEntry: RunningRankingListInfo) {
        self.userID = runningEntry.user_info.user_id
        self.nickname = runningEntry.user_info.nickname
        self.avatarImageURL = runningEntry.user_info.avatar_image_url
        self.score = runningEntry.duration_seconds
        self.recordID = runningEntry.record_id
    }
    
    static func == (lhs: RunningRankingListEntry, rhs: RunningRankingListEntry) -> Bool {
        return lhs.userID == rhs.userID
    }
}
