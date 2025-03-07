//
//  CardSelectionView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/11.
//

import SwiftUI

struct CardSelectionView: View {
    @Binding var isPresented: Bool
    @ObservedObject var cardManager = MagicCardManager.shared
    @State private var tempSelectedCards: [MagicCard] = []
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            VStack {
                if cardManager.availableCards.isEmpty {
                    ProgressView("加载卡片...")
                        .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(cardManager.availableCards) { card in
                                CardSelectableView(card: card, isSelected: tempSelectedCards.contains(card))
                                    .onTapGesture {
                                        toggleSelection(of: card)
                                    }
                            }
                        }
                        .padding()
                    }
                    
                    HStack {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("取消")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // 写入选择结果
                            MagicCardManager.shared.SelectedCards(tempSelectedCards)
                            // 加载对应PredictionModel
                            ModelManager.shared.selectModels(tempSelectedCards)
                            // 异步加载已选择的MLModel
                            Task {
                                await ModelManager.shared.loadSelectedModels()
                            }
                            isPresented = false
                        }) {
                            Text("确定")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        //.disabled(tempSelectedCards.isEmpty)
                    }
                    .padding([.horizontal, .bottom])
                }
            }
            .navigationTitle("选择卡片")
            .navigationBarItems(trailing: Button("完成") {
                isPresented = false
            })
            .onAppear {
                tempSelectedCards = cardManager.selectedCards
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

