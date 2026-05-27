//
//  RankingListViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/13.
//

import Foundation


class BikeScoreRankingViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var rankingListEntries: [BikeScoreRankEntry] = []
    @Published var gender: Gender = .male
    let seasonName: String
    let seasonID: String
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 20
    
    init(seasonName: String, seasonID: String, gender: Gender) {
        self.seasonName = seasonName
        self.seasonID = seasonID
        self.gender = gender
    }
    
    func queryScoreRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
        }
        guard var components = URLComponents(string: "/competition/bike/query_score_leaderboard") else { return }
        components.queryItems = [
            URLQueryItem(name: "season_id", value: seasonID),
            URLQueryItem(name: "gender", value: gender.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: BikeScoreRankResponse.self, showLoadingToast: reset, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempEntries: [BikeScoreRankEntry] = []
                        for entry in unwrappedData.entries {
                            tempEntries.append(BikeScoreRankEntry(from: entry))
                        }
                        if reset {
                            self.rankingListEntries = tempEntries
                        } else {
                            for entry in tempEntries {
                                let index = entry.rank - 1
                                if index >= 0 && index < self.rankingListEntries.count {
                                    self.rankingListEntries[index] = entry
                                } else {
                                    self.rankingListEntries.append(entry)
                                }
                            }
                        }
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

class BikeRankingListViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var rankingListEntries: [BikeRankingListEntry] = []
    @Published var gender: Gender = .male
    @Published var recordID: String?
    @Published var rank: Int?
    @Published var duration: Double?
    @Published var voucherAmount: Int?
    @Published var score: Int?
    
    let trackID: String
    let isHistory: Bool
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 20
    var timeStamp: String?
    
    var lastRefreshTimeStamp: Date?
    
    
    init(trackID: String, gender: Gender, isHistory: Bool) {
        self.trackID = trackID
        self.gender = gender
        self.isHistory = isHistory
    }
    
    func refresh(enforce: Bool = false) {
        if !enforce {
            // 时间截流
            if let lastRefreshTimeStamp = lastRefreshTimeStamp, Date().timeIntervalSince(lastRefreshTimeStamp) < 3 {
                return
            }
        }
        lastRefreshTimeStamp = Date()
        if isHistory {
            queryHistoryRankingList(reset: true)
        } else {
            queryRankInfo()
            queryRankingList(reset: true)
            GlobalConfig.shared.refreshRankInfo = true
        }
    }
    
    func queryRankInfo() {
        guard UserManager.shared.isLoggedIn else { return }
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
                        self.rank = unwrappedData.rank
                        self.recordID = unwrappedData.record_id
                        self.duration = unwrappedData.duration_seconds
                        self.voucherAmount = unwrappedData.reward_voucher_amount
                        self.score = unwrappedData.score
                    }
                }
            default: break
            }
        }
    }
    
    func queryRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
            timeStamp = nil
        }
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
        
        NetworkService.sendRequest(with: request, decodingType: BikeRankingListResponse.self, showLoadingToast: reset, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempEntries: [BikeRankingListEntry] = []
                        for entry in unwrappedData.entries {
                            tempEntries.append(BikeRankingListEntry(from: entry))
                        }
                        if reset {
                            self.rankingListEntries = tempEntries
                        } else {
                            for entry in tempEntries {
                                let index = entry.rank - 1
                                if index >= 0 && index < self.rankingListEntries.count {
                                    self.rankingListEntries[index] = entry
                                } else {
                                    self.rankingListEntries.append(entry)
                                }
                            }
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
    
    func queryHistoryRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
        }
        guard var components = URLComponents(string: "/competition/bike/query_leaderboads_history") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID),
            URLQueryItem(name: "gender", value: gender.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRankingListResponse.self, showLoadingToast: reset, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempEntries: [BikeRankingListEntry] = []
                        for entry in unwrappedData.entries {
                            tempEntries.append(BikeRankingListEntry(from: entry))
                        }
                        if reset {
                            self.rankingListEntries = tempEntries
                        } else {
                            for entry in tempEntries {
                                let index = entry.rank - 1
                                if index >= 0 && index < self.rankingListEntries.count {
                                    self.rankingListEntries[index] = entry
                                } else {
                                    self.rankingListEntries.append(entry)
                                }
                            }
                        }
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

class BikeRouteRankListViewModel: ObservableObject {
    let userManager = UserManager.shared
    @Published var isLoading: Bool = false
    @Published var entries: [BikeRouteRankEntry] = []
    @Published var gender: Gender?
    @Published var nextCursor: String? = nil
    
    @Published var rank: Int?
    @Published var score: Double?
    
    let routeID: String
    let isPremium: Bool
    
    init(routeID: String, isPremium: Bool) {
        self.routeID = routeID
        let genderFilter: Gender? = isPremium ? userManager.user.gender : nil
        self.gender = genderFilter
        self.isPremium = isPremium
    }
    
    func queryMeRankInfo() {
        guard userManager.isLoggedIn else { return }
        guard var components = URLComponents(string: "/training/bike/route_ranklist/me") else { return }
        components.queryItems = [
            URLQueryItem(name: "route_id", value: routeID)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRouteMeRankInfo?.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.rank = unwrappedData?.rank
                        self.score = unwrappedData?.duration_seconds
                    }
                }
            default: break
            }
        }
    }
    
    func queryRanklists(reset: Bool = true) {
        guard !isLoading else { return }
        
        if reset {
            entries = []
            nextCursor = nil
        }
        
        isLoading = true
        
        var query: [String: String] = [
            "route_id": routeID,
            "limit": "20"
        ]
        
        if let gender = gender {
            query["gender"] = gender.rawValue
        }
        
        if let cursor = nextCursor {
            query["cursor"] = cursor
        }
        
        var components = URLComponents(string: "/training/bike/route_ranklist")
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let urlPath = components?.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: BikeRouteRanklistResponse.self, showLoadingToast: reset ? true : false, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let data):
                    if let data {
                        var tempEntries: [BikeRouteRankEntry] = []
                        for route in data.ranklist {
                            tempEntries.append(BikeRouteRankEntry(from: route))
                        }
                        if reset {
                            self.entries = tempEntries
                        } else {
                            self.entries.append(contentsOf: tempEntries)
                        }
                        self.nextCursor = data.next_cursor
                    }
                default:
                    break
                }
            }
        }
    }
}

