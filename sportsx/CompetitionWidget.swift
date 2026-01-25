//
//  CompetitionWidget.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/16.
//

import SwiftUI
import Combine

struct CompetitionWidget: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var dataFusionManager = DataFusionManager.shared
    // 拖拽状态
    @State private var dragOffset: CGSize = .zero
    @State private var lastPosition: CGSize = CGSize(width: .zero, height: -150)
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    @State private var screenHeight: CGFloat = UIScreen.main.bounds.height
    
    var body: some View {
        if appState.competitionManager.isShowWidget {
            GeometryReader { geo in
                ZStack {
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 70, height: 70)
                        Spacer()
                        VStack {
                            Text(TimeDisplay.formattedTime(dataFusionManager.elapsedTime, part: .hour))
                            Text(TimeDisplay.formattedTime(dataFusionManager.elapsedTime, part: .minute))
                            Text(TimeDisplay.formattedTime(dataFusionManager.elapsedTime, part: .second))
                        }
                        .foregroundStyle(Color.white)
                        .padding(10)
                    }
                    .offset(x: -35)
                    .opacity(dragOffset == .zero ? ((lastPosition.width > -geo.size.width / 2 + 70) ? 0 : 1) : 0)
                    ZStack(alignment: .trailing) {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(width: 70, height: 70)
                        Spacer()
                        VStack {
                            Text(TimeDisplay.formattedTime(dataFusionManager.elapsedTime, part: .hour))
                            Text(TimeDisplay.formattedTime(dataFusionManager.elapsedTime, part: .minute))
                            Text(TimeDisplay.formattedTime(dataFusionManager.elapsedTime, part: .second))
                        }
                        .foregroundStyle(Color.white)
                        .padding(10)
                    }
                    .offset(x: 35)
                    .opacity(dragOffset == .zero ? ((lastPosition.width > -geo.size.width / 2 + 70) ? 1 : 0) : 0)
                    
                    // 外圈
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 70, height: 70)
                    
                    // 内圈
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(appState.competitionManager.sport.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 30)
                        )
                }
                .position(
                    x: geo.size.width - 70 + dragOffset.width + lastPosition.width,
                    y: geo.size.height + dragOffset.height + lastPosition.height
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            withAnimation(.easeIn(duration: 0.2)) {
                                let totalOffsetX = value.translation.width + lastPosition.width
                                let totalOffsetY = value.translation.height + lastPosition.height
                                
                                // 计算松手后吸附到左右边缘
                                let targetX: CGFloat = (totalOffsetX > -geo.size.width / 2 + 70) ? 0 : -geo.size.width + 140
                                // 限制上下边界
                                let clampedY = min(max(totalOffsetY, -geo.size.height + 35), geo.safeAreaInsets.bottom - 145)
                                
                                lastPosition = CGSize(width: targetX, height: clampedY)
                                dragOffset = .zero
                            }
                        }
                )
                .onTapGesture {
                    appState.navigationManager.append(.competitionRealtimeView)
                }
            }
        }
    }
}

#Preview{
    let appState = AppState.shared
    CompetitionWidget()
        .environmentObject(appState)
}
