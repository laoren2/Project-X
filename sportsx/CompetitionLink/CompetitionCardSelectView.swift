//
//  CompetitionCardSelectView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI


struct CompetitionCardSelectView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var cardManager = MagicCardManager.shared
    @State private var showCardSelection = false
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 140
    private let maxCards = 3
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    // 销毁计时器a和b
                    appState.competitionManager.stopAllTeamJoinTimers()
                    appState.navigationManager.removeLast()
                    appState.competitionManager.resetCompetitionProperties()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .light))
                    Text("返回")
                }
                .padding(.leading, 18)
                
                Spacer()
            }
            
            Spacer()
            
            // 组队模式显示区域
            if let isTeamCompetition = appState.competitionManager.currentCompetitionRecord?.isTeamCompetition, isTeamCompetition {
                VStack {
                    if appState.competitionManager.isTeamJoinWindowExpired {
                        Text("队伍有效窗口时间已过，无法加入比赛")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Text("剩余加入时间: \(appState.competitionManager.teamJoinRemainingTime)秒")
                            .font(.headline)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
                
                Spacer()
            }
            
            Text("我的卡牌阵容")
                .font(.headline)
                .padding(.bottom, 5)
            
            // 固定的三个卡牌位
            HStack(spacing: 20) {
                ForEach(0..<maxCards, id: \.self) { index in
                    if index < appState.competitionManager.selectedCards.count {
                        // 显示已选择的卡牌
                        CardView(card: appState.competitionManager.selectedCards[index])
                            .frame(width: cardWidth, height: cardHeight)
                    } else {
                        // 显示占位卡牌
                        EmptyCardSlot()
                            .frame(width: cardWidth, height: cardHeight)
                    }
                }
            }
            .padding(.bottom, 30)
            
            Button(action: {
                showCardSelection = true
            }) {
                Text("选择卡片")
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding()
            .sheet(isPresented: $showCardSelection) {
                CardSelectionView()
            }
            .disabled(appState.competitionManager.isRecording)
            
            Button(action: {
                appState.navigationManager.append(.competitionRealtimeView)
            }) {
                Text("我准备好了")
                    .frame(minWidth: 180)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.7)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding(.top, 10)
            .disabled(appState.competitionManager.isRecording)
            
            Spacer()
        }
        .background(
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
        )
        .onAppear {
            if cardManager.availableCards.isEmpty {
                cardManager.fetchUserCards()
            }
            // 如果是组队模式，启动计时器a
            if let isTeamCompetition = appState.competitionManager.currentCompetitionRecord?.isTeamCompetition, isTeamCompetition {
                appState.competitionManager.startTeamJoinTimerA()
            }
        }
        .navigationBarHidden(true)
    }
}



#Preview {
    let appState = AppState.shared
    return CompetitionCardSelectView()
        .environmentObject(appState)
}
