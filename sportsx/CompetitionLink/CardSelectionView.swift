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
    @ObservedObject var userManager = UserManager.shared
    @State private var tempSelectedCards: [MagicCard] = []
    @State private var searchText: String = ""
    @Binding var showCardSelection: Bool
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    private var maxCards: Int { return userManager.user.isVip ? 4 : 3}
    
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
                    Text("action.cancel")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.thirdText)
                }
                
                Spacer()
                
                Text("competition.magiccard.select")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                
                Spacer()
                
                Button(action:{
                    showCardSelection = false
                    appState.competitionManager.selectedCards = tempSelectedCards
                }) {
                    Text("action.complete")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white)
                }
            }
            .padding()
            
            // 已选卡牌区域
            VStack {
                Text("competition.magiccard.selected")
                    .font(.headline)
                    .foregroundStyle(Color.secondText)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(tempSelectedCards) { card in
                            // 显示已选择的卡牌
                            ZStack(alignment: .topTrailing) {
                                MagicCardView(card: card)
                                    .frame(width: cardWidth * 0.8)
                                
                                // 卸载按钮
                                Button(action: {
                                    tempSelectedCards.removeAll { $0.cardID == card.cardID }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .background(Circle().fill(Color.white))
                                        .shadow(radius: 1)
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                        // 占位卡牌
                        ForEach(tempSelectedCards.count..<4, id: \.self) { index in
                            if index == 3 {
                                ZStack {
                                    EmptyCardVipSlot()
                                        .frame(width: cardWidth * 0.8)
                                    if !userManager.user.isVip {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(Color.gray.opacity(0.6))
                                            .font(.system(size: 50))
                                    }
                                }
                            } else {
                                EmptyCardSlot()
                                    .frame(width: cardWidth * 0.8)
                            }
                        }
                    }
                    .padding(2)
                    .padding(.top, 6)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .padding()
            
            // 搜索框
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 44)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding(.leading, 12)
                        
                        TextField(text: $searchText) {
                            Text("competition.magiccard.search")
                                .foregroundColor(.gray)
                                .font(.system(size: 15))
                        }
                        .foregroundStyle(Color.white)
                        .font(.system(size: 15))
                        .padding(.vertical, 8)
                        
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
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            
            // 卡牌列表
            if assetManager.magicCards.isEmpty {
                Text("institute.upgrade.card.none")
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
            Spacer()
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.defaultBackground)
        .hideKeyboardOnScroll()
        .onStableAppear {
            tempSelectedCards = appState.competitionManager.selectedCards
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
                ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.sporttype"))
                return
            }
            // 检查组队模式
            if card.tags.first(where: { $0 == "team" }) != nil {
                guard CompetitionManager.shared.isTeam else {
                    ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.sportmode"))
                    return
                }
                if tempSelectedCards.contains(where: { $0.tags.contains("team") }) {
                    ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.exceed"))
                    return
                }
            }
            // 检查传感器
            if let location = card.sensorLocation {
                if !DeviceManager.shared.checkSensorLocation(at: location >> 1, in: card.sensorType) {
                    if card.sensorLocation2 == nil {
                        ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.no_sensor"))
                        return
                    }
                    if let location2 = card.sensorLocation2, !DeviceManager.shared.checkSensorLocation(at: location2 >> 1, in: card.sensorType) {
                        ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.no_sensor"))
                        return
                    }
                }
            }
            // 检查版本
            guard AppVersionManager.shared.checkMinimumVersion(card.version) else {
                ToastManager.shared.show(toast: Toast(message: "warehouse.equipcard.unavailable.detail"))
                return
            }
            // 检查是否重复装备
            guard tempSelectedCards.firstIndex(where: { $0.defID == card.defID }) == nil else {
                ToastManager.shared.show(toast: Toast(message: "competition.magiccard.error.repeat"))
                return
            }
            if tempSelectedCards.count < maxCards {
                tempSelectedCards.append(card)
            }
        }
    }
}


//#Preview {
//    CardSelectionView()
//}
