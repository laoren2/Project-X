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
        VStack(spacing: 10) {
            if workoutManager.workoutMode != .freeTraining {
                Text("competition.applewatch.control.info")
                    .minimumScaleFactor(0.6)
                    .allowsTightening(true)
                    .font(.subheadline)
                //.fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            HStack {
                Spacer()
                // 暂停 / 继续按钮（仅 free training）
                if workoutManager.workoutMode == .freeTraining {
                    Button(action: {
                        if workoutManager.isPaused {
                            workoutManager.requestResume()
                        } else {
                            workoutManager.requestPause()
                        }
                    }) {
                        Image(systemName: workoutManager.isPaused ? "arrowtriangle.right.fill" : "pause.fill")
                            .font(.system(size: 24))
                            .frame(width: 50, height: 50)
                            .foregroundStyle(workoutManager.isPaused ? Color.green : Color.orange)
                            .background(Color.white.opacity(0.3))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                // 结束按钮
                Button(action:{
                    workoutManager.requestStop()
                }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 24))
                        .frame(width: 50, height: 50)
                        .foregroundStyle(Color.red)
                        .background(Color.white.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Spacer()
            }
            //.padding(.top, 20)
        }
        .padding()
        //.border(.red)
    }
}

#Preview {
    let workout = WatchDataManager.shared
    return ControlView()
        .environmentObject(workout)
}
