//
//  AdminPanelView.swift
//  sportsx
//
//  Created by 任杰 on 2025/6/3.
//

import SwiftUI

#if DEBUG
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
                    SetUpItemView(icon: "pc", title: "自行车赛事管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.bikeEventBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "自行车赛道管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.bikeTrackBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "自行车记录校验", isDarkScheme: false) {
                        NavigationManager.shared.append(.bikeRecordBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "跑步赛事管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.runningEventBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "跑步赛道管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.runningTrackBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "跑步记录校验", isDarkScheme: false) {
                        NavigationManager.shared.append(.runningRecordBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "cp资产定义管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.cpAssetBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "cp资产商店管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.cpAssetPriceBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "卡牌定义管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.magicCardBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "卡牌商店管理", isDarkScheme: false) {
                        NavigationManager.shared.append(.magicCardPriceBackendView)
                    }
                    SetUpItemView(icon: "pc", title: "用户资产管理",showDivider: false, isDarkScheme: false) {
                        NavigationManager.shared.append(.userAssetManageBackendView)
                    }
                }
                .cornerRadius(20)
                .padding()
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
}

#Preview {
    AdminPanelView()
}
#endif
