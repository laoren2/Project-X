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
            Text("比赛结果结算页面")
                .font(.largeTitle)
        }
        .navigationBarBackButtonHidden(true)  // 隐藏默认返回按钮
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: adjustNavigationPath) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                }
            }
        }
    }
    
    private func adjustNavigationPath() {
        let cardSelectViewIndex = appState.navigationManager.findIndex(des: "competitionCardSelectView")
        let realtimeViewIndex = appState.navigationManager.findIndex(des: "competitionRealtimeView")
        let lastToRemove = max(1, cardSelectViewIndex, realtimeViewIndex)
        appState.navigationManager.path.removeLast(lastToRemove)
    }
}