struct BikeRouteMeRankInfo: Codable {
    let rank: Int
    let duration_seconds: Double
}

struct BikeRouteRankInfo: Codable {
    let rank: Int
    let duration_seconds: Double
    let user: PersonInfoDTO
}

struct BikeRouteRanklistResponse: Codable {
    let ranklist: [BikeRouteRankInfo]
    let next_cursor: String?
}

struct BikeRouteRankEntry: Identifiable {
    var id: String { userID }
    let rank: Int
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let score: Double
    
    init(from dto: BikeRouteRankInfo) {
        self.rank = dto.rank
        self.userID = dto.user.user_id
        self.nickname = dto.user.nickname
        self.avatarImageURL = dto.user.avatar_image_url
        self.score = dto.duration_seconds
    }
}

struct BikeScoreRankResponse: Codable {
    let entries: [BikeScoreRankInfo]
}

struct BikeScoreRankInfo: Codable {
    let rank: Int
    let user_info: PersonInfoDTO
    let score: Int
}

struct BikeScoreRankEntry: Identifiable {
    var id: String { userID }
    let rank: Int
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let score: Int
    
    init(from bikeEntry: BikeScoreRankInfo) {
        self.rank = bikeEntry.rank
        self.userID = bikeEntry.user_info.user_id
        self.nickname = bikeEntry.user_info.nickname
        self.avatarImageURL = bikeEntry.user_info.avatar_image_url
        self.score = bikeEntry.score
    }
}

struct BikeRankingListResponse: Codable {
    let entries: [BikeRankingListInfo]
    let time_stamp: String?
}

struct BikeRankingListInfo: Codable {
    let rank: Int
    let record_id: String
    let user_info: PersonInfoDTO
    let duration_seconds: Double
    let voucher: Int
    let score: Int
}

struct BikeRankingListEntry: Identifiable {
    var id: String { userID }
    let rank: Int
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let duration: Double
    let voucher: Int
    let score: Int
    let recordID: String
    
    init(
        rank: Int,
        userID: String,
        nickname: String,
        avatarImageURL: String,
        duration: Double,
        voucher: Int,
        score: Int,
        recordID: String
    ) {
        self.rank = rank
        self.userID = userID
        self.nickname = nickname
        self.avatarImageURL = avatarImageURL
        self.duration = duration
        self.voucher = voucher
        self.score = score
        self.recordID = recordID
    }
    
    init(from bikeEntry: BikeRankingListInfo) {
        self.rank = bikeEntry.rank
        self.userID = bikeEntry.user_info.user_id
        self.nickname = bikeEntry.user_info.nickname
        self.avatarImageURL = bikeEntry.user_info.avatar_image_url
        self.duration = bikeEntry.duration_seconds
        self.voucher = bikeEntry.voucher
        self.score = bikeEntry.score
        self.recordID = bikeEntry.record_id
    }
}


class RunningScoreRankingViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var rankingListEntries: [RunningScoreRankEntry] = []
    @Published var gender: Gender = .male
    let seasonName: String
    let seasonID: String
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 20
    
    init(seasonName: String, seasonID: String, gender: Gender) {
        self.seasonName = seasonName
        self.seasonID = seasonID
        self.gender = gender
    }
    
    func queryScoreRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
        }
        guard var components = URLComponents(string: "/competition/running/query_score_leaderboard") else { return }
        components.queryItems = [
            URLQueryItem(name: "season_id", value: seasonID),
            URLQueryItem(name: "gender", value: gender.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RunningScoreRankResponse.self, showLoadingToast: reset, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempEntries: [RunningScoreRankEntry] = []
                        for entry in unwrappedData.entries {
                            tempEntries.append(RunningScoreRankEntry(from: entry))
                        }
                        if reset {
                            self.rankingListEntries = tempEntries
                        } else {
                            for entry in tempEntries {
                                let index = entry.rank - 1
                                if index >= 0 && index < self.rankingListEntries.count {
                                    self.rankingListEntries[index] = entry
                                } else {
                                    self.rankingListEntries.append(entry)
                                }
                            }
                        }
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

class RunningRankingListViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var rankingListEntries: [RunningRankingListEntry] = []
    @Published var gender: Gender = .male
    @Published var  recordID: String?
    @Published var  rank: Int?
    @Published var  duration: Double?
    @Published var  voucherAmount: Int?
    @Published var  score: Int?

    let trackID: String
    let isHistory: Bool
    
    var hasMore: Bool = true
    var page: Int = 1
    let pageSize: Int = 20
    var timeStamp: String?
    
    var lastRefreshTimeStamp: Date?
    
    init(trackID: String, gender: Gender, isHistory: Bool) {
        self.trackID = trackID
        self.gender = gender
        self.isHistory = isHistory
    }
    
    func refresh(enforce: Bool = false) {
        if !enforce {
            // 时间截流
            if let lastRefreshTimeStamp = lastRefreshTimeStamp, Date().timeIntervalSince(lastRefreshTimeStamp) < 3 {
                return
            }
        }
        lastRefreshTimeStamp = Date()
        
        if isHistory {
            queryHistoryRankingList(reset: true)
        } else {
            queryRankInfo()
            queryRankingList(reset: true)
            GlobalConfig.shared.refreshRankInfo = true
        }
    }
    
    func queryRankInfo() {
        guard UserManager.shared.isLoggedIn else { return }
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
                        self.rank = unwrappedData.rank
                        self.recordID = unwrappedData.record_id
                        self.duration = unwrappedData.duration_seconds
                        self.voucherAmount = unwrappedData.reward_voucher_amount
                        self.score = unwrappedData.score
                    }
                }
            default: break
            }
        }
    }
    
    func queryRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
            timeStamp = nil
        }
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
        
        NetworkService.sendRequest(with: request, decodingType: RunningRankingListResponse.self, showLoadingToast: reset, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempEntries: [RunningRankingListEntry] = []
                        for entry in unwrappedData.entries {
                            tempEntries.append(RunningRankingListEntry(from: entry))
                        }
                        if reset {
                            self.rankingListEntries = tempEntries
                        } else {
                            for entry in tempEntries {
                                let index = entry.rank - 1
                                if index >= 0 && index < self.rankingListEntries.count {
                                    self.rankingListEntries[index] = entry
                                } else {
                                    self.rankingListEntries.append(entry)
                                }
                            }
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
    
    func queryHistoryRankingList(reset: Bool) {
        if reset {
            rankingListEntries.removeAll()
            page = 1
        }
        guard var components = URLComponents(string: "/competition/running/query_leaderboads_history") else { return }
        components.queryItems = [
            URLQueryItem(name: "track_id", value: trackID),
            URLQueryItem(name: "gender", value: gender.rawValue),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRankingListResponse.self, showLoadingToast: reset, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        var tempEntries: [RunningRankingListEntry] = []
                        for entry in unwrappedData.entries {
                            tempEntries.append(RunningRankingListEntry(from: entry))
                        }
                        if reset {
                            self.rankingListEntries = tempEntries
                        } else {
                            for entry in tempEntries {
                                let index = entry.rank - 1
                                if index >= 0 && index < self.rankingListEntries.count {
                                    self.rankingListEntries[index] = entry
                                } else {
                                    self.rankingListEntries.append(entry)
                                }
                            }
                        }
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

class RunningRouteRankListViewModel: ObservableObject {
    let userManager = UserManager.shared
    @Published var isLoading: Bool = false
    @Published var entries: [RunningRouteRankEntry] = []
    @Published var gender: Gender?
    @Published var nextCursor: String? = nil
    
    @Published var rank: Int?
    @Published var score: Double?
    
    let routeID: String
    let isPremium: Bool
    
    init(routeID: String, isPremium: Bool) {
        self.routeID = routeID
        let genderFilter: Gender? = isPremium ? userManager.user.gender : nil
        self.gender = genderFilter
        self.isPremium = isPremium
    }
    
    func queryMeRankInfo() {
        guard userManager.isLoggedIn else { return }
        guard var components = URLComponents(string: "/training/running/route_ranklist/me") else { return }
        components.queryItems = [
            URLQueryItem(name: "route_id", value: routeID)
        ]
        guard let urlPath = components.string else { return }
            
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRouteMeRankInfo?.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.rank = unwrappedData?.rank
                        self.score = unwrappedData?.duration_seconds
                    }
                }
            default: break
            }
        }
    }
    
    func queryRanklists(reset: Bool = true) {
        guard !isLoading else { return }
        
        if reset {
            entries = []
            nextCursor = nil
        }
        
        isLoading = true
        
        var query: [String: String] = [
            "route_id": routeID,
            "limit": "20"
        ]
        
        if let gender = gender {
            query["gender"] = gender.rawValue
        }
        
        if let cursor = nextCursor {
            query["cursor"] = cursor
        }
        
        var components = URLComponents(string: "/training/running/route_ranklist")
        components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let urlPath = components?.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        NetworkService.sendRequest(with: request, decodingType: RunningRouteRanklistResponse.self, showLoadingToast: reset ? true : false, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let data):
                    if let data {
                        var tempEntries: [RunningRouteRankEntry] = []
                        for route in data.ranklist {
                            tempEntries.append(RunningRouteRankEntry(from: route))
                        }
                        if reset {
                            self.entries = tempEntries
                        } else {
                            self.entries.append(contentsOf: tempEntries)
                        }
                        self.nextCursor = data.next_cursor
                    }
                default:
                    break
                }
            }
        }
    }
}

