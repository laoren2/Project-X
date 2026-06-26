//
//  WatchPreview.swift
//  sportsx_Watch Watch App
//
//  仅用于录制预览/宣传视频的场景与假数据动画。
//  ⚠️ 提交前请将 WatchPreview.enabled 置为 false（或删除本文件 + sportsx_WatchApp 里的入口分支）。
//
//  Created by 任杰 on 2026/6/18.
//

import SwiftUI


// 预览根：纵向分页在两个场景间切换；每个场景成为当前页时重播动画
struct WatchPreviewRoot: View {
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            PaceComparePreviewScene(active: page == 0).tag(0)
            RadarPreviewScene(active: page == 1).tag(1)
        }
        .tabViewStyle(.verticalPage)
        .background(Color.black)
        .ignoresSafeArea()
    }
}

// MARK: - 场景一：race/route 名次环 + 名次跳动 + PB 对比

struct PaceComparePreviewScene: View {
    let active: Bool

    private let total = 128
    @State private var displayRank = 128
    @State private var fraction: Double = 0
    @State private var pbDelta: Double = -45      // 秒，>0 领先
    @State private var startDate = Date()
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            // 外圈 3/4 名次环 + 进度末端圆点
            RankRingView(fraction: fraction)

            // 底部缺口处名次：越靠前字号越大，弹性放缩
            VStack {
                Spacer()
                Text("# \(displayRank) / \(total)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundColor(.orange)
                    .scaleEffect(0.85 + 0.6 * fraction)
                    .padding(.bottom, 4)
            }

            // 中间：时间 + PB 对比
            VStack(spacing: 6) {
                TimelineView(.periodic(from: startDate, by: 1.0 / 30.0)) { ctx in
                    ElapsedTimeView(elapsedTime: ctx.date.timeIntervalSince(startDate), showSubseconds: true)
                        .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.yellow)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                pbDeltaView
            }
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if active { play() } }
        .onChange(of: active) { if active { play() } }
    }

    private var pbDeltaView: some View {
        let ahead = pbDelta >= 0
        return HStack(spacing: 3) {
            Image(systemName: ahead ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                .foregroundStyle(ahead ? Color.green : Color.red)
            Text(ElapsedTimeView.formatted(abs(pbDelta), showSubseconds: false))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .font(.system(size: 16, weight: .semibold, design: .rounded).monospacedDigit())
    }

    private func play() {
        task?.cancel()
        startDate = Date()
        fraction = 0
        displayRank = total
        pbDelta = -15
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)   // 等 1s
            // 逐帧驱动（~60fps 直接更新，不用 withAnimation）：避免弹簧被反复打断的卡顿与起始跳变
            let duration = 4.0
            let begin = Date()
            while !Task.isCancelled {
                let u = min(Date().timeIntervalSince(begin) / duration, 1.0)
                let f = Self.progressCurve(u)
                fraction = f
                displayRank = max(1, total - Int((Double(total - 1) * f).rounded()))
                pbDelta = -15 + 30 * f
                if u >= 1.0 { break }
                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    // 进度曲线：0→中间(平滑起步) → 围绕中间来回摆动几次(钟形包络渐起渐落) → 中间→1。
    // 各相位边界处速度为 0，整体顺滑无跳变。
    private static func progressCurve(_ u: Double) -> Double {
        let mid = 0.5
        let aEnd = 0.25, bEnd = 0.70
        if u <= aEnd {
            return mid * smoothstep(u / aEnd)
        } else if u <= bEnd {
            let x = (u - aEnd) / (bEnd - aEnd)
            let amp = 0.25 * sin(.pi * x)            // 钟形包络：摆动渐起渐落
            return mid + amp * sin(2 * .pi * 1.5 * x)
        } else {
            return mid + (1 - mid) * smoothstep((u - bEnd) / (1 - bEnd))
        }
    }

    // 平滑插值：两端导数为 0
    private static func smoothstep(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}

// MARK: - 场景二：雷达 箭头逐一弹出 → 一起旋转 → 一个进入视野变 reward

struct RadarPreviewScene: View {
    let active: Bool

    private struct PMarker: Identifiable {
        let id: Int
        var angle: Double          // 基础方位（度，0=正上，顺时针）
        var radiusFraction: Double // 0..1
        var inRange: Bool
        var reward: String
        var shown: Bool
        var distanceText: String
    }

    @State private var markers: [PMarker] = RadarPreviewScene.initialMarkers()
    @State private var rotation: Double = 0
    @State private var startDate = Date()
    @State private var task: Task<Void, Never>?

    private static func initialMarkers() -> [PMarker] {
        [
            PMarker(id: 0, angle: -55, radiusFraction: 0.9, inRange: false, reward: "coin", shown: false, distanceText: "1.2km"),
            PMarker(id: 1, angle: 45, radiusFraction: 0.9, inRange: false, reward: "blue_stone", shown: false, distanceText: "1.1km"),
            PMarker(id: 2, angle: 155, radiusFraction: 0.9, inRange: false, reward: "coupon", shown: false, distanceText: "1.4km"),
        ]
    }

    var body: some View {
        GeometryReader { geo in
            let radius = min(geo.size.width, geo.size.height) / 2 - 4
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.orange.opacity(0.15), .clear],
                                         center: .center, startRadius: 0, endRadius: radius))
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .stroke(Color.orange.opacity(0.18), lineWidth: 1)
                        .frame(width: radius * 2 * CGFloat(i) / 3,
                               height: radius * 2 * CGFloat(i) / 3)
                }
                ForEach(markers) { m in
                    markerView(m)
                        .scaleEffect(m.shown ? 1 : 0)
                        .opacity(m.shown ? 1 : 0)
                        .position(point(m, center: center, radius: radius))
                }
                TimelineView(.periodic(from: startDate, by: 1.0 / 30.0)) { ctx in
                    ElapsedTimeView(elapsedTime: ctx.date.timeIntervalSince(startDate), showSubseconds: true)
                        .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundColor(.yellow)
                }
                .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { if active { play() } }
        .onChange(of: active) { if active { play() } }
    }

    private func point(_ m: PMarker, center: CGPoint, radius: CGFloat) -> CGPoint {
        let a = (m.angle + rotation) * .pi / 180
        let r = radius * CGFloat(m.radiusFraction)
        return CGPoint(x: center.x + r * CGFloat(sin(a)), y: center.y - r * CGFloat(cos(a)))
    }

    private func markerView(_ m: PMarker) -> some View {
        VStack(spacing: 1) {
            ZStack {
                // 范围外：箭头指向网格方向
                Image(systemName: "location.north.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.orange)
                    .rotationEffect(.degrees(m.angle + rotation))
                    .opacity(m.inRange ? 0 : 1)
                // 范围内：reward 图标 + 金色光晕
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.yellow.opacity(0.45), .clear],
                                             center: .center, startRadius: 1, endRadius: 12))
                        .frame(width: 24, height: 24)
                    Image(m.reward).resizable().scaledToFit().frame(height: 16)
                }
                .opacity(m.inRange ? 1 : 0)
            }
            Text(m.distanceText)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func play() {
        task?.cancel()
        startDate = Date()
        markers = RadarPreviewScene.initialMarkers()
        rotation = 0
        task = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)   // 等 1s

            // 1) 三个箭头逐一弹出（跳动）
            for i in markers.indices {
                if Task.isCancelled { return }
                withAnimation(.spring(response: 0.35, dampingFraction: 0.45)) {
                    markers[i].shown = true
                }
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            try? await Task.sleep(nanoseconds: 300_000_000)

            // 2) 一起旋转 2s（逐帧步进，保证沿弧线运动、距离文字保持正立）
            let rotSteps = 60
            for i in 0...rotSteps {
                if Task.isCancelled { return }
                rotation = 360 * Double(i) / Double(rotSteps)
                try? await Task.sleep(nanoseconds: UInt64(2.0 / Double(rotSteps) * 1_000_000_000))
            }

            // 3) 其中一个进入视野 → 变 reward 图标
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                markers[0].radiusFraction = 0.42
                markers[0].inRange = true
                markers[0].distanceText = "380m"
            }
        }
    }
}

#Preview() {
    WatchPreviewRoot()
}
