//
//  FriendListViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/4/22.
//

import Foundation

struct PersonInfoCard: Identifiable, Equatable {
    let id = UUID()
    let userID: String      // server userid
    let avatarUrl: String   // 头像
    let name: String        // 用户昵称
    
    init(userID: String, avatarUrl: String, name: String) {
        self.userID = userID
        self.avatarUrl = avatarUrl
        self.name = name
    }
    
    init(from person: PersonInfoDTO) {
        self.userID = person.user_id
        self.avatarUrl = person.avatar_image_url
        self.name = person.nickname
    }
    
    static func == (lhs: PersonInfoCard, rhs: PersonInfoCard) -> Bool {
        return lhs.userID == rhs.userID
    }
}

class FriendListViewModel: ObservableObject {
    // 朋友列表
    @Published var myFriends: [PersonInfoCard] = []
    // 关注列表
    @Published var myIdols: [PersonInfoCard] = []
    // 粉丝列表
    @Published var myFans: [PersonInfoCard] = []
    
    // 过滤后的朋友列表
    @Published var myFilteredFriends: [PersonInfoCard] = []
    // 过滤后的关注列表
    @Published var myFilteredIdols: [PersonInfoCard] = []
    // 过滤后的粉丝列表
    @Published var myFilteredFans: [PersonInfoCard] = []
    
    var user_id: String
    
    @Published var isIdolsLoading = false
    var idolsCursorDatetime: String? = nil
    var idolsCursorID: String? = nil
    var hasMoreIdols: Bool = false
    
    @Published var isFansLoading = false
    var fansCursorDatetime: String? = nil
    var fansCursorID: String? = nil
    var hasMoreFans: Bool = false
    
    @Published var isFriendsLoading = false
    var friendsCursorDatetime: String? = nil
    var friendsCursorID: String? = nil
    var hasMoreFriends: Bool = false
    
    @Published var isSearchIdolsLoading = false
    var searchIdolsCursorDatetime: String? = nil
    var searchIdolsCursorID: String? = nil
    var hasMoreSearchIdols: Bool = false
    
    @Published var isSearchFansLoading = false
    var searchFansCursorDatetime: String? = nil
    var searchFansCursorID: String? = nil
    var hasMoreSearchFans: Bool = false
    
    @Published var isSearchFriendsLoading = false
    var searchFriendsCursorDatetime: String? = nil
    var searchFriendsCursorID: String? = nil
    var hasMoreSearchFriends: Bool = false
    
    
    init(id: String) {
        user_id = id
        
        fetchIdols()
        fetchFans()
        fetchFriends()
    }
    
