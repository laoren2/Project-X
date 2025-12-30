//
//  UsageTipView.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/27.
//

import SwiftUI

struct UsageTipView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("home.feature.skill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.secondText)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("test")
                            .foregroundStyle(Color.white)
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}
