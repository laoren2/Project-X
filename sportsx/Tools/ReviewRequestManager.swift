//
//  ReviewRequestManager.swift
//  sportsx
//
//  应用评价邀请
//  原生 SKStoreReview 无回调、拿不到分数、也无法在评分后串联，故用「体验问句」分流：
//  - 喜欢 → 弹「快速评分（原生 in-app）/ 写评价（write-review 深链）」两个入口，用户自选
//  - 一般 → 邀请进入站内反馈
//  仅在「成功完成训练/比赛」这一价值时刻、且满足门槛/节流时触发。不按星级过滤，规避审核 1.1.7。
//

import SwiftUI
import UIKit
import StoreKit


final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    // App Store 数字 ID（与设置页手动评价入口一致）
    private let appStoreID = "6755963833"

    // 门槛与节流
    private let successThreshold = 3        // 累计成功完成场次达到才考虑
    private let cooldownDays = 120          // 两次请求最小间隔
    private let maxRequests = 3             // 自定义弹窗的总次数上限，避免打扰

    // 持久化 key
    private enum Key {
        static let successCount = "review.successCount"
        static let lastRequestDate = "review.lastRequestDate"
        static let requestCount = "review.requestCount"
        static let lastVersion = "review.lastVersion"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // 成功完成一次训练/比赛后调用：累加计数并尝试触发
    func onSessionFinishedSuccessfully() {
        defaults.set(defaults.integer(forKey: Key.successCount) + 1, forKey: Key.successCount)
        attemptPrompt()
    }

    private var isEligible: Bool {
        guard defaults.integer(forKey: Key.successCount) >= successThreshold else { return false }
        guard defaults.integer(forKey: Key.requestCount) < maxRequests else { return false }
        // 当前版本已请求过则不再请求
        if defaults.string(forKey: Key.lastVersion) == currentVersion { return false }
        // 冷却期内不重复请求
        if let last = defaults.object(forKey: Key.lastRequestDate) as? Date,
           Date().timeIntervalSince(last) < Double(cooldownDays) * 86400 {
            return false
        }
        return true
    }

    // 延迟触发，避免盖住结算弹窗；当前有弹窗时重试，仍占用则放弃（不消耗额度，下次再来）
    private func attemptPrompt(retries: Int = 2) {
        guard isEligible else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard self.isEligible else { return }
            if !PopupWindowManager.shared.popups.isEmpty {
                if retries > 0 { self.attemptPrompt(retries: retries - 1) }
                return
            }
            self.presentSentimentPrompt()
        }
    }

    private func consumeQuota() {
        defaults.set(Date(), forKey: Key.lastRequestDate)
        defaults.set(defaults.integer(forKey: Key.requestCount) + 1, forKey: Key.requestCount)
        defaults.set(currentVersion, forKey: Key.lastVersion)
    }

    // 第一步：体验问句（喜欢 / 一般），不出现伪造星级
    private func presentSentimentPrompt() {
        consumeQuota()
        PopupWindowManager.shared.presentPopup(
            title: "review.sentiment.title",
            bottomButtons: [
                PopupButton(action: { self.presentFeedbackInvite() }) {
                    self.sentimentButtonLabel("review.sentiment.dislike", icon: "heart_broken", background: Color.gray.opacity(0.3))
                },
                PopupButton(action: { self.presentRateOrReviewInvite() }) {
                    self.sentimentButtonLabel("review.sentiment.like", icon: "heart", background: Color.pink.opacity(0.25))
                }
            ]
        )
    }

    // 体验问句的自定义按钮样式：文字 + 图标 + 背景（灰 / 淡粉）
    private func sentimentButtonLabel(_ titleKey: String, icon: String, background: Color) -> some View {
        HStack(spacing: 6) {
            Text(LocalizedStringKey(titleKey))
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 18, height: 18)
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(Color.white)
        .padding(.vertical, 10)
        .padding(.horizontal, 20)
        .background(background)
        .cornerRadius(10)
    }

    // 第二步（喜欢）：并列提供「快速评分（原生）」与「写评价（深链）」两个入口
    private func presentRateOrReviewInvite() {
        PopupWindowManager.shared.presentPopup(
            title: "review.invite.title",
            message: "review.invite.message",
            bottomButtons: [
                .confirm("review.action.rate") { self.requestNativeReview() },
                .confirm("review.action.review") { self.openWriteReview() }
            ]
        )
    }

    // 第二步（一般）：邀请站内反馈
    private func presentFeedbackInvite() {
        PopupWindowManager.shared.presentPopup(
            title: "review.feedback.title",
            message: "review.feedback.message",
            bottomButtons: [
                .cancel("review.action.later"),
                .confirm("review.action.feedback") {
                    NavigationManager.shared.append(.feedbackView(mailType: .other))
                }
            ]
        )
    }

    // 原生 in-app 评分弹窗（真实评分、不跳出 app；无回调、拿不到分数）
    private func requestNativeReview() {
        Task { @MainActor in
            let windowScenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let scene = windowScenes.first(where: { $0.activationState == .foregroundActive }) ?? windowScenes.first {
                AppStore.requestReview(in: scene)
            }
        }
    }

    // 跳 App Store 写评价页（评分 + 文字评论合一，跳出 app）
    private func openWriteReview() {
        if let url = URL(string: "https://apps.apple.com/app/\(appStoreID)?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

#if DEBUG
    // 跳过所有门槛直接弹出，用于调试 UI/分支
    func debugForcePrompt() {
        presentSentimentPrompt()
    }

    // 清空持久化状态，用于从头验证门槛/节流逻辑
    func debugResetState() {
        defaults.removeObject(forKey: Key.successCount)
        defaults.removeObject(forKey: Key.lastRequestDate)
        defaults.removeObject(forKey: Key.requestCount)
        defaults.removeObject(forKey: Key.lastVersion)
    }
#endif
}
