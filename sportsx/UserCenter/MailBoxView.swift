//
//  MailBoxView.swift
//  sportsx
//
//  Created by 任杰 on 2025/9/17.
//

import SwiftUI


struct MailBoxView: View {
    @EnvironmentObject var appState: AppState
    @State private var mails: [MailCard] = []
    @State private var hasMore: Bool = false
    @State private var isLoading: Bool = false
    @State private var page: Int = 1
    let pageSize: Int = 10
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("邮箱")
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
                if mails.isEmpty {
                    VStack {
                        Text("暂无邮件")
                            .foregroundStyle(Color.secondText)
                    }
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(mails) { mail in
                            MailCardView(mail: mail)
                                .onAppear {
                                    if mail == mails.last && hasMore{
                                        Task {
                                            await queryMails(reset: false, withLoadingToast: false)
                                        }
                                    }
                                }
                        }
                        if isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding()
                }
            }
            .refreshable {
                await queryMails(reset: true, withLoadingToast: false)
            }
        }
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onFirstAppear {
            Task {
                await queryMails(reset: true, withLoadingToast: true)
            }
        }
    }
    
    @MainActor
    func queryMails(reset: Bool, withLoadingToast: Bool) async {
        if reset {
            mails.removeAll()
            page = 1
        }
        isLoading = true
        
        guard var components = URLComponents(string: "/mailbox/query_mails") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: MailResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        isLoading = false
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for mail in unwrappedData.mails {
                    mails.append(MailCard(from: mail))
                }
                if unwrappedData.mails.count < self.pageSize {
                    hasMore = false
                } else {
                    hasMore = true
                    page += 1
                }
            }
        default: break
        }
    }
}

struct MailCardView: View {
    @EnvironmentObject var appState: AppState
    let mail: MailCard
    @State var hasRead: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                Image(systemName: mail.mailType == .REWARD ? "gift.fill" : "envelope.fill")
                    .frame(width: 20)
                    .foregroundStyle(mail.mailType == .REWARD ? .yellow : .blue)
                if !hasRead {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.red)
                        .offset(x: -3, y: -3)
                }
            }
            Text(mail.title)
                .font(.system(size: 16, weight: .semibold))
            Spacer()
            if let created = mail.created_at {
                Text("\(DateDisplay.formattedDate(created))")
                    .font(.caption)
            }
        }
        .foregroundStyle(Color.secondText)
        .padding()
        .background(Color.gray)
        .cornerRadius(10)
        .onFirstAppear {
            hasRead = mail.isRead
        }
        .exclusiveTouchTapGesture {
            if !hasRead {
                hasRead = true
                GlobalConfig.shared.refreshMailStatus = true
            }
            appState.navigationManager.append(.mailBoxDetailView(mailID: mail.mailID))
        }
    }
}