    func fetchIdols(withNicname name: String? = nil) {
        guard var components = URLComponents(string: "/user/following_list") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: user_id),
            URLQueryItem(name: "limit", value: "11")
        ]
        if let nicName = name {
            isSearchIdolsLoading = true
            if let cursorDatetime = searchIdolsCursorDatetime {
                components.queryItems?.append(URLQueryItem(name: "cursor_created_at", value: cursorDatetime))
            }
            if let cursorID = searchIdolsCursorID {
                components.queryItems?.append(URLQueryItem(name: "cursor_id", value: cursorID))
            }
            components.queryItems?.append(URLQueryItem(name: "search", value: nicName))
            
        } else {
            isIdolsLoading = true
            if let cursorDatetime = idolsCursorDatetime {
                components.queryItems?.append(URLQueryItem(name: "cursor_created_at", value: cursorDatetime))
            }
            if let cursorID = idolsCursorID {
                components.queryItems?.append(URLQueryItem(name: "cursor_id", value: cursorID))
            }
        }
        guard let urlPath = components.url?.absoluteString else { return }
        
        // "+" -> "%2B" 需手动编码
        let safeUrlPath = urlPath.replacingOccurrences(of: "+", with: "%2B")
        
        let request = APIRequest(path: safeUrlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: FollowingResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        if name != nil {
                            self.isSearchIdolsLoading = false
                            self.hasMoreSearchIdols = unwrappedData.has_more
                            self.searchIdolsCursorDatetime = unwrappedData.next_cursor_created_at
                            self.searchIdolsCursorID = unwrappedData.next_cursor_id
                            for user in unwrappedData.users {
                                self.myFilteredIdols.append(PersonInfoCard(userID: user.user_id, avatarUrl: user.avatar_image_url, name: user.nickname))
                            }
                        } else {
                            self.isIdolsLoading = false
                            self.hasMoreIdols = unwrappedData.has_more
                            self.idolsCursorDatetime = unwrappedData.next_cursor_created_at
                            self.idolsCursorID = unwrappedData.next_cursor_id
                            for user in unwrappedData.users {
                                self.myIdols.append(PersonInfoCard(userID: user.user_id, avatarUrl: user.avatar_image_url, name: user.nickname))
                            }
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    func fetchFans(withNicname name: String? = nil) {
        guard var components = URLComponents(string: "/user/follower_list") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: user_id),
            URLQueryItem(name: "limit", value: "10")
        ]
        if let nicName = name {
            isSearchFansLoading = true
            if let cursorDatetime = searchFansCursorDatetime {
                components.queryItems?.append(URLQueryItem(name: "cursor_created_at", value: cursorDatetime))
            }
            if let cursorID = searchFansCursorID {
                components.queryItems?.append(URLQueryItem(name: "cursor_id", value: cursorID))
            }
            components.queryItems?.append(URLQueryItem(name: "search", value: nicName))
            
        } else {
            isFansLoading = true
            if let cursorDatetime = fansCursorDatetime {
                components.queryItems?.append(URLQueryItem(name: "cursor_created_at", value: cursorDatetime))
            }
            if let cursorID = fansCursorID {
                components.queryItems?.append(URLQueryItem(name: "cursor_id", value: cursorID))
            }
        }
        guard let urlPath = components.url?.absoluteString else { return }
        
        // "+" -> "%2B" 需手动编码
        let safeUrlPath = urlPath.replacingOccurrences(of: "+", with: "%2B")
        
        let request = APIRequest(path: safeUrlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: FollowingResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        if name != nil {
                            self.isSearchFansLoading = false
                            self.hasMoreSearchFans = unwrappedData.has_more
                            self.searchFansCursorDatetime = unwrappedData.next_cursor_created_at
                            self.searchFansCursorID = unwrappedData.next_cursor_id
                            for user in unwrappedData.users {
                                self.myFilteredFans.append(PersonInfoCard(userID: user.user_id, avatarUrl: user.avatar_image_url, name: user.nickname))
                            }
                        } else {
                            self.isFansLoading = false
                            self.hasMoreFans = unwrappedData.has_more
                            self.fansCursorDatetime = unwrappedData.next_cursor_created_at
                            self.fansCursorID = unwrappedData.next_cursor_id
                            for user in unwrappedData.users {
                                self.myFans.append(PersonInfoCard(userID: user.user_id, avatarUrl: user.avatar_image_url, name: user.nickname))
                            }
                        }
                    }
                }
            default:
                break
            }
        }
    }
    
    func fetchFriends(withNicname name: String? = nil) {
        guard var components = URLComponents(string: "/user/friend_list") else { return }
        components.queryItems = [
            URLQueryItem(name: "user_id", value: user_id),
            URLQueryItem(name: "limit", value: "11")
        ]
        if let nicName = name {
            isSearchFriendsLoading = true
            if let cursorDatetime = searchFriendsCursorDatetime {
                components.queryItems?.append(URLQueryItem(name: "cursor_created_at", value: cursorDatetime))
            }
            if let cursorID = searchFriendsCursorID {
                components.queryItems?.append(URLQueryItem(name: "cursor_id", value: cursorID))
            }
            components.queryItems?.append(URLQueryItem(name: "search", value: nicName))
            
        } else {
            isFriendsLoading = true
            if let cursorDatetime = friendsCursorDatetime {
                components.queryItems?.append(URLQueryItem(name: "cursor_created_at", value: cursorDatetime))
            }
            if let cursorID = friendsCursorID {
                components.queryItems?.append(URLQueryItem(name: "cursor_id", value: cursorID))
            }
        }
        guard let urlPath = components.url?.absoluteString else { return }
        
        // "+" -> "%2B" 需手动编码
        let safeUrlPath = urlPath.replacingOccurrences(of: "+", with: "%2B")
        
        let request = APIRequest(path: safeUrlPath, method: .get, requiresAuth: false)
        
        NetworkService.sendRequest(with: request, decodingType: FollowingResponse.self, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        if name != nil {
                            self.isSearchFriendsLoading = false
                            self.hasMoreSearchFriends = unwrappedData.has_more
                            self.searchFriendsCursorDatetime = unwrappedData.next_cursor_created_at
                            self.searchFriendsCursorID = unwrappedData.next_cursor_id
                            for user in unwrappedData.users {
                                self.myFilteredFriends.append(PersonInfoCard(userID: user.user_id, avatarUrl: user.avatar_image_url, name: user.nickname))
                            }
                        } else {
                            self.isFriendsLoading = false
                            self.hasMoreFriends = unwrappedData.has_more
                            self.friendsCursorDatetime = unwrappedData.next_cursor_created_at
                            self.friendsCursorID = unwrappedData.next_cursor_id
                            for user in unwrappedData.users {
                                self.myFriends.append(PersonInfoCard(userID: user.user_id, avatarUrl: user.avatar_image_url, name: user.nickname))
                            }
                        }
                    }
                }
            default:
                break
            }
        }
    }
}

struct PersonInfoDTO: Codable {
    let user_id: String
    let avatar_image_url: String
    let nickname: String
}

struct FollowingResponse: Codable {
    let users: [PersonInfoDTO]
    let next_cursor_created_at: String?
    let next_cursor_id: String?
    let has_more: Bool
}
