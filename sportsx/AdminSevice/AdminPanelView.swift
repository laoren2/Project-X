//
//  AdminPanelView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/3.
//

import SwiftUI


struct AdminPanelView: View {
    @EnvironmentObject var appState: AppState
    

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("后台管理")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 0) {
                    SetUpItemView(icon: "pc", title: "赛季&地理区域管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.seasonBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "赛事管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.eventBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "赛道管理",showDivider: false, isDarkScheme: false) {
                        NavigationManager.shared.append(.trackBackendView)
                    }
                }
                .cornerRadius(20)
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
    }
}

#Preview {
    AdminPanelView()
}
