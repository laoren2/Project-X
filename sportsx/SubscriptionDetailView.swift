//
//  SubscriptionDetailView.swift
//  sportsx
//
//  Created by 任杰 on 2025/12/4.
//

import SwiftUI
import StoreKit


struct SubscriptionDetailView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    @State private var selectedProduct: Product? = nil
    @State private var isSubscribed: Bool = false
    @State private var autoRenew: Bool?
    @State private var startDate: Date?
    @State private var expireDate: Date?
    @State private var isLoading: Bool = true
    
    @ObservedObject private var manager = IAPManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(isSubscribed ? "订阅中" : "当前未订阅")
                            .font(.title3.bold())
                            .foregroundStyle(isSubscribed ? .green : .gray)
                        
                        Button("刷新") {
                            updateSubscriptionStatus(enforce: true)
                        }
                    }
                    if let start = startDate {
                        Text("订阅开始日期：\(DateDisplay.formattedDate(start))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let end = expireDate {
                        Text("订阅截止日期：\(DateDisplay.formattedDate(end))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    if let autoStatus = autoRenew {
                        HStack {
                            Text("自动续费：")
                            Text(autoStatus ? "已开启" : "未开启")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
            
            subscriptionCards
            HStack {
                Spacer()
                Button("帮助与反馈") {
                    navigationManager.append(.iapHelpView)
                }
                .padding()
                .foregroundStyle(Color.white)
                .background(Color.gray)
                .cornerRadius(10)
            }
            subscribeButton
            Spacer()
        }
        .padding()
        .onFirstAppear {
            Task {
                await manager.loadSubscriptionProducts()
                DispatchQueue.main.async {
                    if !manager.subscriptionProducts.isEmpty {
                        selectedProduct = manager.subscriptionProducts[0]
                    }
                }
            }
            updateSubscriptionStatus()
        }
    }
    
    func updateSubscriptionStatus(enforce: Bool = false) {
        guard var components = URLComponents(string: "/iap/query_subscription_status") else { return }
        components.queryItems = [
            URLQueryItem(name: "enforce", value: "\(enforce)")
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: IAPSubscriptionInfoResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        isSubscribed = unwrappedData.is_active
                        UserManager.shared.user.isVip = unwrappedData.is_active
                        if let autoStatus = unwrappedData.auto_renew, let start = unwrappedData.started_at, let end = unwrappedData.expired_at {
                            autoRenew = autoStatus
                            startDate = ISO8601DateFormatter().date(from: start)
                            expireDate = ISO8601DateFormatter().date(from: end)
                        }
                    }
                }
            default: break
            }
        }
    }
}

// MARK: - 子视图拆分
extension SubscriptionDetailView {
    // 4 个订阅卡片区域
    private var subscriptionCards: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(manager.subscriptionProducts, id: \.id) { product in
                    SubscriptionCardView(
                        product: product,
                        isSelected: selectedProduct?.id == product.id
                    )
                    .onTapGesture {
                        selectedProduct = product
                    }
                }
            }
            .padding(4)
        }
    }
    
    // 订阅按钮
    private var subscribeButton: some View {
        Button {
            Task {
                guard let product = selectedProduct else { return }
                if isSubscribed {
                    if let text = await manager.checkPurchasedSubscription(product: product) {
                        DispatchQueue.main.async {
                            ToastManager.shared.show(toast: Toast(message: text, duration: 3))
                        }
                        return
                    }
                } else {
                    guard !(await manager.checkAllPurchasedSubscriptions()) else {
                        DispatchQueue.main.async {
                            ToastManager.shared.show(toast: Toast(message: "此AppleID关联的其他账号已订阅，无法重复订阅", duration: 3))
                        }
                        return
                    }
                }
                let progressToast = LoadingToast()
                DispatchQueue.main.async {
                    ToastManager.shared.start(toast: progressToast)
                }
                if let subInfo = await manager.purchaseSubscription(product: product) {
                    DispatchQueue.main.async {
                        isSubscribed = subInfo.isActive
                        autoRenew = subInfo.autoRenew
                        if let start = subInfo.startDate, let end = subInfo.expireDate {
                            DispatchQueue.main.async {
                                startDate = ISO8601DateFormatter().date(from: start)
                                expireDate = ISO8601DateFormatter().date(from: end)
                            }
                        }
                    }
                    // 更新用户的订阅状态 & original_transaction_id
                    await UserManager.shared.fetchMeInfo()
                }
                DispatchQueue.main.async {
                    ToastManager.shared.finish()
                }
            }
        } label: {
            Text(isSubscribed ? "更新订阅" : "立即订阅")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(isSubscribed ? Color.green : Color.orange)
                .cornerRadius(10)
        }
        .disabled(selectedProduct == nil)
    }
}

struct SubscriptionCardView: View {
    let product: Product
    let isSelected: Bool
    
    var body: some View {
        VStack {
            VStack(spacing: 20) {
                Text(product.displayName)
                    .font(.headline)
                
                Text(product.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(product.displayPrice)
                .font(.headline)
        }
        .padding()
        .frame(width: 200, height: 300)
        .background(isSelected ? Color.orange.opacity(0.2) : Color(.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

struct IAPHelpView: View {
    var body: some View {
        VStack(spacing: 40) {
            JustifiedText("    在iOS系统中进行订阅时，如果出现付款后权益未到账的情况，可能是您登陆App Store的appleID下有多个Sporreer账号，可先切换各账号查看是否购买在其他账号，或点击下方按钮查询当前appleID关联的已订阅账号，也可以稍等片刻尝试手动刷新一下订阅状态，如果仍有问题，可提交反馈并附上Apple支付账单截图，我们会尽快解决并给予回复，感谢您的支持！")
                .border(.red)
                
            Button(action:{
                Task {
                    await IAPManager.shared.queryEntitlementAccount()
                }
            }) {
                Text("点击查询")
                    .padding(.vertical)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
}
