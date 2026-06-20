//
//  test.swift
//  sportsx
//
//  only use for local unit tests
//  ⚠️ clear before each submission
//
//  Created by 任杰 on 2024/9/20.
//

import SwiftUI
import UIKit
import MapKit
import Combine
import CoreML
import os

// 用于录制部分场景的展示视频
struct PreviewLaunchView: View {
    @State var progress: Double = 0
    @State private var sloganOpacity: Double = 0
    @State private var iconScale: CGFloat = 0.85
    @State private var contentScale: CGFloat = 1.0
    @State private var textScale: CGFloat = 0.25
    @State private var contentOpacity: Double = 1.0
    @State private var endingTextOpacity: Double = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                Image("single_app_icon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100)
                    .foregroundStyle(Color.orange.opacity(0.8))
                    .scaleEffect(iconScale)
                Text("app.slogan.preview.5")
                    .font(.system(.title, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color.secondText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 32)
                    .opacity(sloganOpacity)
                //ProgressBar(progress: progress)
                //    .frame(height: 10)
                //    .padding(.top, 10)
                //    .padding(.bottom, 50)
                Spacer()
            }
            .scaleEffect(contentScale)
            .opacity(contentOpacity)
            
            Text("app.slogan.preview.5")
                .font(.system(size: 28, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.secondText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .scaleEffect(textScale)
                .opacity(endingTextOpacity)
        }
        .padding()
        .ignoresSafeArea(.all)
        .background(Color.defaultBackground)
        .onAppear {
            progress = 0
            sloganOpacity = 0
            iconScale = 0.85
            contentScale = 1.0
            contentOpacity = 1.0
            endingTextOpacity = 0

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeIn(duration: 0.5)) {
                    sloganOpacity = 1
                }

                withAnimation(.easeOut(duration: 0.8)) {
                    iconScale = 1.0
                }

                /*withAnimation(
                    .timingCurve(0.2, 0.75, 0.8, 0.25, duration: 1.5)
                ) {
                    progress = 1.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        textScale = 1
                        contentScale = 0.25
                        contentOpacity = 0
                        endingTextOpacity = 1
                    }
                }*/
            }
        }
    }
}

/*struct LaunchRecordingView: View {
    @State private var progress: Double = 0
    @State private var sloganIndex: Int = 0
    @State private var isVisible: Bool = true
    
    private let slogans: [String] = [
        "Play for Passion",
        "動いて、遊べ。",
        "열정을 플레이하다",
        "YI起动    YI起玩",
        "YI起動    YI起玩"
    ]
    
    private let timer = Timer.publish(every: 1.2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            Image("single_app_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 100)
                .foregroundStyle(Color.orange.opacity(0.85))
            
            ZStack {
                ForEach(Array(slogans.enumerated()), id: \.offset) { index, text in
                    if sloganIndex == index {
                        SloganTextView(text: text)
                            .transition(
                                .asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                )
                            )
                    }
                }
            }
            .frame(height: 40)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .animation(.easeInOut(duration: 0.5), value: sloganIndex)
            
            ProgressBar(progress: progress)
                .frame(height: 10)
            
            Spacer()
        }
        .padding()
        .ignoresSafeArea(.all)
        .background(Color.defaultBackground)
        .task {
            withAnimation(.linear(duration: 6.0)) {
                progress = 1.0
            }
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.45)) {
                sloganIndex = (sloganIndex + 1) % slogans.count
            }
        }
    }
}

struct SloganTextView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(Color.secondText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
    
    private var font: Font {
        if text.contains("열정") {
            return .system(size: 28, weight: .semibold, design: .rounded)
        }
        
        if text.contains("情熱") {
            return .system(size: 30, weight: .bold, design: .rounded)
        }
        
        return .system(size: 30, weight: .heavy, design: .rounded)
    }
}*/

struct PreviewRealtimeView: View {
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    @State private var mapMode: MapViewMode = .followUser
    @State var isRecording: Bool = false
    @State private var distance: Double = 0.1
    @State private var avgSpeed: Double = 10
    @State private var elevGain: Double = 5
    @State private var heartRate: Int = 108
    @State private var energy: Int = 23
    @State private var power: Int = 59
    @State private var cadence: Int = 156
    @State private var startButtonScale: CGFloat = 1.0
    @State private var startButtonOpacity: Double = 1.0
    @State private var metricsOpacity: Double = 0
    @State private var metricsScale: CGFloat = 0.8
    @State private var timer: Timer?
    @State private var demoPath: [PreviewPathPoint] = []
    @State private var routeProgress: CGFloat = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var displayElapsedTime: TimeInterval = 0
    @State private var simulatedLocation = CLLocation(latitude: 38.9203, longitude: -77.0288)
    @State private var currentRewardAsset: CCAssetType?
    @State private var rewardOpacity: Double = 0
    @State private var rewardOffsetY: CGFloat = 10
    
    private let rewardMoments: [(CGFloat, CCAssetType)] = [
        (0.3, .stone1),
        (0.65, .stone2),
        (0.85, .coupon)
    ]
    // 定义两列布局
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // 动态构建 items 数组
    var items: [(String, String, String, Color)] {
        var temp: [(String, String, String, Color)] = []

        temp.append(("competition.realtime.distance", String(format: "%.2f ", distance), "distance.km", Color.orange))
        temp.append(("competition.realtime.avgspeed", String(format: "%.1f ", avgSpeed), "speed.km/h", Color.yellow))
        temp.append(("competition.realtime.heartrate", "\(heartRate) ", "heartrate.unit", Color.red))
        temp.append(("competition.realtime.elev_gain", String(format: "%.1f ", elevGain), "distance.m", Color.purple))
        temp.append(("competition.realtime.energy", "\(energy) ", "energy.unit", Color.blue))
        temp.append(("competition.realtime.power", "\(power) ", "power.unit", Color.green))
        temp.append(("competition.result.stepcadence", "\(cadence) ", "stepCadence.unit", Color.pink))

        return temp
    }
    
