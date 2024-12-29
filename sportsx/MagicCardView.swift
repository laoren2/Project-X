//
//  MagicCardView.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/26.
//

import SwiftUI

struct CardSelectableView: View {
    let card: MagicCard
    let isSelected: Bool
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack {
                Image(card.imageURL)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 100)
                    .cornerRadius(8)
                Text(card.name)
                    .font(.headline)
                Text("类型: \(card.type)")
                    .font(.subheadline)
                Text("等级: \(card.level)")
                    .font(.subheadline)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? Color.blue : Color.gray, lineWidth: isSelected ? 2 : 1))
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .offset(x: 10, y: -10)
            }
        }
    }
}

// MARK: - 已选择卡片视图
struct CardView: View {
    let card: MagicCard
    
    var body: some View {
        VStack {
            Image(card.imageURL)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .cornerRadius(8)
            Text(card.name)
                .font(.caption)
        }
        .padding(4)
    }
}
