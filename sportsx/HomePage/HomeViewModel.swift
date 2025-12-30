//
//  HomeViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/20.
//

import Foundation
import Combine
import CoreLocation
import MapKit
import SwiftUI


class HomeViewModel: ObservableObject {
    let assetManager = AssetManager.shared
    let userManager = UserManager.shared
    let reminderManager = SignInReminderManager.shared
    
    @Published var ads: [AdInfo] = []
    @Published var items: [SignInDay] = []
    //@Published var continuousDays: Int = 0
    @Published var announcements: [String] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingVip: Bool = false
    @AppStorage("signInReminderEnabled") var reminderEnabled: Bool = false
    @AppStorage("signInReminderTime") var reminderTimeString: String = "09:00"
    
    var hasMoreUsers: Bool = true
    var page: Int = 1
    let size: Int = 10
    @Published var isUserLoading: Bool = false

    var reminderTime: Date {
        get {
            // 将 "HH:mm" 转为 Date
            let parts = reminderTimeString.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = parts[0]
                comps.minute = parts[1]
                comps.second = 0
                return Calendar.current.date(from: comps) ?? Date()
            }
            // 解析失败时，返回默认 09:00
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            comps.hour = 9
            comps.minute = 0
            comps.second = 0
            return Calendar.current.date(from: comps) ?? Date()
        }
        set {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            let hour = comps.hour ?? 9
            let minute = comps.minute ?? 0
            reminderTimeString = String(format: "%02d:%02d", hour, minute)
        }
    }
    
    // 功能组件数据
    let features = [
        //FeatureComponent(iconName: "star.fill", title: "技巧", destination: .skillView),
        //FeatureComponent(iconName: "star.fill", title: "活动", destination: .activityView)
        FeatureComponent(iconName: "list.clipboard", title: "action.feedback", destination: .feedbackView(mailType: .other)),
        FeatureComponent(iconName: "list.clipboard", title: "home.feature.skill", destination: .usageTipView)
    ]
    
    // Date formatter for "yyyy-MM-dd"
    let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    let localAds: [AdInfo] = [
        AdInfo(imageLocalURL: "Ads", appRoute: .usageTipView),
        AdInfo(appRoute: .usageTipView)
    ]
    
    init() {
        if userManager.isLoggedIn {
            fetchStatus()
        }
        fetchAdsUrl()
        fetchAnnouncements()
        syncReminderOnLaunch()
    }
    
    deinit {
        //deleteLocationSubscription()
    }
    
    // 启用提醒流程
    func enableReminder() {
        reminderManager.requestAuthorization { granted in
            if granted {
                self.reminderManager.scheduleDailyReminder(at: self.reminderTime)
            } else {
                DispatchQueue.main.async {
                    ToastManager.shared.show(toast: Toast(message: "home.sigin_in.toast.reminder_permission"))
                    self.reminderEnabled = false
                }
            }
        }
    }
    
    // 禁用提醒
    func disableReminder() {
        reminderManager.cancelReminder()
    }
    
    // 更新提醒时间
    func updateReminderTime(_ date: Date) {
        self.reminderTime = date
        if reminderEnabled {
            reminderManager.updateReminderTime(to: date)
        }
    }
    
    // 启动时保持一致（防止被系统清理）
    private func syncReminderOnLaunch() {
        if reminderEnabled {
            reminderManager.isReminderScheduled { exists in
                if !exists {
                    self.reminderManager.scheduleDailyReminder(at: self.reminderTime)
                }
            }
        }
    }
    
    func fetchStatus() {
        let request = APIRequest(path: "/user/sign_in/status", method: .get, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: SignInStatusDTO.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    //self.continuousDays = unwrappedData.continuous_days
                    self.items = self.makeItems(from: unwrappedData)
                default:
                    break
                }
            }
        }
    }
    
    func fetchAnnouncements() {
        let request = APIRequest(path: "/homepage/query_announcements", method: .get)
        NetworkService.sendRequest(with: request, decodingType: AnnouncementResponse.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    for announcement in unwrappedData.announcements {
                        self.announcements.append(announcement.content)
                    }
                default:
                    break
                }
            }
        }
    }
    
    func fetchAdsUrl() {
        let request = APIRequest(path: "/homepage/query_banner_ads", method: .get)
        NetworkService.sendRequest(with: request, decodingType: AdResponse.self) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    for ad in unwrappedData.ads {
                        self.ads.append(AdInfo(from: ad))
                    }
                    self.ads.append(contentsOf: self.localAds)
                default:
                    break
                }
            }
        }
    }
    
    private func makeItems(from statusDto: SignInStatusDTO) -> [SignInDay] {
        var days: [SignInDay] = []
        for dto in statusDto.items {
            if let d = dateFormatter.date(from: dto.date) {
                let isToday = Calendar.current.isDateInToday(d)
                days.append(
                    SignInDay(
                        date: d,
                        ccassetType: dto.ccasset_type,
                        ccassetReward: dto.ccasset_reward,
                        ccassetTypeVip: dto.ccasset_type_vip,
                        ccassetRewardVip: dto.ccasset_reward_vip,
                        state: isToday ? (statusDto.today_signed ? .claimed : .available) : .future,
                        state_vip: isToday ? (statusDto.today_signed_vip ? .claimed : .available) : .future
                    )
                )
            }
        }
        days.sort { $0.date < $1.date }
        return days
    }
    
    func signInToday(day: SignInDay) {
        guard !isLoading else { return }
        isLoading = true
        
        let request = APIRequest(path: "/user/sign_in/today", method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: SignInResultDTO.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let data):
                    if let unwrappedData = data {
                        let today = Calendar.current.startOfDay(for: Date())
                        if let idx = self.items.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                            self.items[idx].state = .claimed
                            self.assetManager.updateCCAsset(type: unwrappedData.ccasset_type, newBalance: unwrappedData.new_ccamount)
                        } else {
                            self.fetchStatus()
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "popup.claim_reward.title",
                            bottomButtons: [
                                .confirm("action.confirm")
                            ]
                        ) {
                            VStack {
                                Text("home.sign_in.popup.claim_reward_success.content")
                                HStack(spacing: 4) {
                                    Image(day.ccassetType.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                    Text("* \(day.ccassetReward)")
                                        .font(.system(size: 15))
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(Color.white)
                        }
                        //self.continuousDays = unwrappedData.continuous_days
                    }
                default:
                    break
                }
            }
        }
    }
    
    func signInTodayVip(day: SignInDay) {
        guard !isLoadingVip else { return }
        isLoadingVip = true
        
        let request = APIRequest(path: "/user/sign_in_vip/today", method: .post, requiresAuth: true)
        NetworkService.sendRequest(with: request, decodingType: SignInResultDTO.self, showErrorToast: true) { result in
            DispatchQueue.main.async {
                self.isLoadingVip = false
                switch result {
                case .success(let data):
                    if let unwrappedData = data {
                        let today = Calendar.current.startOfDay(for: Date())
                        if let idx = self.items.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
                            self.items[idx].state_vip = .claimed
                            self.assetManager.updateCCAsset(type: unwrappedData.ccasset_type, newBalance: unwrappedData.new_ccamount)
                        } else {
                            self.fetchStatus()
                        }
                        PopupWindowManager.shared.presentPopup(
                            title: "popup.claim_reward.title",
                            bottomButtons: [
                                .confirm("action.confirm")
                            ]
                        ) {
                            VStack {
                                Text("home.sign_in.popup.claim_reward_success.content_vip")
                                HStack(spacing: 4) {
                                    Image(day.ccassetType.iconName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20)
                                    Text("* \(day.ccassetReward)")
                                        .font(.system(size: 15))
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(Color.white)
                        }
                        //self.continuousDays = unwrappedData.continuous_days
                    }
                default:
                    break
                }
            }
        }
    }
}

