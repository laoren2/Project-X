//
//  ElapsedTimeView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI

struct ElapsedTimeView: View {
    var elapsedTime: TimeInterval = 0
    var showSubseconds: Bool = true

    var body: some View {
        Text(Self.formatted(elapsedTime, showSubseconds: showSubseconds))
            .fontWeight(.semibold)
    }

    // 纯整数运算直接拼字符串：避免在 TimelineView 高频刷新（最高 30fps）下
    // 反复走 DateComponentsFormatter（本地化 + NSCalendar，开销大、每帧分配），
    // 那正是熄屏/亮屏切换时「时间卡顿」的主因之一。
    static func formatted(_ time: TimeInterval, showSubseconds: Bool) -> String {
        let clamped = max(0, time)
        let totalSeconds = Int(clamped)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if showSubseconds {
            let hundredths = Int((clamped - Double(totalSeconds)) * 100)
            let separator = Locale.current.decimalSeparator ?? "."
            return String(format: "%02d:%02d%@%02d", minutes, seconds, separator, hundredths)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
