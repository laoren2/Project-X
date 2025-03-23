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
                    appState.navigationManager.path.removeLast()
                    appState.competitionManager.addCompetitionRecord()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .light))
                    Text("返回")
                }
                .padding(.leading, 18)
                
                Spacer()
            }
            Spacer()
            
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
                    .cornerRadius(15)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }
            .padding()
            .sheet(isPresented: $showCardSelection) {
                CardSelectionView()
            }
            .disabled(appState.competitionManager.isRecording)
            
            Button(action: {
                appState.navigationManager.path.append("competitionRealtimeView")
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
                    .cornerRadius(20)
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
        }
        .navigationBarHidden(true)
    }
}



#Preview {
    let appState = AppState()
    return CompetitionCardSelectView()
        .environmentObject(appState)
}
