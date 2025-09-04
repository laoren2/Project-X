//
//  SessionPageView.swift
//  sportsx
//
//  Created by 任杰 on 2025/2/18.
//

import SwiftUI



struct SessionPageView: View {
    @State private var selection = 0
    @EnvironmentObject var workoutManager: WatchDataManager
    @Environment(\.isLuminanceReduced) var isLuminanceReduced
    
    var body: some View {
        TabView(selection: $selection) {
            ControlView().tag(0)
            MetricsView().tag(1)
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: workoutManager.running) {
            displayMetricsView()
        }
        .tabViewStyle(
            PageTabViewStyle(indexDisplayMode: isLuminanceReduced ? .never : .automatic)
        )
        .onChange(of: isLuminanceReduced) {
            displayMetricsView()
        }
    }
    
    private func displayMetricsView() {
        withAnimation {
            selection = 1
        }
    }
}