    var body: some View {
        // 显示实时比赛数据
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                PreviewRealtimeMapView(
                    //path: demoPath,
                    mapMode: $mapMode,
                    userLocation: simulatedLocation,
                    isShowSheet: !chevronDirection,
                    routeProgress: routeProgress
                )
                .ignoresSafeArea()
                
                Button(action: {
                    
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .bold()
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                        .padding()
                }
            }
            
            VStack {
                HStack {
                    VStack {
                        ZStack {
                            Circle()
                                .fill(mapMode == .followUser ? Color.defaultBackground : Color.black.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(mapMode == .followUser ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            Image("location")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                        ZStack {
                            Circle()
                                .fill(Color.defaultBackground)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.orange, lineWidth: 2)
                                )
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 20))
                                .frame(width: 20, height: 20)
                        }
                    }
                    .opacity(0)
                    Spacer()
                    // 添加一个图标实时显示路径触发奖励成功
                    VStack {
                        if let asset = currentRewardAsset {
                            HStack(spacing: 6) {
                                Text("+")
                                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Color.orange)
                                Image(asset.iconName)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                            .shadow(color: Color.gold.opacity(0.35), radius: 10)
                            .opacity(rewardOpacity)
                            .offset(y: rewardOffsetY)
                        }
                    }
                    Spacer()
                    VStack {
                        ZStack {
                            Circle()
                                .fill(mapMode == .followUser ? Color.defaultBackground : Color.black.opacity(0.6))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(mapMode == .followUser ? Color.orange : Color.clear, lineWidth: 2)
                                )
                            Image("location")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                        }
                        ZStack {
                            Circle()
                                .fill(Color.defaultBackground)
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle()
                                        .stroke(Color.orange, lineWidth: 2)
                                )
                            Image(systemName: "square.grid.2x2")
                                .font(.system(size: 20))
                                .frame(width: 20, height: 20)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding()
                
                ZStack {
                    HStack {
                        Image("bike")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Spacer()
                        Image("free_training")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 20)
                            .padding(6)
                            .background(Color.black.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    HStack(alignment: .top, spacing: 5) {
                        Text("GPS")
                            .foregroundStyle(Color.white)
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<4) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.green)
                                    .frame(width: 6, height: CGFloat(6 + index * 4))
                            }
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal)
                
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: chevronDirection2 ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white)
                            .bold()
                            .padding(.vertical, 10)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        chevronDirection2.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeIn(duration: 0.2)) {
                                chevronDirection.toggle()
                            }
                        }

                        if !chevronDirection {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                startDemoMovement()
                            }
                        }
                    }
                    ZStack {
                        ProgressBar(progress: Double(2) / Double(5))
                            .frame(height: 20)
                        Text("checked \(2) / \(5)")
                            .foregroundStyle(Color.white)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                    }
                    .padding(.horizontal)
                    ScrollView {
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                if isRecording {
                                    Text(TimeDisplay.formattedTime(elapsedTime))
                                        .contentTransition(.numericText())
                                        /*.animation(
                                            .linear(duration: 1.0 / 30.0),
                                            value: elapsedTime
                                        )*/
                                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                                    VStack(spacing: 10) {
                                        Text("- \(28)s")
                                            .foregroundStyle(Color.green)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 10)
                                        Text("+ \(8)s")
                                            .foregroundStyle(Color.pink)
                                            .font(.system(size: 20, weight: .bold, design: .rounded))
                                            .padding(.horizontal, 10)
                                    }
                                    // 背景按钮
                                    Text("training.realtime.action.finish")
                                        .font(.system(size: 20))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                } else {
                                    Spacer()
                                    Text("competition.realtime.action.start")
                                        .font(.system(size: 30))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .frame(width: 100, height: 100)
                                        .background(Color.green)
                                        .clipShape(Circle())
                                        .scaleEffect(startButtonScale)
                                        .opacity(startButtonOpacity)
                                        .exclusiveTouchTapGesture {
                                            startFreeTraining()
                                        }
                                    Spacer()
                                }
                            }
                            .foregroundStyle(Color.white)
                            
                            if isRecording {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(items, id: \.0) { title, value, unit, color in
                                        VStack {
                                            Text(LocalizedStringKey(title))
                                                .font(.headline)
                                            (Text(value) + Text(LocalizedStringKey(unit)))
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .contentTransition(.numericText())
                                                /*.animation(
                                                    .linear(duration: 1.0 / 30.0),
                                                    value: value
                                                )*/
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 80)
                                        .background(color.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                //.scaleEffect(metricsScale)
                                //.opacity(metricsOpacity)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                    .frame(height: 450)
                }
                .background(Color.defaultBackground.opacity(0.8))
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
            }
            .offset(y: chevronDirection ? 300 : 0)
        }
        .onValueChange(of: routeProgress) { _, newValue in
            guard let reward = rewardMoments.first(where: {
                abs($0.0 - newValue) < 0.01
            }) else {
                return
            }

            currentRewardAsset = reward.1

            rewardOpacity = 0
            rewardOffsetY = 10

            withAnimation(
                .spring(response: 0.2, dampingFraction: 0.72)
            ) {
                rewardOpacity = 1
                rewardOffsetY = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.2)) {
                    rewardOpacity = 0
                    rewardOffsetY = -10
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private func startDemoMovement() {
        routeProgress = 0

        let duration: Double = 3.0
        let start = CACurrentMediaTime()

        Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { timer in
            let elapsed = CACurrentMediaTime() - start
            let progress = min(elapsed / duration, 1.0)
            let eased = 1.0 - pow(1.0 - progress, 3.0)
            routeProgress = progress

            if progress >= 1.0 {
                timer.invalidate()
            }
        }
    }

    private func startFreeTraining() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            startButtonScale = 0.2
            startButtonOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isRecording = true

            withAnimation(.spring(response: 0.65, dampingFraction: 0.75)) {
                metricsScale = 1.0
                metricsOpacity = 1.0
            }
        }

        elapsedTime = 0
        displayElapsedTime = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { _ in
            if routeProgress >= 1.0 {
                timer?.invalidate()
                return
            }

            elapsedTime += Double.random(in: 10...15)

            distance += Double.random(in: 0.1...0.8)
            avgSpeed = Double.random(in: 18...32)
            elevGain += Double.random(in: 1...5)
            heartRate = Int.random(in: 110...180)
            energy += Int.random(in: 3...10)
            power = Int.random(in: 120...180)
            cadence = Int.random(in: 150...170)
        }
    }
}

