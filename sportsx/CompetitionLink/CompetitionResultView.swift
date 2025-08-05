//
//  CompetitionResultView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI

struct CompetitionResultView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    adjustNavigationPath()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("result")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            Text("比赛结果结算页面")
                .font(.largeTitle)
                .foregroundStyle(.white)
            Spacer()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture() {
            adjustNavigationPath()
        }
    }
    
    private func adjustNavigationPath() {
        var cardSelectViewIndex = 1
        var realtimeViewIndex = 1
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
            cardSelectViewIndex = appState.navigationManager.path.count - index
        }
        if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionRealtimeView" }) {
            realtimeViewIndex = appState.navigationManager.path.count - index
        }
        let lastToRemove = max(1, cardSelectViewIndex, realtimeViewIndex)
        appState.navigationManager.removeLast(lastToRemove)
    }
}
