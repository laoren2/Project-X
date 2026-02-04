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
            Text("competition.applewatch.control.info")
                .minimumScaleFactor(0.6)
                .allowsTightening(true)
                .font(.subheadline)
                //.fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action:{
                workoutManager.stopCollecting()
            }) {
                Text("competition.realtime.action.finish.2")
                    .foregroundStyle(Color.red)
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