struct PreviewPathPoint: Codable {
    let lat: Double
    let lon: Double
    let speed: Double
    let altitude: Double
    let heart_rate: Double?
    let timestamp: TimeInterval
}

struct PreviewRealtimeMapView: View {
    @Binding var mapMode: MapViewMode
    var userLocation: CLLocation?
    let isShowSheet: Bool
    let routeProgress: CGFloat

    private let gridColumns = 15
    private let gridRows = 20

    private let buffIndexes: Set<Int> = [52, 80, 97, 108, 138, 156, 167]

    private let buffAssetMap: [Int: CCAssetType] = [
        52: .stone3,
        80: .stone1,
        97: .coin,
        108: .stone1,
        138: .stone2,
        156: .coupon,
        167: .voucher
    ]

    private let buffConditionMap: [Int: String?] = [
        52: "buff_condition_speed",
        80: nil,
        97: "buff_condition_distance",
        108: nil,
        138: nil,
        156: "buff_condition_distance",
        167: "buff_condition_speed"
    ]

    private let crownIndexes: Set<Int> = [
        21, 37, 65, 74, 92, 116, 106, 142, 172
    ]

    private var normalizedRoute: [CGPoint] {
        [
            CGPoint(x: 0.10, y: 0.18),
            CGPoint(x: 0.14, y: 0.185),
            CGPoint(x: 0.18, y: 0.192),
            CGPoint(x: 0.23, y: 0.198),
            CGPoint(x: 0.29, y: 0.205),
            CGPoint(x: 0.36, y: 0.218),
            CGPoint(x: 0.44, y: 0.238),
            CGPoint(x: 0.52, y: 0.268),
            CGPoint(x: 0.58, y: 0.295),
            CGPoint(x: 0.54, y: 0.312),
            CGPoint(x: 0.48, y: 0.322),
            CGPoint(x: 0.42, y: 0.329),
            CGPoint(x: 0.35, y: 0.336),
            CGPoint(x: 0.29, y: 0.348),
            CGPoint(x: 0.24, y: 0.372),
            CGPoint(x: 0.23, y: 0.402),
            CGPoint(x: 0.27, y: 0.425),
            CGPoint(x: 0.33, y: 0.442),
            CGPoint(x: 0.40, y: 0.452),
            CGPoint(x: 0.48, y: 0.462),
            CGPoint(x: 0.56, y: 0.474),
            CGPoint(x: 0.63, y: 0.486),
            CGPoint(x: 0.69, y: 0.495),
            CGPoint(x: 0.74, y: 0.503),
            CGPoint(x: 0.79, y: 0.512),
            CGPoint(x: 0.83, y: 0.522),
            CGPoint(x: 0.86, y: 0.532)
        ]
    }

    private func crownAnimatedScale(
        current: CGFloat,
        trigger: CGFloat
    ) -> CGFloat {
        let delta = current - trigger

        if delta <= 0 {
            return 0.15
        }

        if delta >= 0.18 {
            return 1.0
        }

        let normalized = delta / 0.18

        let spring =
            1.0
            + (sin(normalized * .pi * 2.2) * 0.22)
            * (1.0 - normalized)

        return max(0.15, spring)
    }
    
    private func crownProgress(for index: Int) -> CGFloat {
        let sorted = crownIndexes.sorted()

        guard let position = sorted.firstIndex(of: index) else {
            return 0
        }

        return CGFloat(position + 1)
            / CGFloat(sorted.count + 2)
    }
    
    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            let routePoints = normalizedRoute.map {
                CGPoint(
                    x: $0.x * size.width,
                    y: $0.y * size.height
                )
            }

            let visiblePoints = sampledRoutePoints(
                from: routePoints,
                progress: routeProgress,
                includePartialSegment: true
            )

            let visiblePath = Path { path in
                guard let first = visiblePoints.first else {
                    return
                }

                path.move(to: first)

                for point in visiblePoints.dropFirst() {
                    path.addLine(to: point)
                }
            }

            ZStack {
                Image("preview_map")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea()
                
                visiblePath
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )

                Canvas { context, canvasSize in
                    let cellWidth = canvasSize.width / CGFloat(gridColumns)
                    let cellHeight = canvasSize.height / CGFloat(gridRows)

                    for row in 0..<gridRows {
                        for column in 0..<gridColumns {
                            let rect = CGRect(
                                x: CGFloat(column) * cellWidth,
                                y: CGFloat(row) * cellHeight,
                                width: cellWidth,
                                height: cellHeight
                            )

                            let index = row * gridColumns + column

                            var path = Path()
                            path.addRect(rect)

                            let center = CGPoint(
                                x: rect.midX,
                                y: rect.midY
                            )

                            let expandedRect = rect.insetBy(dx: -8, dy: -8)

                            let isVisited = visiblePoints.contains {
                                expandedRect.contains($0)
                            }

                            let fillColor: Color

                            if isVisited {
                                fillColor = Color.orange.opacity(0.22)
                            } else {
                                fillColor = Color.white.opacity(0.025)
                            }

                            context.fill(path, with: .color(fillColor))

                            context.stroke(
                                path,
                                with: .color(
                                    isVisited
                                    ? Color.orange.opacity(0.7)
                                    : Color.white.opacity(0.08)
                                ),
                                lineWidth: 1
                            )

                            if isVisited, crownIndexes.contains(index) {
                                let trigger = crownProgress(for: index)

                                let scale = crownAnimatedScale(
                                    current: routeProgress,
                                    trigger: trigger
                                )
                                
                                let crownSize: CGFloat = 24 * scale

                                let crownRect = CGRect(
                                    x: center.x - crownSize / 2,
                                    y: center.y - crownSize / 2,
                                    width: crownSize,
                                    height: crownSize
                                )

                                let crownBackground = Path(
                                    ellipseIn: CGRect(
                                        x: center.x - 14,
                                        y: center.y - 14,
                                        width: 28,
                                        height: 28
                                    )
                                )

                                context.drawLayer { layerContext in
                                    layerContext.addFilter(
                                        .blur(radius: 6)
                                    )
                                    layerContext.fill(
                                        crownBackground,
                                        with: .color(
                                            Color.orange.opacity(0.35)
                                        )
                                    )
                                }

                                let crownText = Text(
                                    Image(systemName: "crown.fill")
                                )
                                    .font(.system(size: 16 * scale, weight: .bold))
                                    .foregroundColor(.orange)

                                context.draw(
                                    crownText,
                                    in: crownRect
                                )
                            }

                            if buffIndexes.contains(index) {
                                let tileRect = CGRect(
                                    x: center.x - 18,
                                    y: center.y - 18,
                                    width: 36,
                                    height: 36
                                )

                                let glowRect = CGRect(
                                    x: center.x - 16,
                                    y: center.y - 16,
                                    width: 32,
                                    height: 32
                                )

                                let glowPath = Path(ellipseIn: glowRect)

                                context.drawLayer { layerContext in
                                    layerContext.addFilter(
                                        .blur(radius: 10)
                                    )
                                    layerContext.fill(
                                        glowPath,
                                        with: .color(
                                            Color.gold.opacity(0.45)
                                        )
                                    )
                                }

                                if let assetType = buffAssetMap[index],
                                   let assetImage = UIImage(named: assetType.iconName) {
                                    context.draw(
                                        Image(uiImage: assetImage),
                                        in: CGRect(
                                            x: center.x - 12,
                                            y: center.y - 15,
                                            width: 24,
                                            height: 30
                                        )
                                    )
                                }

                                if let conditionName = buffConditionMap[index],
                                   let conditionImage = UIImage(named: conditionName ?? "") {
                                    context.draw(
                                        Image(uiImage: conditionImage),
                                        in: CGRect(
                                            x: center.x + 4,
                                            y: center.y - 18,
                                            width: 12,
                                            height: 12
                                        )
                                    )
                                }
                            }
                        }
                    }
                }

