//
//  MailboxBackendView.swift
//  sportsx
//
//  Created by 任杰 on 2025/7/9.
//

import SwiftUI


struct MailboxBackendView: View {
    @ObservedObject var navigationManager = NavigationManager.shared
    
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
    
    @State private var title_hans: String = ""
    @State private var title_hant: String = ""
    @State private var title_en: String = ""
    
    @State private var content_hans: String = ""
    @State private var content_hant: String = ""
    @State private var content_en: String = ""
    
    @State private var attachments: String = ""
    
    let mail_types = [
        MailType.NOTIFICATION,
        MailType.REWARD
    ]
    
    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    navigationManager.removeLast()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                }
                
                Spacer()
                
                Text("邮件管理")
                    .font(.system(size: 18, weight: .bold))
                
                Spacer()
                
                // 平衡布局的空按钮
                Button(action: {}) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
            }
            ScrollView {
                VStack(spacing: 50) {
                    VStack {
                        Text("更新用户资产")
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
                    }
                    VStack {
                        Text("发送邮件")
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
                                TextField("标题hans", text: $title_hans)
                                    .background(.gray.opacity(0.1))
                                TextField("标题hant", text: $title_hant)
                                    .background(.gray.opacity(0.1))
                                TextField("标题en", text: $title_en)
                                    .background(.gray.opacity(0.1))
                                TextField("内容hans", text: $content_hans)
                                    .background(.gray.opacity(0.1))
                                TextField("内容hant", text: $content_hant)
                                    .background(.gray.opacity(0.1))
                                TextField("内容en", text: $content_en)
                                    .background(.gray.opacity(0.1))
                                TextField("附件", text: $attachments)
                                    .background(.gray.opacity(0.1))
                            }
                            
                            Button("发送邮件") {
                                sendMail()
                            }
                            .padding()
                            .disabled(user2_id.isEmpty || title_en.isEmpty || title_hans.isEmpty || title_hant.isEmpty)
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture()
    }
    
    func sendMail() {
        var headers: [String: String] = [:]
        headers["Content-Type"] = "application/json"
        
        var title_i18n: [String: String] = [:]
        if !title_hans.isEmpty { title_i18n["zh-Hans"] = title_hans }
        if !title_hant.isEmpty { title_i18n["zh-Hant"] = title_hant }
        if !title_en.isEmpty { title_i18n["en"] = title_en }

        var content_i18n: [String: String] = [:]
        if !content_hans.isEmpty { content_i18n["zh-Hans"] = content_hans }
        if !content_hant.isEmpty { content_i18n["zh-Hant"] = content_hant }
        if !content_en.isEmpty { content_i18n["en"] = content_en }
        
        var body: [String: Any] = [
            "user_id": user2_id,
            "type": mail_type,
            "title": title_i18n
        ]
        if !content_i18n.isEmpty {
            body["content"] = content_i18n
        }
        if !attachments.isEmpty {
            body["attachments"] = attachments
        }
        guard JSONSerialization.isValidJSONObject(body), let encodedBody = try? JSONSerialization.data(withJSONObject: body) else { return }
        
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
