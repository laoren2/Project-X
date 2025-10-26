//
//  CompetitionCardSelectView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI


struct CompetitionCardSelectView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @State private var showCardSelection = false
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 140
    private let maxCards = 3
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    // 销毁计时器a和b
                    appState.competitionManager.stopAllTeamJoinTimers()
                    appState.navigationManager.removeLast()
                    if !appState.competitionManager.isRecording {
                        appState.competitionManager.resetCompetitionProperties()
                    }
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                Spacer()
                Text("cardselect")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // 组队模式显示区域
            if appState.competitionManager.isTeam {
                VStack {
                    if appState.competitionManager.isTeamJoinWindowExpired {
                        Text("队伍有效窗口时间已过，无法加入比赛")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        Text("剩余加入时间: \(appState.competitionManager.teamJoinRemainingTime)秒")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding()
                    }
                }
                .padding(.bottom, 20)
                
                Spacer()
            }
            
            Text("我的卡牌阵容")
                .font(.headline)
                .padding(.bottom, 5)
                .foregroundStyle(.white)
            
            // 固定的三个卡牌位
            HStack(spacing: 20) {
                ForEach(appState.competitionManager.selectedCards) { card in
                    MagicCardView(card: card)
                        .frame(width: cardWidth, height: cardHeight)
                }
                ForEach(appState.competitionManager.selectedCards.count..<maxCards, id: \.self) {_ in
                    EmptyCardSlot()
                        .frame(width: cardWidth, height: cardHeight)
                }
            }
            .padding(.bottom, 30)
            
            Text("选择卡片")
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .foregroundColor(.white)
                .background(Color.blue)
                .cornerRadius(12)
                .exclusiveTouchTapGesture {
                    showCardSelection = true
                }
                .disabled(appState.competitionManager.isRecording)
            
            Text("我准备好了")
                .frame(minWidth: 180)
                .padding(.vertical, 15)
                .background(Color.green)
                .cornerRadius(12)
                .foregroundColor(.white)
                .padding(.top, 10)
                .exclusiveTouchTapGesture {
                    appState.navigationManager.append(.competitionRealtimeView)
                }
                .disabled(appState.competitionManager.isRecording)
            
            Spacer()
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        //.enableBackGesture() {
            // 销毁计时器a和b
        //    appState.competitionManager.stopAllTeamJoinTimers()
        //    appState.navigationManager.removeLast()
        //    if !appState.competitionManager.isRecording {
        //        appState.competitionManager.resetCompetitionProperties()
        //    }
        //}
        .enableSwipeBackGesture(false)
        .onFirstAppear {
            //if assetManager.magicCards.isEmpty {
            //    assetManager.queryMagicCards(withLoadingToast: false)
            //}
            // 如果是组队模式，启动计时器a
            if appState.competitionManager.isTeam {
                appState.competitionManager.startTeamJoinTimerA()
            }
        }
        .bottomSheet(isPresented: $showCardSelection, size: .large) {
            CardSelectionView(showCardSelection: $showCardSelection)
        }
    }
}



/*#Preview {
    let appState = AppState.shared
    let card = MagicCard(cardID: "qwe", name: "踏频仙人", sportType: .Bike, level: 5, levelSkill1: 2, levelSkill2: 3, levelSkill3: nil, imageURL: "Ads", sensorType: .heartSensor, sensorLocation: 7, lucky: 67.3, rarity: "A", description: "这是一段描述", descriptionSkill1: "技能1的描述", descriptionSkill2: "技能2的描述", descriptionSkill3: nil, version: AppVersion("1.0.0"), tags: ["team"], effectDef: MagicCardDef(cardID: "qwe", typeName: "pedal", params: .string("")))
    AssetManager.shared.magicCards.append(card)
    return CompetitionCardSelectView()
        .environmentObject(appState)
}*/
