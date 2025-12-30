//
//  StartView.swift
//  sportsx_Watch Watch App
//
//  Created by 任杰 on 2025/1/6.
//

import SwiftUI

struct StartView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image("single_app_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 50)
                .foregroundStyle(Color.orange)
            Button(action:{
                workoutManager.syncStatus()
            }){
                Text("competition.applewatch.sync")
                    .foregroundStyle(Color.green)
            }
        }
        //.onAppear {
        //    workoutManager.requestAuthorization()
        //}
    }
}

#Preview {
    let obj = WatchDataManager.shared
    return StartView()
        .environmentObject(obj)
}
