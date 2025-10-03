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
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Button(action:{
                workoutManager.syncStatus()
            }){
                Text("同步")
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