/// - 请求通知权限
/// - 安排每天定时通知（默认09:00）
/// - 更改提醒时间
/// - 取消提醒
/// - 检查是否已安排提醒
/// - 提供跳转系统设置的URL
/// - 仅管理本地通知 & UserDefaults 中提醒时间持久化
/// - 支持 iOS 16+
final class SignInReminderManager {
    static let shared = SignInReminderManager()
    private init() {}
    
    private let notificationIdentifier = "com.sportsx.signInReminder"
    private let timeKey = "signInReminderTime"   // 存储为 "HH:mm"
    
    private var center: UNUserNotificationCenter {
        UNUserNotificationCenter.current()
    }
    
    // 请求通知权限（只在用户开启提醒时调用）
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self.center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            case .denied:
                DispatchQueue.main.async { completion(false) }
            @unknown default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    /// 安排每天定时提醒（使用 device 当前时区）
    /// - Parameter time: 仅使用其中的 hour & minute
    /// - Parameter body: 通知内容（默认：签到提醒文案）
    func scheduleDailyReminder(
        at time: Date,
        body: String.LocalizationValue = "home.sign_in.reminder.content"
    ) {
        // 保存用户选择的时间
        persistReminderTime(time)
        
        // 先取消旧的，避免重复
        cancelReminder()
        
        // 创建通知内容
        let content = UNMutableNotificationContent()
        content.title = String(localized: "home.sign_in.tile")
        content.body = String(localized: body)
        content.sound = .default
        content.userInfo = ["purpose": "sign_in_reminder"]
        
        // 提取 hour/minute
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        
        var dateComponents = DateComponents()
        dateComponents.hour = comps.hour
        dateComponents.minute = comps.minute
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: dateComponents,
            repeats: true
        )
        
        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )
        
        center.add(request) { error in
            if let error = error {
                print("[SignInReminderManager] add error: \(error)")
            } else {
                print("[SignInReminderManager] scheduled at \(comps.hour ?? 0):\(comps.minute ?? 0)")
            }
        }
    }
    
    // 取消签到提醒（包括 pending & delivered）
    func cancelReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
        print("[SignInReminderManager] cancelled reminder")
    }
    
    // 更新时间（内部调用 schedule 替换旧提醒）
    func updateReminderTime(to time: Date) {
        scheduleDailyReminder(at: time)
    }
    
    // 检查是否已有提醒在排队（pending）
    func isReminderScheduled(completion: @escaping (Bool) -> Void) {
        center.getPendingNotificationRequests { requests in
            let exists = requests.contains { $0.identifier == self.notificationIdentifier }
            DispatchQueue.main.async {
                completion(exists)
            }
        }
    }
    
    // 检查通知权限是否已授权（authorized/provisional/ephemeral）
    func checkNotificationPermission(completion: @escaping (Bool) -> Void) {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { completion(true) }
            default:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // 获取“去系统设置”URL（用于用户拒绝权限后的引导）
    func settingsURL() -> URL? {
        URL(string: UIApplication.openSettingsURLString)
    }
    
    // MARK: - 存储提醒时间
    private func persistReminderTime(_ date: Date) {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = comps.hour, let minute = comps.minute else { return }
        let string = String(format: "%02d:%02d", hour, minute)
        UserDefaults.standard.setValue(string, forKey: timeKey)
    }
    
    // 获取保存的时间（若无则返回今天 09:00）
    func storedReminderTime() -> Date {
        if let s = UserDefaults.standard.string(forKey: timeKey) {
            let parts = s.split(separator: ":").compactMap { Int($0) }
            if parts.count == 2 {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = parts[0]
                comps.minute = parts[1]
                comps.second = 0
                if let d = Calendar.current.date(from: comps) {
                    return d
                }
            }
        }
        // 默认 09:00
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }
}