                if let currentPoint = visiblePoints.last {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 22, height: 22)
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 22, height: 22)
                    }
                    .position(currentPoint)
                }
            }
        }
    }


    private func sampledRoutePoints(
        from points: [CGPoint],
        progress: CGFloat,
        includePartialSegment: Bool
    ) -> [CGPoint] {
        guard points.count > 1 else {
            return []
        }
        let scaledProgress = progress * CGFloat(points.count - 1)
        let completedSegments = Int(floor(scaledProgress))
        let partialT = scaledProgress - CGFloat(completedSegments)
        var samples: [CGPoint] = []

        let segmentCount = min(
            completedSegments,
            points.count - 2
        )

        for index in 0...segmentCount {
            let current = points[index]
            let next = points[index + 1]

            let previous = index > 0
                ? points[index - 1]
                : current

            let nextNext = index < points.count - 2
                ? points[index + 2]
                : next

            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) * 0.18,
                y: current.y + (next.y - previous.y) * 0.18
            )

            let control2 = CGPoint(
                x: next.x - (nextNext.x - current.x) * 0.18,
                y: next.y - (nextNext.y - current.y) * 0.18
            )

            let sampleCount = 40

            let isPartialSegment =
                includePartialSegment
                && index == completedSegments
                && completedSegments < points.count - 1

            let upperBound: Int

            if isPartialSegment {
                upperBound = max(
                    Int(CGFloat(sampleCount) * partialT),
                    1
                )
            } else {
                upperBound = sampleCount
            }

            for sampleIndex in 0...upperBound {
                let t = CGFloat(sampleIndex) / CGFloat(sampleCount)
                let point = cubicBezierPoint(
                    t: t,
                    start: current,
                    control1: control1,
                    control2: control2,
                    end: next
                )
                samples.append(point)
            }

            if isPartialSegment {
                let exactPoint = cubicBezierPoint(
                    t: partialT,
                    start: current,
                    control1: control1,
                    control2: control2,
                    end: next
                )
                samples.append(exactPoint)
            }
        }
        return samples
    }

    private func cubicBezierPoint(
        t: CGFloat,
        start: CGPoint,
        control1: CGPoint,
        control2: CGPoint,
        end: CGPoint
    ) -> CGPoint {
        let mt = 1 - t
        let mt2 = mt * mt
        let t2 = t * t

        let a = mt2 * mt
        let b = 3 * mt2 * t
        let c = 3 * mt * t2
        let d = t * t2

        return CGPoint(
            x: (a * start.x)
                + (b * control1.x)
                + (c * control2.x)
                + (d * end.x),
            y: (a * start.y)
                + (b * control1.y)
                + (c * control2.y)
                + (d * end.y)
        )
    }

}

struct PreviewCardSelectedView: View {
    @State private var showCard2 = false
    @State private var showCard3 = false

    @State private var card2Scale: CGFloat = 1.5
    @State private var card3Scale: CGFloat = 1.5

    @State private var card2Opacity: Double = 0
    @State private var card3Opacity: Double = 0
    
