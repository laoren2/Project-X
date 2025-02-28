//
//  NaviView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI

struct NaviView: View {
    @EnvironmentObject var workoutManager: WatchDataManager
    
    var body: some View {
        if workoutManager.running {
            SessionPageView()
        } else {
            StartView()
        }
    }
}

