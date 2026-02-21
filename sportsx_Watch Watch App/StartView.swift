//
//  StartView.swift
//  sportsx_Watch Watch App
//
//  Created by 任杰 on 2025/1/6.
//

import SwiftUI

struct StartView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    @State var toast: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Image("single_app_icon")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 50)
                .foregroundStyle(Color.orange)
            if !toast.isEmpty {
                Text(LocalizedStringKey(toast))
                    .font(.caption)
                    .foregroundStyle(Color.red.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action:{
                let syncStatus = workoutManager.syncStatus()
                if !syncStatus.result {
                    toast = syncStatus.msg
                }
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