    var body: some View {
        VStack {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.trailing, 20)
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        
                    }
                Spacer()
                Image("bike")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 20)
                Text("competition.register.single")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondText)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(Color.green.opacity(0.6))
                    .cornerRadius(6)
                Spacer()
                Button(action: {
                    
                }) {
                    Image("device_bind")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .padding(.vertical, 5)
                        .padding(.leading, 20)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        HStack(spacing: 4) {
                            Text("competition.cardselect.familiarity_buff")
                                .font(.headline)
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.thirdText)
                                .font(.subheadline)
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "competition.cardselect.familiarity_buff",
                                        message: "competition.cardselect.familiarity_buff.description",
                                        bottomButtons: [.confirm()]
                                    )
                                }
                        }
                        Spacer()
                        Text(String(format: "%.2f %%",0.63))
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    
                    HStack {
                        Text("competition.cardselect.sport_state_buff")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f %%", 0.25))
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    
                    VStack {
                        Text("competition.cardselect.choose")
                            .font(.system(size: 25))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        HStack {
                            Image("vip_icon_on")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 18)
                            Text("competition.cardselect.subscription")
                                .font(.subheadline)
                                .foregroundStyle(Color.secondText)
                        }
                        .padding(.vertical, 5)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.8))
                        .cornerRadius(10)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    VStack {
                        // 卡牌位
                        HStack(spacing: 20) {
                            //PreviewEmptyCardSlot()
                            Image("preview_card1")
                                .resizable()
                                .scaledToFit()
                                .scaleEffect(1.05)
                                .shadow(color: Color.gold.opacity(0.25), radius: 10)
                            ZStack {
                                PreviewEmptyCardSlot()
                                if showCard2 {
                                    Image("preview_card2")
                                        .resizable()
                                        .scaledToFit()
                                        .scaleEffect(card2Scale)
                                        .opacity(card2Opacity)
                                        .shadow(color: Color.gold.opacity(0.25), radius: 10)
                                }
                            }
                            ZStack {
                                PreviewEmptyCardSlot()
                                if showCard3 {
                                    Image("preview_card3")
                                        .resizable()
                                        .scaledToFit()
                                        .scaleEffect(card3Scale)
                                        .opacity(card3Opacity)
                                        .shadow(color: Color.gold.opacity(0.25), radius: 10)
                                }
                            }
                        }
                        .padding(.bottom)
                        
                        Text("competition.cardselect.action.choose")
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Color.defaultBackground)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.orange, lineWidth: 2)
                            )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.2))
                    )
                    
                    HStack(spacing: 4) {
                        Image("healthkit")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("competition.cardselect.healthkit.title")
                        Image(systemName: "info.circle")
                            .exclusiveTouchTapGesture {
                                
                            }
                        Spacer()
                    }
                    .foregroundStyle(Color.thirdText)
                    .font(.subheadline)
                    
                    Button(action: {
                        
                    }) {
                        HStack {
                            Text("competition.cardselect.action.next_step")
                            Image(systemName: "arrowshape.right")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            Capsule()
                                .fill(Color.orange)
                        )
                        .padding(.top, 50)
                    }
                }
                .padding()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                showCard2 = true

                withAnimation(.easeOut(duration: 0.18)) {
                    card2Opacity = 1
                    card2Scale = 1.5
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(
                        .spring(response: 0.28, dampingFraction: 0.62)
                    ) {
                        card2Scale = 0.95
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(
                            .spring(response: 0.22, dampingFraction: 0.72)
                        ) {
                            card2Scale = 1.05
                        }
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                showCard3 = true

                withAnimation(.easeOut(duration: 0.18)) {
                    card3Opacity = 1
                    card3Scale = 1.5
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(
                        .spring(response: 0.28, dampingFraction: 0.62)
                    ) {
                        card3Scale = 0.95
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(
                            .spring(response: 0.22, dampingFraction: 0.72)
                        ) {
                            card3Scale = 1.05
                        }
                    }
                }
            }
        }
        .background(Color.defaultBackground)
    }
}

struct PreviewEmptyCardSlot: View {
    let text: String
    let ratio: Double
    
    init(text: String = "competition.cardselect.magiccard.empty_slot", ratio: Double = 5/7) {
        self.text = text
        self.ratio = ratio
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let iconSize = width * 0.3
            let fontSize = width * 0.085
            
            ZStack {
                RoundedRectangle(cornerRadius: width * 0.08)
                    .fill(Color.gray.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: width * 0.08)
                            .stroke(Color.white.opacity(0.6), style: StrokeStyle(lineWidth: width * 0.015, dash: [width * 0.05]))
                    )
                
                VStack(spacing: width * 0.05) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: iconSize))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(LocalizedStringKey(text))
                        .font(.system(size: fontSize))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
        }
        .aspectRatio(ratio, contentMode: .fit)
    }
}

struct PreviewRankingListEntry: Identifiable, Equatable {
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
}

struct PreviewRankingListEntryView: View {
    let entry: PreviewRankingListEntry

    var body: some View {
        HStack(spacing: 10) {
            let NoSize: CGFloat = CGFloat(entry.rank < 4 ? 15 + (8 - 2 * entry.rank) : 15)
            let NoWeight: Font.Weight = entry.rank < 4 ? .bold : .medium
            let NoColor: Color = entry.rank < 4 ? (entry.rank == 1 ? Color.gold : (entry.rank == 2 ? Color.silver : Color.bronze)) : Color.white
            Text("#\(entry.rank)")
                .font(.system(size: NoSize, weight: NoWeight, design: .rounded))
                .foregroundStyle(NoColor)
            CachedAsyncImage(
                urlString: "",
                placeholder: Image(entry.avatarImageURL)
            )
            .aspectRatio(contentMode: .fill)
            .frame(width: 50, height: 50)
            .clipShape(Circle())
            .padding(.leading, 5)
            VStack(alignment: .leading) {
                Text(LocalizedStringKey(entry.nickname))
                    .font(.system(size: (entry.userID == "me" ? 20 : 16), weight: (entry.userID == "me" ? .bold : .medium)))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(TimeDisplay.formattedTime(entry.duration, showFraction: true))
                    .font(.system(size: (entry.userID == "me" ? 20 : 16), weight: (entry.userID == "me" ? .bold : .medium), design: .rounded))
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 30) {
                Text("\(entry.voucher)")
                    .foregroundStyle(Color.secondText)
                    .font(.system(size: (entry.userID == "me" ? 18 : 16), weight: (entry.userID == "me" ? .bold : .medium), design: .rounded))
                Text("\(entry.score)")
                    .foregroundStyle(Color.secondText)
                    .font(.system(size: (entry.userID == "me" ? 18 : 16), weight: (entry.userID == "me" ? .bold : .medium), design: .rounded))
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(10)
        .overlay {
            if entry.userID == "me" {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.orange, lineWidth: 1)
            }
        }
        .padding(.horizontal, 1)
    }
}

struct PreviewRankingListView: View {
    @State private var displayedEntries: [PreviewRankingListEntry] = []
    @State private var animatedUserScale: CGFloat = 1.0
    @State private var animatedUserShadow: CGFloat = 0

