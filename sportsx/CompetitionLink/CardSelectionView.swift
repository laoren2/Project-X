//
//  CardSelectionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import SwiftUI

struct CardSelectionView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @State private var tempSelectedCards: [MagicCard] = []
    @State private var searchText: String = ""
    @Binding var showCardSelection: Bool
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 140
    private let maxCards = 3
    
    // 定义4列网格
    let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]
    
    // 过滤后的卡牌
    var filteredCards: [MagicCard] {
        if searchText.isEmpty {
            return assetManager.magicCards
        } else {
            return assetManager.magicCards.filter { card in
                card.name.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    showCardSelection = false
                }) {
                    Text("取消")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.thirdText)
                }
                
                Spacer()
                
                Text("选择技能卡")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    showCardSelection = false
                    appState.competitionManager.activateCards(tempSelectedCards)
                }) {
                    Text("完成")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                }
            }
            .padding()
            
            // 已选卡牌区域
            VStack {
                Text("已选择")
                    .font(.headline)
                    .foregroundStyle(Color.secondText)
                    .padding(.top, 10)
                
                HStack(spacing: 20) {
                    ForEach(0..<maxCards, id: \.self) { index in
                        if index < tempSelectedCards.count {
                            // 显示已选择的卡牌
                            ZStack(alignment: .topTrailing) {
                                MagicCardView(card: tempSelectedCards[index])
                                    .frame(width: cardWidth * 0.8, height: cardHeight * 0.8)
                                
                                // 卸载按钮
                                Button(action: {
                                    if index < tempSelectedCards.count {
                                        tempSelectedCards.remove(at: index)
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                        .shadow(radius: 1)
                                }
                                .offset(x: 8, y: -8)
                            }
                        } else {
                            // 显示占位卡牌
                            EmptyCardSlot()
                                .frame(width: cardWidth * 0.8, height: cardHeight * 0.8)
                        }
                    }
                }
                .padding(.bottom, 20)
                .padding(.leading, 30)
                .padding(.trailing, 30)
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            
            // 搜索框
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.systemGray6))
                        .frame(height: 44)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.leading, 12)
                        
                        TextField("搜索卡牌", text: $searchText)
                            .padding(.vertical, 10)
                            .foregroundColor(.primary)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation {
                                    searchText = ""
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 12)
                            }
                            .transition(.opacity)
                        } else {
                            // 占位，保持布局一致
                            Spacer().frame(width: 12)
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 卡牌列表
            if assetManager.magicCards.isEmpty {
                Text("无可用卡牌")
                    .padding()
                    .foregroundStyle(Color.secondText)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(filteredCards) { card in
                            MagicCardSelectableView(
                                card: card,
                                isSelected: tempSelectedCards.contains(card)
                            )
                            .onTapGesture {
                                onCardTap(of: card)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color.defaultBackground)
        .onChange(of: showCardSelection) {
            if !showCardSelection {
                tempSelectedCards = appState.competitionManager.selectedCards
            }
        }
        .onFirstAppear {
            if assetManager.magicCards.isEmpty {
                Task {
                    await assetManager.queryMagicCards(withLoadingToast: false)
                }
            }
        }
    }
    
    private func onCardTap(of card: MagicCard) {
        if tempSelectedCards.contains(card) {
            tempSelectedCards.removeAll { $0.cardID == card.cardID }
        } else {
            // 检查运动类型
            guard card.sportType == CompetitionManager.shared.sport else {
                ToastManager.shared.show(toast: Toast(message: "运动类型不匹配"))
                return
            }
            // 检查组队模式
            if card.tags.first(where: { $0 == "team" }) != nil {
                guard CompetitionManager.shared.isTeam else {
                    ToastManager.shared.show(toast: Toast(message: "运动模式不匹配"))
                    return
                }
            }
            // 检查传感器
            if let location = card.sensorLocation {
                guard DeviceManager.shared.checkSensorLocation(at: location >> 1, in: card.sensorType) else {
                    ToastManager.shared.show(toast: Toast(message: "传感器未绑定"))
                    return
                }
            }
            // 检查版本
            guard AppVersionManager.shared.checkMinimumVersion(card.version) else {
                ToastManager.shared.show(toast: Toast(message: "客户端版本过低"))
                return
            }
            // 检查是否重复装备
            guard tempSelectedCards.firstIndex(where: { $0.defID == card.defID }) == nil else {
                ToastManager.shared.show(toast: Toast(message: "不可重复装备"))
                return
            }
            if tempSelectedCards.count < 3 {
                tempSelectedCards.append(card)
            }
        }
    }
}


//#Preview {
//    CardSelectionView()
//}
