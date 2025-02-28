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
            Text("Hello, world!")
        }
        .padding()
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

#Preview {
    StartView()
}
