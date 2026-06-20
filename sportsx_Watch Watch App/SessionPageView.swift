//
//  SessionPageView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI



struct SessionPageView: View {
    @State private var selection = 0
    @EnvironmentObject var workoutManager: WatchDataManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    var body: some View {
        TabView(selection: $selection) {
            ControlView().tag(0)
            MetricsView().tag(1)
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: workoutManager.isRecording) {
            displayMetricsView()
        }
        .tabViewStyle(
            PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic)
        )
        .onChange(of: isLuminanceReduced) {
            // 仅在熄屏(进入 AOD)时回到指标页；亮屏交互时保留用户当前页，
            // 避免每次亮屏都被强制切页。
            if isLuminanceReduced {
                displayMetricsView()
            }
        }
    }

    private func displayMetricsView() {
        // 不加 withAnimation：熄屏/亮屏切换本身已有系统级转场，
        // 再叠一层 SwiftUI 翻页动画会造成可见卡顿。
        selection = 1
    }
}