struct RunningRouteMeRankInfo: Codable {
    let rank: Int
    let duration_seconds: Double
}

struct RunningRouteRankInfo: Codable {
    let rank: Int
    let duration_seconds: Double
    let user: PersonInfoDTO
}

struct RunningRouteRanklistResponse: Codable {
    let ranklist: [RunningRouteRankInfo]
    let next_cursor: String?
}

struct RunningRouteRankEntry: Identifiable {
    var id: String { userID }
    let rank: Int
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let score: Double
    
    init(from dto: RunningRouteRankInfo) {
        self.rank = dto.rank
        self.userID = dto.user.user_id
        self.nickname = dto.user.nickname
        self.avatarImageURL = dto.user.avatar_image_url
        self.score = dto.duration_seconds
    }
}

struct RunningScoreRankResponse: Codable {
    let entries: [RunningScoreRankInfo]
}

struct RunningScoreRankInfo: Codable {
    let rank: Int
    let user_info: PersonInfoDTO
    let score: Int
}

struct RunningScoreRankEntry: Identifiable {
    var id: String { userID }
    let rank: Int
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let score: Int
    
    init(from bikeEntry: RunningScoreRankInfo) {
        self.rank = bikeEntry.rank
        self.userID = bikeEntry.user_info.user_id
        self.nickname = bikeEntry.user_info.nickname
        self.avatarImageURL = bikeEntry.user_info.avatar_image_url
        self.score = bikeEntry.score
    }
}

struct RunningRankingListResponse: Codable {
    let entries: [RunningRankingListInfo]
    let time_stamp: String?
}

struct RunningRankingListInfo: Codable {
    let rank: Int
    let record_id: String
    let user_info: PersonInfoDTO
    let duration_seconds: Double
    let voucher: Int
    let score: Int
}

struct RunningRankingListEntry: Identifiable {
    var id: String { userID }
    let rank: Int
    let userID: String
    let nickname: String
    let avatarImageURL: String
    let duration: Double
    let voucher: Int
    let score: Int
    let recordID: String
    
    init(
        rank: Int,
        userID: String,
        nickname: String,
        avatarImageURL: String,
        duration: Double,
        voucher: Int,
        score: Int,
        recordID: String
    ) {
        self.rank = rank
        self.userID = userID
        self.nickname = nickname
        self.avatarImageURL = avatarImageURL
        self.duration = duration
        self.voucher = voucher
        self.score = score
        self.recordID = recordID
    }
    
    init(from bikeEntry: RunningRankingListInfo) {
        self.rank = bikeEntry.rank
        self.userID = bikeEntry.user_info.user_id
        self.nickname = bikeEntry.user_info.nickname
        self.avatarImageURL = bikeEntry.user_info.avatar_image_url
        self.duration = bikeEntry.duration_seconds
        self.voucher = bikeEntry.voucher
        self.score = bikeEntry.score
        self.recordID = bikeEntry.record_id
    }
}
