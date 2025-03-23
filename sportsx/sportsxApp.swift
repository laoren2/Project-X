//
//  sportsxApp.swift
//  sportsx
//
//  Created by 任杰 on 2024/7/17.
//
import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    @Published var sport: SportName = .Bike // 默认运动
    @Published var competitionManager = CompetitionManager.shared // 管理比赛进程
    @Published var navigationManager = NavigationManager.shared // 管理一级导航
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 当 competitionManager 有变化时，让 AppState 也发出变化通知
        competitionManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
        
        navigationManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        .store(in: &cancellables)
    }
}

class AppStateTest: ObservableObject {
    @Published var testbool: Bool = false
    @Published var showWidget: Bool = false
}



@main
struct sportsxApp: App {
    @StateObject var appState = AppState()
    //@StateObject var appStateTest = AppStateTest()
    //@StateObject private var navigationManager = NManager()
    //@StateObject var nm = NManager()
    
    var body: some Scene {
        WindowGroup {
            NaviView()
                .environmentObject(appState)
            //test()
            //    .environmentObject(nm)
            //CompetitionView()
        }
    }
}