    let entries: [PreviewRankingListEntry] = [
        PreviewRankingListEntry(
            rank: 2,
            userID: "u1",
            nickname: "MountainFox",
            avatarImageURL: "Ads2",
            duration: 24.82,
            voucher: 118,
            score: 180,
            recordID: "r1"
        ),
        PreviewRankingListEntry(
            rank: 3,
            userID: "u2",
            nickname: "NightRider",
            avatarImageURL: "Ads3",
            duration: 25.16,
            voucher: 112,
            score: 172,
            recordID: "r2"
        ),
        PreviewRankingListEntry(
            rank: 4,
            userID: "u3",
            nickname: "SpeedWolf",
            avatarImageURL: "Ads",
            duration: 25.91,
            voucher: 108,
            score: 166,
            recordID: "r3"
        ),
        PreviewRankingListEntry(
            rank: 1,
            userID: "me",
            nickname: "common.me",
            avatarImageURL: "app_logo",
            duration: 21.48,
            voucher: 125,
            score: 200,
            recordID: "me"
        ),
        PreviewRankingListEntry(
            rank: 5,
            userID: "u4",
            nickname: "UrbanSprint",
            avatarImageURL: "preview_map",
            duration: 26.40,
            voucher: 101,
            score: 158,
            recordID: "r4"
        ),
        PreviewRankingListEntry(
            rank: 6,
            userID: "u5",
            nickname: "ClimbMaster",
            avatarImageURL: "coupon_background",
            duration: 27.02,
            voucher: 94,
            score: 151,
            recordID: "r5"
        )
    ]
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                Spacer()
                Text("competition.track.leaderboard")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            HStack {
                HStack(spacing: 4) {
                    Text(LocalizedStringKey(Gender.male.displayName))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white)
                    Image(systemName: "arrow.left.arrow.right")
                        .foregroundStyle(Color.secondText)
                        .font(.system(size: 10, weight: .light))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.defaultBackground)
                        .overlay(
                            Capsule()
                                .stroke(Color.orange, lineWidth: 1)
                        )
                )
                Spacer()
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
            }
            
            HStack(spacing: 30) {
                Text("competition.track.leaderboard.ranking")
                Text("competition.track.leaderboard.user_and_time")
                Spacer()
                Image("voucher")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Image("season_points")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
            }
            .font(.subheadline)
            .foregroundStyle(Color.secondText)
            .padding(.horizontal)
            
            // (user row is now part of the scrolling list)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    LazyVStack(spacing: 10) {
                        ForEach(displayedEntries) { entry in
                            PreviewRankingListEntryView(entry: entry)
                                .scaleEffect(
                                    entry.userID == "me"
                                    ? animatedUserScale
                                    : 1.0
                                )
                                .shadow(
                                    color: entry.userID == "me"
                                    ? Color.orange.opacity(0.35)
                                    : .clear,
                                    radius: animatedUserShadow
                                )
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.82),
                                    value: displayedEntries
                                )
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(.horizontal)
        .onAppear {
            displayedEntries = entries
            animatedUserScale = 1.0
            animatedUserShadow = 0

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {

                let moveDurations: [Double] = [0.0, 0.38, 0.76, 1.14]

                for index in 0..<4 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + moveDurations[index]) {

                        guard let currentIndex = displayedEntries.firstIndex(where: {
                            $0.userID == "me"
                        }), currentIndex > 0 else {
                            return
                        }

                        withAnimation(
                            .spring(response: 0.48, dampingFraction: 0.82)
                        ) {
                            displayedEntries.swapAt(currentIndex, currentIndex - 1)

                            animatedUserScale = 1.04
                            animatedUserShadow = 16
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            withAnimation(
                                .spring(response: 0.3, dampingFraction: 0.72)
                            ) {
                                animatedUserScale = 1.0
                            }
                        }
                    }
                }
            }
        }
        .background(Color.defaultBackground)
    }
}


// MARK: - 录屏预览：实时名次/PB + 跟随用户的赛道动画（全程代码控制，仅假数据视觉）

struct PreviewRealtimeRankView: View {
    @State private var sheetUp = false
    @State private var isRecording = false
    @State private var showPace = false
    @State private var playTrack = false
    @State private var startButtonScale: CGFloat = 1.0
    @State private var startButtonOpacity: Double = 1.0

    // 假统计
    @State private var elapsed: TimeInterval = 0
    @State private var distance = 0.0
    @State private var avgSpeed = 0.0
    @State private var heartRate = 120
    @State private var energy = 0
    @State private var power = 150
    @State private var cadence = 160

    // 名次 / PB（VIP 快照）
    private let paceRank = 12
    private let paceTotal = 120
    private let pbDeltaSeconds = 8.0

    private let track = PreviewRealtimeRankMapView.makeTrack()
    @State private var statsTimer: Timer?