struct AdInfo: Identifiable {
    let id = UUID()
    let imageURL: String?
    let imageLocalURL: String?
    let webURL: String?
    let appRoute: AppRoute?
    
    init(from ad: AdDTO) {
        self.imageURL = ad.image_url
        self.imageLocalURL = nil
        self.webURL = ad.web_url
        self.appRoute = nil
    }
    
    init(
        imageURL: String? = nil,
        imageLocalURL: String? = nil,
        webURL: String? = nil,
        appRoute: AppRoute? = nil
    ) {
        self.imageURL = imageURL
        self.imageLocalURL = imageLocalURL
        self.webURL = webURL
        self.appRoute = appRoute
    }
}

struct AdDTO: Codable {
    let image_url: String
    let web_url: String?
}

struct AdResponse: Codable {
    let ads: [AdDTO]
}

struct FeatureComponent: Identifiable {
    let id = UUID()
    let iconName: String
    let title: LocalizedStringKey
    let destination: AppRoute
}

enum RewardState: String, Codable {
    case claimed = "claimed"
    case available = "available"
    case future = "future"
    
    var color: Color {
        switch self {
        case .claimed: return .green
        case .available: return .orange
        case .future: return .white.opacity(0.2)
        }
    }
    
    var icon: some View {
        switch self {
        case .claimed: return Image(systemName: "checkmark").foregroundStyle(Color.white)
        case .available: return Image(systemName: "gift.fill").foregroundStyle(Color.white)
        case .future: return Image(systemName: "gift.fill").foregroundStyle(Color.white.opacity(0.6))
        }
    }
}

struct SignInDay: Identifiable {
    let id = UUID()
    let date: Date
    let ccassetType: CCAssetType
    let ccassetReward: Int
    let ccassetTypeVip: CCAssetType
    let ccassetRewardVip: Int
    var state: RewardState
    var state_vip: RewardState
}

struct SignInItemDTO: Codable {
    let date: String                    // yyyy-MM-dd
    let ccasset_type: CCAssetType       // 非订阅奖励
    let ccasset_reward: Int             // 非订阅奖励
    let ccasset_type_vip: CCAssetType   // 订阅奖励
    let ccasset_reward_vip: Int         // 订阅奖励
}

struct SignInStatusDTO: Codable {
    let today_signed: Bool
    let today_signed_vip: Bool
    let items: [SignInItemDTO]
}

struct SignInResultDTO: Codable {
    let ccasset_type: CCAssetType
    let new_ccamount: Int
}

struct AnnouncementInfo: Identifiable {
    let id = UUID()
    let content: String
    let date: Date?
    
    init(from announcement: AnnouncementDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.content = announcement.content
        self.date = formatter.date(from: announcement.date)
    }
}

struct AnnouncementDTO: Codable {
    let content: String
    let date: String
}

struct AnnouncementResponse: Codable {
    let announcements: [AnnouncementDTO]
}
