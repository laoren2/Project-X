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
    @ObservedObject var userManager = UserManager.shared
    @State private var showCardSelection = false
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    //private let cardHeight: CGFloat = 140
    private var maxCards: Int { return userManager.user.isVip ? 4 : 3}
    
    var body: some View {
        VStack {
            HStack(spacing: 4) {
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
                Image(systemName: appState.competitionManager.sport.iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.white)
                Text(appState.competitionManager.isTeam ? "组队" : "单人")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondText)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(appState.competitionManager.isTeam ? Color.orange.opacity(0.6) : Color.green.opacity(0.6))
                    .cornerRadius(6)
                Spacer()
                // 平衡布局的空按钮
                Button(action: {
                    appState.navigationManager.append(.sensorBindView)
                }) {
                    Image(systemName: "applewatch.side.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            
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
                .frame(height: 150)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .frame(height: 150)
            }
            
            HStack {
                if userManager.user.isVip {
                    Spacer()
                }
                Text("请选择你的装备卡")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                if !userManager.user.isVip {
                    HStack {
                        Image(systemName: "v.circle.fill")
                            .font(.system(size: 15))
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.red)
                        Text("订阅获得额外卡牌槽")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondText)
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0.8))
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 10)
            
            VStack {
                // 卡牌位
                if userManager.user.isVip {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(appState.competitionManager.selectedCards) { card in
                                MagicCardView(card: card)
                                    .frame(width: cardWidth)
                            }
                            ForEach(appState.competitionManager.selectedCards.count..<maxCards, id: \.self) { index in
                                if index == 3 {
                                    EmptyCardVipSlot()
                                        .frame(width: cardWidth)
                                } else {
                                    EmptyCardSlot()
                                        .frame(width: cardWidth)
                                }
                            }
                        }
                        .padding(2)
                    }
                    .padding(.bottom)
                } else {
                    HStack {
                        let selected = appState.competitionManager.selectedCards
                        let placeholders = Array(selected.count..<maxCards)
                        let allViews: [AnyView] = selected.map { card in
                            AnyView(
                                MagicCardView(card: card)
                                    .frame(width: cardWidth)
                            )
                        } + placeholders.map { _ in
                            AnyView(
                                EmptyCardSlot()
                                    .frame(width: cardWidth)
                            )
                        }
                        
                        ForEach(0..<allViews.count, id: \.self) { i in
                            allViews[i]
                            if i < allViews.count - 1 {
                                Spacer()
                            }
                        }
                    }
                    .padding(.bottom)
                }
                
                Text("选择卡片")
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Color.white.opacity(0.5))
                    .cornerRadius(12)
                    .exclusiveTouchTapGesture {
                        showCardSelection = true
                    }
                    .disabled(appState.competitionManager.isRecording)
            }
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal)
            Spacer()
            HStack {
                Text("下一步")
                Image(systemName: "arrowshape.right")
            }
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
            .background(Color.green)
            .cornerRadius(12)
            .exclusiveTouchTapGesture {
                appState.navigationManager.append(.competitionRealtimeView)
                appState.competitionManager.activateCards()
            }
            .disabled(appState.competitionManager.isRecording)
            .padding(.bottom, 120)
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .onFirstAppear {
            // 如果是组队模式，启动计时器a
            if appState.competitionManager.isTeam {
                appState.competitionManager.startTeamJoinTimerA()
            }
        }
        .bottomSheet(isPresented: $showCardSelection, size: .large, destroyOnDismiss: true) {
            CardSelectionView(showCardSelection: $showCardSelection)
        }
    }
    
    @ViewBuilder
    func interleavedHStack<Views: View>(@ViewBuilder _ views: () -> [Views]) -> some View {
        let list = views()
        HStack {
            ForEach(0..<list.count, id: \.self) { i in
                list[i]
                if i < list.count - 1 {
                    Spacer()
                }
            }
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
