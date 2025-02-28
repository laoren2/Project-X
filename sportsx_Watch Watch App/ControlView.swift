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
            Text("ControlView")
        }
        .padding()
    }
}
