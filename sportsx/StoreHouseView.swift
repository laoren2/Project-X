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
    
    @State var selectedAsset: CommonAssetUserInfo? = nil
    
    @State var selectedTab: Int = 0
    let globalConfig = GlobalConfig.shared
    
    
    var body: some View {
        ZStack(alignment: .bottom) {
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
                        Text("shop.tab.props")
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
                        Text("shop.tab.equip_card")
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
                                                    .stroke(selectedAsset?.id == asset.id ? Color.orange : Color.clear, lineWidth: 2)
                                            )
                                            .onTapGesture {
                                                if selectedAsset?.id == asset.id {
                                                    selectedAsset = nil
                                                } else {
                                                    selectedAsset = CommonAssetUserInfo(from: asset)
                                                }
                                            }
                                    }
                                }
                                .padding(.top, 10)
                                .padding(.bottom, 100)
                            }
                            .refreshable {
                                await MainActor.run {
                                    selectedAsset = nil
                                }
                                await assetManager.queryCPAssets(withLoadingToast: false)
                            }
                        }
                    }
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
                                                        .stroke(selectedAsset?.id == card.id ? Color.orange : Color.clear, lineWidth: 3)
                                                )
                                            if !AppVersionManager.shared.checkMinimumVersion(card.version) {
                                                Text("warehouse.equipcard.unavailable")
                                                    .font(.system(size: itemWidth * 0.2, weight: .bold))
                                                    .foregroundColor(.white)
                                                    .padding(itemWidth * 0.04)
                                                    .background(Color.red.opacity(0.5))
                                                    .cornerRadius(itemWidth * 0.04)
                                            }
                                        }
                                        .onTapGesture {
                                            if selectedAsset?.id == card.id {
                                                selectedAsset = nil
                                            } else {
                                                selectedAsset = CommonAssetUserInfo(from: card)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 20)
                                .padding(.bottom, 100)
                            }
                            .refreshable {
                                await MainActor.run {
                                    selectedAsset = nil
                                }
                                await assetManager.queryMagicCards(withLoadingToast: false)
                            }
                        }
                    }
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.gray.opacity(0.2))
            }
            
            if let asset = selectedAsset {
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(asset.name)
                                .bold()
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                            if let version = asset.version, !AppVersionManager.shared.checkMinimumVersion(version) {
                                Text("warehouse.equipcard.unavailable.detail")
                                    .font(.system(size: 13))
                                    .foregroundColor(.red)
                            }
                        }
                        ScrollView {
                            Text(asset.description)
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
                    if asset.assetType == .cpasset {
                        Text("warehouse.action.goBuy")
                            .foregroundColor(.white)
                            .frame(height: 60)
                            .padding(.horizontal, 16)
                            .background(Color.orange)
                            .cornerRadius(8)
                            .onTapGesture {
                                appState.navigationManager.selectedTab = .shop
                            }
                    } else if asset.assetType == .magiccard {
                        Text("warehouse.action.goUpgrade")
                            .foregroundColor(.white)
                            .frame(height: 60)
                            .padding(.horizontal, 16)
                            .background(Color.green)
                            .cornerRadius(8)
                            .onTapGesture {
                                appState.navigationManager.append(.instituteView)
                            }
                    }
                }
                .padding()
                .background(Color.black)
                .padding(.bottom, 85)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .bottom)
        .onValueChange(of: userManager.isLoggedIn) {
            selectedAsset = nil
            if !userManager.isLoggedIn {
                assetManager.resetAll()
            }
        }
        .onStableAppear {
            if globalConfig.refreshStoreHouseView {
                Task {
                    DispatchQueue.main.async {
                        selectedAsset = nil
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
                urlString: asset.image_url
            )
            .aspectRatio(contentMode: .fit)
            .frame(height: 55)
            .clipped()
            
            HStack(spacing: 2) {
                Text("x")
                Text("\(asset.amount)")
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
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
