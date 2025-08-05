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
    //@State var cpassets: [CPAssetUserInfo] = []
    @State var selectedAsset: CPAssetUserInfo? = nil
    @State var selectedTab: Int = 0
    @State private var firstOnAppear = true
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
                                                selectedAsset = asset
                                            }
                                        }
                                }
                            }
                            .padding(10)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .refreshable {
                        selectedAsset = nil
                        await assetManager.queryCPAssets(withLoadingToast: false)
                    }
                    .background(Color.gray.opacity(0.2))
                    .tag(0)
                    
                    GeometryReader { geo in
                        let itemSpacing: CGFloat = 20
                        let columnCount = 3
                        let totalSpacing = itemSpacing * CGFloat(columnCount - 1)
                        let itemWidth = (geo.size.width - totalSpacing - 40) / CGFloat(columnCount) // 40为ScrollView两侧padding

                        ScrollView {
                            LazyVGrid(columns: Array(repeating: GridItem(.fixed(itemWidth), spacing: itemSpacing), count: columnCount), spacing: 10) {
                                // todo
                            }
                            .padding(20)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .refreshable {
                        //await fetchCPAssets(withLoadingToast: false)
                    }
                    .background(Color.gray.opacity(0.2))
                    .tag(1)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            
            if let selected = selectedAsset {
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
                    
                    Text("销毁")
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(8)
                        .onTapGesture {
                            // todo
                        }
                }
                .padding()
                .background(Color.black)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onStableAppear {
            if firstOnAppear || globalConfig.refreshStoreHouseView {
                Task {
                    selectedAsset = nil
                    await assetManager.queryCPAssets(withLoadingToast: true)
                }
                globalConfig.refreshStoreHouseView  = false
            }
            firstOnAppear = false
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
