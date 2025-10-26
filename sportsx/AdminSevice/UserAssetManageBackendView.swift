//
//  UserAssetManageBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/9.
//

import SwiftUI


struct UserAssetManageBackendView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var user_id: String = ""
    @State private var ccasset_type: String = CCAssetType.coin.rawValue
    @State private var amount: String = ""
    let types = [
        CCAssetType.coin,
        CCAssetType.coupon,
        CCAssetType.voucher,
        CCAssetType.stone1,
        CCAssetType.stone2,
        CCAssetType.stone3
    ]
    
    @State var isLoading: Bool = false
    
    @State private var user2_id: String = ""
    @State private var mail_type: String = MailType.NOTIFICATION.rawValue
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var attachments: String = ""
    let mail_types = [
        MailType.NOTIFICATION,
        MailType.REWARD
    ]
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    appState.navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("用户资产管理")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            
            HStack {
                VStack {
                    TextField("用户id", text: $user_id)
                        .background(.gray.opacity(0.1))
                    Menu {
                        ForEach(types, id: \.self) { type in
                            Button(type.rawValue) {
                                ccasset_type = type.rawValue
                            }
                        }
                    } label: {
                        HStack {
                            Text(ccasset_type)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
                    TextField("数量变化", text: $amount)
                        .background(.gray.opacity(0.1))
                        .keyboardType(.numberPad)
                }
                
                Button("更新") {
                    //viewModel.assets.removeAll()
                    //viewModel.currentPage = 1
                    rewardCCAssets()
                }
                .padding()
            }
            Spacer()
            HStack {
                VStack {
                    TextField("用户id", text: $user2_id)
                        .background(.gray.opacity(0.1))
                    Menu {
                        ForEach(mail_types, id: \.self) { type in
                            Button(type.rawValue) {
                                mail_type = type.rawValue
                            }
                        }
                    } label: {
                        HStack {
                            Text(mail_type)
                                .font(.subheadline)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .cornerRadius(8)
                    }
                    TextField("标题", text: $title)
                        .background(.gray.opacity(0.1))
                    TextField("内容", text: $content)
                        .background(.gray.opacity(0.1))
                    TextField("附件", text: $attachments)
                        .background(.gray.opacity(0.1))
                }
                
                Button("发送邮件") {
                    sendMail()
                }
                .padding()
            }
            Spacer()
        }
        .padding(.horizontal)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
    
    func sendMail() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        var body: [String: String] = [
            "user_id": user2_id,
            "type": mail_type,
            "title": title
        ]
        if !content.isEmpty {
            body["content"] = content
        }
        if !attachments.isEmpty {
            body["attachments"] = attachments
        }
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/mailbox/send_mail", method: .post, headers: headers, body: encodedBody, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showSuccessToast: true, showErrorToast: true) { _ in }
    }
    
    func rewardCCAssets() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        let body: [String: String] = [
            "user_id": user_id,
            "ccasset_type": ccasset_type,
            "amount": amount
        ]
        guard let encodedBody = try? JSONEncoder().encode(body) else {
            return
        }
        
        let request = APIRequest(path: "/asset/reward_ccasset", method: .post, headers: headers, body: encodedBody, isInternal: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showSuccessToast: true, showErrorToast: true) { _ in }
    }
}
