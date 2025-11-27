//
//  StoreHouseView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/8.
//

import SwiftUI


struct StoreHouseView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @ObservedObject var userManager = UserManager.shared
    @State var selectedCPAsset: CPAssetUserInfo? = nil
    @State var selectedCard: MagicCard? = nil
    @State var selectedTab: Int = 0
    let globalConfig = GlobalConfig.shared
    
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .defaultBackground.softenColor(blendWithWhiteRatio: 0.2),
                            .defaultBackground
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Text("道具")
                            .font(.system(size: 16, weight: selectedTab == 0 ? .semibold : .regular))
                            .foregroundColor(selectedTab == 0 ? Color.white : Color.thirdText)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = 0
                                }
                            }
                        Rectangle()
                            .fill(selectedTab == 0 ? Color.white : Color.clear)
                            .frame(width: 40, height: 2)
                    }
                    Spacer()
                    VStack(spacing: 10) {
                        Text("装备卡")
                            .font(.system(size: 16, weight: selectedTab == 1 ? .semibold : .regular))
                            .foregroundColor(selectedTab == 1 ? Color.white : Color.thirdText)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedTab = 1
                                }
                            }
                        Rectangle()
                            .fill(selectedTab == 1 ? Color.white : Color.clear)
                            .frame(width: 40, height: 2)
                    }
                    Spacer()
                }
                
                Divider()
                
                TabView(selection: $selectedTab) {
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 10
                        let columnCount = 5
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 20) / CGFloat(columnCount) // 20为ScrollView两侧padding

                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                    ForEach(assetManager.cpassets) { asset in
                                        CPAssetUserCardView(asset: asset)
                                            .frame(width: itemWidth)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedCPAsset?.id == asset.id ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                            .onTapGesture {
                                                if selectedCPAsset?.id == asset.id {
                                                    selectedCPAsset = nil
                                                } else {
                                                    selectedCPAsset = asset
                                                }
                                            }
                                    }
                                }
                                .padding(10)
                            }
                            .refreshable {
                                await MainActor.run {
                                    selectedCPAsset = nil
                                }
                                await assetManager.queryCPAssets(withLoadingToast: false)
                            }
                            if let selected = selectedCPAsset {
                                HStack(alignment: .bottom, spacing: 20) {
                                    VStack(alignment: .leading) {
                                        Text(selected.name)
                                            .bold()
                                            .font(.system(size: 15))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                        
                                        ScrollView {
                                            Text(selected.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(4)
                                        }
                                        .frame(height: 48)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(10)
                                    }
                                    
                                    Text("去购买")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.orange)
                                        .cornerRadius(8)
                                        .onTapGesture {
                                            appState.navigationManager.selectedTab = .shop
                                        }
                                }
                                .padding()
                                .background(Color.black)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .tag(0)
                    
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 20
                        let columnCount = 3
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 40) / CGFloat(columnCount) // 40为ScrollView两侧padding

                        ZStack(alignment: .bottom) {
                            ScrollView {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                    ForEach(assetManager.magicCards) { card in
                                        ZStack {
                                            MagicCardView(card: card)
                                                .frame(width: itemWidth)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(selectedCard?.id == card.id ? Color.orange : Color.clear, lineWidth: 3)
                                                )
                                            if !AppVersionManager.shared.checkMinimumVersion(card.version) {
                                                GeometryReader { geometry in
                                                    Text("不可用")
                                                        .font(.system(size: geometry.size.width * 0.2, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .padding(geometry.size.width * 0.04)
                                                        .background(Color.red.opacity(0.5))
                                                        .cornerRadius(geometry.size.width * 0.04)
                                                }
                                            }
                                        }
                                        .contentShape(Rectangle())      // 解决 MagicCard 图片尺寸宽高比不同导致的点击范围偏差
                                        .onTapGesture {
                                            if selectedCard?.id == card.id {
                                                selectedCard = nil
                                            } else {
                                                selectedCard = card
                                            }
                                        }
                                    }
                                }
                                .padding(20)
                            }
                            .refreshable {
                                await MainActor.run {
                                    selectedCard = nil
                                }
                                await assetManager.queryMagicCards(withLoadingToast: false)
                            }
                            if let card = selectedCard {
                                HStack(alignment: .bottom, spacing: 20) {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            Text(card.name)
                                                .bold()
                                                .font(.system(size: 15))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                            if !AppVersionManager.shared.checkMinimumVersion(card.version) {
                                                Text("客户端版本过低，卡牌暂时无法使用")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        
                                        ScrollView {
                                            Text(card.description)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(4)
                                        }
                                        .frame(height: 48)
                                        .padding(6)
                                        .background(Color.gray.opacity(0.8))
                                        .cornerRadius(10)
                                    }
                                    VStack {
                                        Text("去升级")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.green)
                                            .cornerRadius(8)
                                            .onTapGesture {
                                                appState.navigationManager.append(.instituteView)
                                            }
                                        Text("销毁")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.orange)
                                            .cornerRadius(8)
                                            .onTapGesture {
                                                Task{
                                                    await assetManager.destroyMagicCard(cardID: card.cardID)
                                                    selectedCard = nil
                                                }
                                            }
                                    }
                                }
                                .padding()
                                .background(Color.black)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onValueChange(of: userManager.isLoggedIn) {
            selectedCPAsset = nil
            selectedCard = nil
            if !userManager.isLoggedIn {
                assetManager.resetAll()
            }
        }
        .onStableAppear {
            if globalConfig.refreshStoreHouseView {
                Task {
                    DispatchQueue.main.async {
                        selectedCPAsset = nil
                        selectedCard = nil
                    }
                    await assetManager.queryCPAssets(withLoadingToast: true)
                    await assetManager.queryMagicCards(withLoadingToast: true)
                }
                globalConfig.refreshStoreHouseView  = false
            }
        }
    }
}

struct CPAssetUserCardView: View {
    let asset: CPAssetUserInfo
    
    var body: some View {
        VStack(spacing: 5) {
            CachedAsyncImage(
                urlString: asset.image_url,
                placeholder: Image("Ads"),
                errorImage: Image(systemName: "photo.badge.exclamationmark")
            )
            .aspectRatio(contentMode: .fit)
            .frame(height: 55)
            .clipped()
            
            HStack(spacing: 2) {
                Text("x")
                Text("\(asset.amount)")
            }
            .font(.caption2)
            .foregroundColor(.secondText)
            .padding(4)
            .frame(maxWidth: .infinity)
            .frame(height: 25)
        }
        .frame(height: 80)
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}