    private let columns: [GridItem] = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    private var items: [(String, String, String, Color)] {
        [
            ("competition.realtime.distance", String(format: "%.2f ", distance), "distance.km", .orange),
            ("competition.realtime.avgspeed", String(format: "%.1f ", avgSpeed), "speed.km/h", .yellow),
            ("competition.realtime.heartrate", "\(heartRate) ", "heartrate.unit", .red),
            ("competition.realtime.energy", "\(energy) ", "energy.unit", .blue),
            ("competition.realtime.power", "\(power) ", "power.unit", .green),
            ("competition.result.stepcadence", "\(cadence) ", "stepCadence.unit", .pink),
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            PreviewRealtimeRankMapView(track: track, duration: 4.2, play: playTrack)
                .ignoresSafeArea()

            sheet.offset(y: sheetUp ? 0 : 470)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear { runSequence() }
        .onDisappear { statsTimer?.invalidate() }
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                VStack {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.clear, lineWidth: 2)
                            )
                        Image("location")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(Color.clear, lineWidth: 2)
                            )
                        Image("location2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                }
            }
            .padding()
            ZStack {
                HStack {
                    Image("bike")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .padding(6)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    Spacer()
                    Image("route_training")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .padding(6)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                HStack(alignment: .top, spacing: 5) {
                    Text("GPS")
                        .foregroundStyle(Color.white)
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<4) { index in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(width: 6, height: CGFloat(6 + index * 4))
                        }
                    }
                }
                .padding(6)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            VStack(spacing: 0) {
                Image(systemName: "chevron.down").foregroundStyle(.white).bold().padding(.vertical, 10)
                ZStack {
                    ProgressBar(progress: Double(2) / Double(5))
                        .frame(height: 20)
                    Text("checked \(2) / \(5)")
                        .foregroundStyle(Color.white)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
                ScrollView {
                    VStack(spacing: 20) {
                        // 时间行 / start 按钮
                        if isRecording {
                            HStack(spacing: 20) {
                                Spacer()
                                Text(TimeDisplay.formattedTime(elapsed))
                                    .contentTransition(.numericText())
                                    .font(.system(size: 35, weight: .heavy, design: .rounded))
                                Spacer()
                                Text("training.realtime.action.finish")
                                    .font(.system(size: 18)).padding(.vertical, 12).padding(.horizontal, 20)
                                    .lineLimit(1).minimumScaleFactor(0.7).background(Color.red).clipShape(Capsule())
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                        } else {
                            Spacer()
                            Text("competition.realtime.action.start")
                                .font(.system(size: 30)).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 100).background(Color.green).clipShape(Circle())
                                .scaleEffect(startButtonScale).opacity(startButtonOpacity)
                                .padding(.vertical, 6)
                            Spacer()
                        }
                        
                        HStack(spacing: 16) {
                            VStack(spacing: 4) {
                                Text("competition.realtime.card.time")
                                    .font(.headline)
                                Text("- \(15)s")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Color.green.opacity(0.8))
                            .clipShape(Capsule())
                            
                            VStack(spacing: 4) {
                                Text("training.route.create.penalty_time")
                                    .font(.headline)
                                Text("+ 7s")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 20)
                        
                        // 名次 + PB：从中间弹出，挤开上下视图
                        if showPace {
                            VStack(spacing: 12) {
                                paceCapsule("realtime.pace.predicted_rank") {
                                    Text("# \(paceRank) / \(paceTotal)")
                                }
                                paceCapsule("realtime.pace.vs_pb") {
                                    HStack(spacing: 4) {
                                        Image(systemName: pbDeltaSeconds >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(pbDeltaSeconds >= 0 ? Color.green : Color.red)
                                        Text(TimeDisplay.formattedTime(abs(pbDeltaSeconds)))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.55, anchor: .center).combined(with: .opacity),
                                removal: .opacity))
                        }
                        
                        if isRecording {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(items, id: \.0) { title, value, unit, color in
                                    VStack {
                                        Text(LocalizedStringKey(title)).font(.headline)
                                        (Text(value) + Text(LocalizedStringKey(unit)))
                                            .font(.title3).fontWeight(.semibold)
                                            .contentTransition(.numericText())
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, minHeight: 80)
                                    .background(color.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 10))
                                    .geometryGroupCompat()   // 让 Text 随卡片整体位移，消除 contentTransition 滞留
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 30)
                }
                .frame(height: 420)
            }
            .frame(maxWidth: .infinity)
            .background(Color.defaultBackground.opacity(0.92))
            .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
        }
    }

    private func paceCapsule(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            value().font(.title3).fontWeight(.semibold)
        }
        .padding()
        .foregroundStyle(Color.white)
        .background(Capsule().fill(Color.white.opacity(0.2)).overlay(Capsule().stroke(Color.orange, lineWidth: 1)))
    }

    // 序列编排（全代码控制）
    private func runSequence() {
        statsTimer?.invalidate()
        sheetUp = false; isRecording = false; showPace = false; playTrack = false
        startButtonScale = 1; startButtonOpacity = 1
        elapsed = 0; distance = 0; energy = 0
        Task { @MainActor in
            // 1) 弹出 sheet（含 start 按钮）
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { sheetUp = true }
            try? await Task.sleep(nanoseconds: 900_000_000)
            // 2) 按下 start → 正常时间 + finish + 统计
            withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                startButtonScale = 0.2; startButtonOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
            //withAnimation(.easeInOut(duration: 0.35)) { isRecording = true }
            isRecording = true
            startStats()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            // 3) 名次 / PB 从中间弹出，挤开上下
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { showPace = true }
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            // 4) 收起 sheet + 赛道动画（统计继续，不停）
            //withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { sheetUp = false }
            try? await Task.sleep(nanoseconds: 300_000_000)
            //playTrack = true
            statsTimer?.invalidate()
            statsTimer = nil
        }
    }

    private func startStats() {
        statsTimer?.invalidate()
        statsTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                elapsed += Double.random(in: 9...15)
                distance += Double.random(in: 0.05...0.2)
                avgSpeed = Double.random(in: 22...30)
                heartRate = Int.random(in: 120...165)
                energy += Int.random(in: 2...6)
                power = Int.random(in: 130...180)
                cadence = Int.random(in: 150...170)
            }
        }
    }
}

// 跟随用户的赛道地图：真实 Map 背景 + 灰/橙轨迹 + 用户/PB 两点。
// 60fps 动画整个放在 Coordinator 的 CADisplayLink 里（全程 UIKit，不触发 SwiftUI 重绘）→ 丝滑。
struct PreviewRealtimeRankMapView: UIViewRepresentable {
    let track: [CLLocationCoordinate2D]
    let duration: Double
    let play: Bool

    // 预设赛道：东京·上野一带的控制点 → Catmull-Rom 平滑曲线（~400m，较短，移动更慢）
    static func makeTrack() -> [CLLocationCoordinate2D] {
        let waypoints: [CLLocationCoordinate2D] = [
            .init(latitude: 33.5713, longitude: 131.1267),
            .init(latitude: 35.7128, longitude: 139.7764),
            .init(latitude: 35.7124, longitude: 139.7780),
            .init(latitude: 35.7134, longitude: 139.7792),
            .init(latitude: 35.7146, longitude: 139.7798),
            .init(latitude: 35.7152, longitude: 139.7786),
            .init(latitude: 35.7156, longitude: 139.7772),
        ]
        return catmullRom(waypoints, samplesPerSegment: 28)
    }

