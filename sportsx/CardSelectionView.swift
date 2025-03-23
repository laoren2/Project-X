//
//  CardSelectionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import SwiftUI

struct CardSelectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var cardManager = MagicCardManager.shared
    @State private var tempSelectedCards: [MagicCard] = []
    @State private var searchText: String = ""
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    private let cardHeight: CGFloat = 140
    private let maxCards = 3
    
    // 定义5列网格
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]
    
    // 过滤后的卡牌
    var filteredCards: [MagicCard] {
        if searchText.isEmpty {
            return cardManager.availableCards
        } else {
            return cardManager.availableCards.filter { card in
                card.name.lowercased().contains(searchText.lowercased()) ||
                card.type.lowercased().contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack() {
                // 已选卡牌区域
                VStack {
                    Text("已选")
                        .font(.headline)
                        .padding(.top, 10)
                    
                    HStack(spacing: 20) {
                        ForEach(0..<maxCards, id: \.self) { index in
                            if index < tempSelectedCards.count {
                                // 显示已选择的卡牌
                                ZStack(alignment: .topTrailing) {
                                    CardView(card: tempSelectedCards[index])
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
                if cardManager.availableCards.isEmpty {
                    ProgressView("加载卡片...")
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 0) {
                            ForEach(filteredCards) { card in
                                CardSelectableView(
                                    card: card,
                                    isSelected: tempSelectedCards.contains(card),
                                    onTap: { toggleSelection(of: card) }
                                )
                                .aspectRatio(5/7, contentMode: .fit)
                            }
                        }
                        .padding()
                    }
                }
                
                // 底部按钮
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("取消")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.2))
                            )
                            .foregroundColor(.primary)
                    }
                    
                    Button(action: {
                        // 写入选择结果
                        appState.competitionManager.SelectedCards(tempSelectedCards)
                        // 加载对应PredictionModel
                        ModelManager.shared.selectModels(tempSelectedCards)
                        // 异步加载已选择的MLModel
                        Task {
                            await ModelManager.shared.loadSelectedModels()
                        }
                        dismiss()
                    }) {
                        Text("确定")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                    }
                }
                .padding([.horizontal, .bottom])
            }
            .navigationTitle("技能卡选择")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                tempSelectedCards = appState.competitionManager.selectedCards
            }
        }
    }
    
    private func toggleSelection(of card: MagicCard) {
        if tempSelectedCards.contains(card) {
            tempSelectedCards.removeAll { $0 == card }
        } else {
            if tempSelectedCards.count < 3 {
                tempSelectedCards.append(card)
            }
        }
    }
}


//#Preview {
//    CardSelectionView()
//}
