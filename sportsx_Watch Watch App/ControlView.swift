//
//  ControlView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI

struct ControlView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("点击结束并不会结束比赛，只会停止watch端的数据收集，想要结束比赛请在手机端操作")
            Button(action:{
                workoutManager.stopCollecting()
            }) {
                Text("结束")
                    .foregroundStyle(Color.red)
            }
        }
        .padding()
    }
}