    static func catmullRom(_ pts: [CLLocationCoordinate2D], samplesPerSegment: Int) -> [CLLocationCoordinate2D] {
        guard pts.count >= 2 else { return pts }
        var result: [CLLocationCoordinate2D] = []
        let n = pts.count
        for i in 0..<(n - 1) {
            let p0 = pts[max(i - 1, 0)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[min(i + 2, n - 1)]
            for s in 0..<samplesPerSegment {
                let t = Double(s) / Double(samplesPerSegment)
                let t2 = t * t, t3 = t2 * t
                func interp(_ a: Double, _ b: Double, _ c: Double, _ d: Double) -> Double {
                    0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
                }
                result.append(.init(latitude: interp(p0.latitude, p1.latitude, p2.latitude, p3.latitude),
                                    longitude: interp(p0.longitude, p1.longitude, p2.longitude, p3.longitude)))
            }
        }
        result.append(pts[n - 1])
        return result
    }

    func makeCoordinator() -> Coordinator { Coordinator(track: track, duration: duration) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.showsUserLocation = false
        map.showsCompass = false
        map.mapType = .mutedStandard
        map.pointOfInterestFilter = .excludingAll
        context.coordinator.attach(map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        if play {
            context.coordinator.start()
        } else {
            context.coordinator.render(0)   // 未播放时显示静态起始帧（待布局后即正确）
        }
    }

    final class Coordinator: NSObject {
        private let track: [CLLocationCoordinate2D]
        private let duration: Double
        private weak var map: MKMapView?
        private var overlay: UIView?
        private let grayLayer = CAShapeLayer()
        private let orangeLayer = CAShapeLayer()
        private let userDot = CALayer()
        private let pbDot = CALayer()
        private let pbBadge = UILabel()
        private var link: CADisplayLink?
        private var startTime: CFTimeInterval = 0
        private var started = false

        init(track: [CLLocationCoordinate2D], duration: Double) {
            self.track = track
            self.duration = duration
            super.init()
        }
        
        func attach(_ map: MKMapView) {
            self.map = map
            let ov = UIView(frame: map.bounds)
            ov.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            ov.isUserInteractionEnabled = false
            ov.backgroundColor = .clear
            for (layer, color): (CAShapeLayer, UIColor) in
                [(grayLayer, UIColor.lightGray.withAlphaComponent(0.75)), (orangeLayer, .orange)] {
                layer.fillColor = UIColor.clear.cgColor
                layer.strokeColor = color.cgColor
                layer.lineWidth = 6
                layer.lineCap = .round
                layer.lineJoin = .round
                ov.layer.addSublayer(layer)
            }
            Self.configureDot(pbDot, color: .systemGreen, diameter: 22)
            Self.configureDot(userDot, color: .orange, diameter: 25)
            Self.configurePBBadge(pbBadge)
            ov.addSubview(pbBadge)
            ov.layer.addSublayer(pbDot)
            ov.layer.addSublayer(userDot)
            //map.addSubview(ov)
            overlay = ov

            map.setCamera(MKMapCamera(lookingAtCenter: interpolate(0), fromDistance: 600, pitch: 0, heading: 0),
                          animated: false)
            DispatchQueue.main.async {
                self.render(0)
            }
        }

        private static func configureDot(_ dot: CALayer, color: UIColor, diameter: CGFloat) {
            dot.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            dot.cornerRadius = diameter / 2
            dot.backgroundColor = color.cgColor
            dot.borderColor = UIColor.white.cgColor
            dot.borderWidth = 2
        }

        private static func configurePBBadge(_ label: UILabel) {
            label.text = "PB"
            label.textAlignment = .center
            label.font = .boldSystemFont(ofSize: 12)
            label.textColor = .white
            label.backgroundColor = .systemGreen
            label.layer.cornerRadius = 8
            label.layer.masksToBounds = true
            label.frame = CGRect(x: 0, y: 0, width: 34, height: 20)
        }

        func start() {
            guard !started else { return }
            started = true
            startTime = CACurrentMediaTime()
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: .main, forMode: .common)
            link = l
        }

        @objc private func tick() {
            let u = min((CACurrentMediaTime() - startTime) / duration, 1.0)
            render(u)
            if u >= 1.0 { link?.invalidate(); link = nil }
        }

        // 在屏幕坐标里画轨迹+两点（地图仅平移当背景）：无 overlay 分块重绘的闪烁，点与平移完全同步
        func render(_ u: Double) {
            guard let map, let ov = overlay, track.count > 1 else { return }
            let userT = Self.smoothstep(u)
            // PB 领先量：两端为 0（同起同终），中段钟形包络内来回交错
            let gap = 0.08 * sin(.pi * userT) * sin(2 * .pi * 2.0 * userT)
            let pbT = min(max(userT + gap, 0), 1)
            let userCoord = interpolate(userT)
            let offsetCenter = CLLocationCoordinate2D(
                latitude: userCoord.latitude - 0.0003,
                longitude: userCoord.longitude
            )
            map.setCenter(offsetCenter, animated: false)

            let pts = track.map { map.convert($0, toPointTo: ov) }

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            let gp = CGMutablePath(); gp.addLines(between: pts)
            grayLayer.path = gp

            let n = track.count - 1
            let pos = min(max(userT, 0), 1) * Double(n)
            let i = Int(floor(pos))
            var op = Array(pts[0...min(i, pts.count - 1)])
            if i < n {
                let f = pos - Double(i), a = pts[i], b = pts[i + 1]
                op.append(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
            }
            let opath = CGMutablePath()
            if op.count >= 2 { opath.addLines(between: op) }
            orangeLayer.path = opath

            userDot.position = map.convert(userCoord, toPointTo: ov)

            let pbPosition = map.convert(interpolate(pbT), toPointTo: ov)
            pbDot.position = pbPosition
            pbBadge.center = CGPoint(
                x: pbPosition.x,
                y: pbPosition.y - 32
            )

            CATransaction.commit()
        }

        private func interpolate(_ t: Double) -> CLLocationCoordinate2D {
            guard track.count > 1 else { return track.first ?? CLLocationCoordinate2D() }
            let pos = min(max(t, 0), 1) * Double(track.count - 1)
            let i = Int(floor(pos))
            if i >= track.count - 1 { return track[track.count - 1] }
            let f = pos - Double(i)
            let a = track[i], b = track[i + 1]
            return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * f,
                                          longitude: a.longitude + (b.longitude - a.longitude) * f)
        }

        private static func smoothstep(_ x: Double) -> Double {
            let c = min(max(x, 0), 1); return c * c * (3 - 2 * c)
        }
    }
}

private extension View {
    // geometryGroup 仅 iOS 17+；这里做个降级兜底（iOS 16 上为 no-op）
    @ViewBuilder
    func geometryGroupCompat() -> some View {
        if #available(iOS 17.0, *) {
            self.geometryGroup()
        } else {
            self
        }
    }
}

#Preview() {
    PreviewRealtimeRankView()
}