struct MailBoxDetailView: View {
    @EnvironmentObject var appState: AppState
    let mailID: String
    @State var mail: MailCardDetail? = nil
    @State var isRewardsReceived: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                CommonIconButton(icon: "chevron.left") {
                    appState.navigationManager.removeLast()
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.secondText)
                Spacer()
                Text("邮件详情")
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
            Spacer()
            if let mail = mail {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(mail.title)
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(.white)
                        if let created = mail.created_at {
                            Text("发送时间: \(DateDisplay.formattedDate(created))")
                                .font(.caption)
                        }
                        
                        Divider()
                        
                        Text(mail.content ?? "")
                            .font(.body)
                        
                        if !mail.ccassets.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("附件奖励")
                                    .font(.headline)
                                ForEach(mail.ccassets, id: \.ccasset_type) { asset in
                                    HStack {
                                        Image(systemName: asset.ccasset_type.iconName)
                                        Spacer()
                                        Text("\(asset.new_ccamount)")
                                            .bold()
                                    }
                                }
                                if let expired = mail.expired_at {
                                    Text("邮件有效期至: \(DateDisplay.formattedDate(expired))")
                                        .font(.caption)
                                }
                                if mail.is_received != nil {
                                    Text(isRewardsReceived ? "已领取" : "领取")
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(isRewardsReceived ? .gray : .green)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .padding(.top, 8)
                                        .exclusiveTouchTapGesture {
                                            receiveRewards()
                                        }
                                        .disabled(isRewardsReceived)
                                }
                            }
                        }
                    }
                    .foregroundStyle(Color.secondText)
                    .padding()
                }
            } else {
                VStack {
                    Text("无数据")
                        .foregroundStyle(Color.secondText)
                }
            }
            Spacer()
        }
        .environment(\.colorScheme, .dark)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableBackGesture()
        .onFirstAppear {
            queryMailDetail()
        }
    }
    
    func queryMailDetail() {
        guard var components = URLComponents(string: "/mailbox/query_mail_detail") else { return }
        components.queryItems = [
            URLQueryItem(name: "mail_id", value: mailID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: MailCardDetailDTO.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.mail = MailCardDetail(from: unwrappedData)
                        if let is_received = unwrappedData.is_received {
                            self.isRewardsReceived = is_received
                        }
                    }
                }
            default: break
            }
        }
    }
    
    func receiveRewards() {
        // 暂仅支持 CCAsset
        guard var components = URLComponents(string: "/mailbox/receive_mail_rewards") else { return }
        components.queryItems = [
            URLQueryItem(name: "mail_id", value: mailID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: AssetUpdateResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        for ccasset in unwrappedData.ccassets {
                            AssetManager.shared.updateCCAsset(type: ccasset.ccasset_type, newBalance: ccasset.new_ccamount)
                        }
                        self.isRewardsReceived = true
                    }
                }
            default: break
            }
        }
    }
}

enum MailType: String, Codable {
    case REWARD = "reward"              // 奖励邮件
    case NOTIFICATION = "notification"  // 通知邮件
}

struct MailCardDetail: Identifiable, Equatable {
    var id: String { mailID }
    let mailID: String
    let title: String
    let content: String?
    let mailType: MailType
    let ccassets: [CCUpdateResponse]
    let is_received: Bool?
    let created_at: Date?
    let expired_at: Date?
    
    init(from card: MailCardDetailDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.mailID = card.mail_id
        self.title = card.title
        self.content = card.content
        self.mailType = card.mail_type
        var temp_assets: [CCUpdateResponse] = []
        if let attachments = card.attachments {
            for type in CCAssetType.allCases {
                if let amount = attachments["\(type.rawValue)"]?.intValue {
                    temp_assets.append(CCUpdateResponse(ccasset_type: type, new_ccamount: amount))
                }
            }
        }
        self.ccassets = temp_assets
        self.is_received = card.is_received
        self.created_at = formatter.date(from: card.created_at)
        self.expired_at = formatter.date(from: card.expired_at ?? "")
    }
    
    static func == (lhs: MailCardDetail, rhs: MailCardDetail) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MailCardDetailDTO: Codable {
    let mail_id: String
    let title: String
    let content: String?
    let mail_type: MailType
    let attachments: JSONValue?
    let is_received: Bool?
    let created_at: String
    let expired_at: String?
}

class MailCard: Identifiable, Equatable {
    var id: String { mailID }
    let mailID: String
    let title: String
    let mailType: MailType
    let created_at: Date?
    var isRead: Bool
    
    init(from card: MailCardDTO) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.mailID = card.mail_id
        self.title = card.title
        self.mailType = card.mail_type
        self.created_at = formatter.date(from: card.created_at)
        self.isRead = card.is_read
    }
    
    static func == (lhs: MailCard, rhs: MailCard) -> Bool {
        return lhs.id == rhs.id
    }
}

struct MailCardDTO: Codable {
    let mail_id: String
    let title: String
    let mail_type: MailType
    let created_at: String
    let is_read: Bool
}

struct MailResponse: Codable {
    let mails: [MailCardDTO]
}

#Preview {
    let appState = AppState.shared
    return MailBoxDetailView(mailID: "")
        .environmentObject(appState)
}
