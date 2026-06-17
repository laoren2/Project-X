//
//  RealtimePaceCompareView.swift
//  sportsx
//
//  运动中实时配速展示：预测完赛名次卡 + 与个人最佳（PB）对比卡。
//  对比卡默认展示时间差，点击切换为距离差；领先绿、落后红。
//  数据来源 CompetitionManager 的实时发布值，race / route training 两个 realtime 页共用。
//
//  Created by Claude on 2026/6/16.
//

import SwiftUI


struct RealtimePaceCompareView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var userManager = UserManager.shared
    @State private var showDistanceDelta = false

    private var manager: CompetitionManager { appState.competitionManager }

    var body: some View {
        VStack(spacing: 12) {
            // 预测完赛名次（始终占位，无数据显示 --）
            paceCapsule("realtime.pace.predicted_rank") {
                rankValue
            }
            // 与个人最佳对比（始终占位；订阅用户点击切换时间/距离差）
            paceCapsule("realtime.pace.vs_pb", onTapWhenUnlocked: { showDistanceDelta.toggle() }) {
                paceDeltaContent
            }
        }
        .padding(.horizontal, 20)
    }

    // 单个 capsule：标题 + 右侧数值；未订阅时各自叠加渐变蒙层
    @ViewBuilder
    private func paceCapsule<V: View>(_ titleKey: String,
                                      onTapWhenUnlocked: (() -> Void)? = nil,
                                      @ViewBuilder value: () -> V) -> some View {
        HStack {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
            Spacer()
            value()
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
        .foregroundStyle(Color.white)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
                .overlay(Capsule().stroke(Color.orange, lineWidth: 1))
        )
        .overlay {
            // 订阅专属：未订阅则该 capsule 各自用从右到左的渐变蒙层盖住右侧真实数据
            if !userManager.user.isVip {
                unlockMask
            }
        }
        .contentShape(Capsule())
        .onTapGesture {
            if userManager.user.isVip {
                onTapWhenUnlocked?()
            } else {
                appState.navigationManager.append(.subscriptionDetailView)
            }
        }
    }

    // 预测名次数值（无数据占位）
    @ViewBuilder private var rankValue: some View {
        if let rank = manager.pacePredictedRank, userManager.user.isVip {
            Text("# \(rank) / \(manager.pacePredictedTotal)")
        } else {
            Text("--")
        }
    }

    // 当前展示的差值（正 = 领先）
    private var currentDelta: Double? {
        showDistanceDelta ? manager.paceDeltaDistance : manager.paceDeltaTime
    }

    @ViewBuilder private var paceDeltaContent: some View {
        if let d = currentDelta, userManager.user.isVip {
            let ahead = d >= 0
            let mag = abs(d)
            HStack(spacing: 4) {
                Image(systemName: ahead ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ahead ? Color.green : Color.red)
                if showDistanceDelta {
                    (Text(String(format: "%.0f ", mag)) + Text("distance.m"))
                } else {
                    Text(TimeDisplay.formattedTime(mag))
                }
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.secondText)
            }
        } else {
            Text("--")
        }
    }
    
    // 单 capsule 的未订阅蒙层：右侧不透明盖住数值，向左渐隐；「解锁」+ vip 图标
    @ViewBuilder private var unlockMask: some View {
        ZStack(alignment: .trailing) {
            LinearGradient(
                stops: [
                    .init(color: Color.gray.opacity(0.0), location: 0.0),
                    .init(color: Color.gray.opacity(0.5), location: 0.5),
                    .init(color: Color.gray.opacity(0.8), location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            HStack(spacing: 6) {
                Image("vip_icon_on")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text("realtime.pace.unlock")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white)
            }
            .padding(.trailing, 20)
        }
        .clipShape(Capsule())
    }
}
