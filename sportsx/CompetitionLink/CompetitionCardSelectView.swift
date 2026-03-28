//
//  CompetitionCardSelectView.swift
//  sportsx
//
//  Created by 任杰 on 2025/3/15.
//

import SwiftUI


struct CompetitionCardSelectView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var assetManager = AssetManager.shared
    @ObservedObject var userManager = UserManager.shared
    @State private var showCardSelection = false
    
    @State var stateValue: Int = 0
    @State var familiarityValue: Double = 0
    
    // 卡牌容器的常量
    private let cardWidth: CGFloat = 100
    //private let cardHeight: CGFloat = 140
    private var maxCards: Int { return userManager.user.isVip ? 4 : 3}
    
    var body: some View {
        VStack {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 5)
                    .padding(.trailing, 20)
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        // 销毁计时器a和b
                        appState.competitionManager.stopAllTeamJoinTimers()
                        appState.navigationManager.removeLast()
                        if !appState.competitionManager.isRecording {
                            appState.competitionManager.resetCompetitionProperties()
                        }
                    }
                Spacer()
                if let sport = appState.competitionManager.sport {
                    Image(sport.iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                }
                Text(appState.competitionManager.isTeam ? "competition.register.team" : "competition.register.single")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.secondText)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(appState.competitionManager.isTeam ? Color.orange.opacity(0.6) : Color.green.opacity(0.6))
                    .cornerRadius(6)
                Spacer()
                Button(action: {
                    appState.navigationManager.append(.sensorBindView)
                }) {
                    Image("device_bind")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 20)
                        .padding(.vertical, 5)
                        .padding(.leading, 20)
                }
            }
            .padding(.horizontal)
            
            ScrollView {
                VStack(spacing: 20) {
                    // 组队模式显示区域
                    if appState.competitionManager.isTeam {
                        if appState.competitionManager.isTeamJoinWindowExpired {
                            Text("competition.realtime.out_window")
                                .foregroundColor(.red)
                                .padding()
                        } else {
                            Text("competition.realtime.remaining_time \(appState.competitionManager.teamJoinRemainingTime)")
                                .font(.headline)
                                .foregroundStyle(Color.white)
                                .padding()
                        }
                    }
                    
                    HStack {
                        HStack(spacing: 4) {
                            Text("competition.cardselect.familiarity_buff")
                                .font(.headline)
                            Image(systemName: "info.circle")
                                .foregroundStyle(Color.thirdText)
                                .font(.subheadline)
                                .exclusiveTouchTapGesture {
                                    PopupWindowManager.shared.presentPopup(
                                        title: "competition.cardselect.familiarity_buff",
                                        message: "competition.cardselect.familiarity_buff.description",
                                        bottomButtons: [.confirm()]
                                    )
                                }
                        }
                        Spacer()
                        Text(String(format: "%.2f %%", Double(familiarityValue) * 2))
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    
                    HStack {
                        Text("competition.cardselect.sport_state_buff")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f %%", Double(stateValue) * 2 / 100))
                            .font(.system(.body, design: .rounded, weight: .bold))
                    }
                    .foregroundStyle(Color.white)
                    
                    HStack {
                        if userManager.user.isVip {
                            Spacer()
                        }
                        Text("competition.cardselect.choose")
                            .font(.system(size: 25))
                            .foregroundStyle(.white)
                        Spacer()
                        if !userManager.user.isVip {
                            HStack {
                                Image("vip_icon_on")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 18)
                                Text("competition.cardselect.subscription")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.secondText)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.8))
                            .cornerRadius(10)
                            .exclusiveTouchTapGesture {
                                appState.navigationManager.append(.subscriptionDetailView)
                            }
                        }
                    }
                    .padding(.top, 50)
                    .padding(.bottom, 10)
                    
                    VStack {
                        // 卡牌位
                        if userManager.user.isVip {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 20) {
                                    ForEach(appState.competitionManager.selectedCards) { card in
                                        MagicCardView(card: card)
                                            .frame(width: cardWidth)
                                    }
                                    ForEach(appState.competitionManager.selectedCards.count..<maxCards, id: \.self) { index in
                                        if index == 3 {
                                            EmptyCardVipSlot()
                                                .frame(width: cardWidth)
                                        } else {
                                            EmptyCardSlot()
                                                .frame(width: cardWidth)
                                        }
                                    }
                                }
                                .padding(2)
                            }
                            .padding(.bottom)
                        } else {
                            HStack(spacing: 20) {
                                ForEach(appState.competitionManager.selectedCards) { card in
                                    MagicCardView(card: card)
                                    //.frame(width: cardWidth)
                                }
                                ForEach(appState.competitionManager.selectedCards.count..<maxCards, id: \.self) { index in
                                    EmptyCardSlot()
                                }
                            }
                            .padding(.bottom)
                        }
                        
                        Text("competition.cardselect.action.choose")
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .foregroundColor(.white)
                            .background(Color.white.opacity(0.5))
                            .cornerRadius(12)
                            .exclusiveTouchTapGesture {
                                showCardSelection = true
                            }
                            .disabled(appState.competitionManager.isRecording)
                    }
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    
                    HStack(spacing: 4) {
                        Image("healthkit")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20)
                        Text("competition.cardselect.healthkit.title")
                        Image(systemName: "info.circle")
                            .exclusiveTouchTapGesture {
                                PopupWindowManager.shared.presentPopup(
                                    title: "competition.cardselect.healthkit.title",
                                    message: "competition.cardselect.healthkit.content",
                                    bottomButtons: [
                                        .confirm(),
                                        .confirm("action.detail") {
                                            appState.navigationManager.append(.privacyPanelView)
                                        }
                                    ]
                                )
                            }
                        Spacer()
                    }
                    .foregroundStyle(Color.thirdText)
                    .font(.subheadline)
                    
                    HStack {
                        Text("competition.cardselect.action.next_step")
                        Image(systemName: "arrowshape.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .background(Color.orange)
                    .cornerRadius(12)
                    .padding(.top, 50)
                    .exclusiveTouchTapGesture {
                        appState.competitionManager.loadMatchEnv()
                    }
                    .disabled(appState.competitionManager.isRecording)
                }
                .padding()
            }
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.defaultBackground)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .onFirstAppear {
            // 如果是组队模式，启动计时器a
            if appState.competitionManager.isTeam {
                appState.competitionManager.startTeamJoinTimerA()
            }
            if appState.competitionManager.sport == .Bike {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.event.precautions",
                    message: "competition.cardselect.popup.content.bike",
                    doNotShowAgainKey: "CompetitionCardSelectView.phone_pos.bike",
                    bottomButtons: [
                        .confirm()
                    ]
                )
            } else if appState.competitionManager.sport == .Running {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.event.precautions",
                    message: "competition.cardselect.popup.content.running",
                    doNotShowAgainKey: "CompetitionCardSelectView.phone_pos.running",
                    bottomButtons: [
                        .confirm()
                    ]
                )
            }
            queryTrackFamiliarity()
            queryTrainingState()
        }
        .bottomSheet(isPresented: $showCardSelection, size: .large, destroyOnDismiss: true) {
            CardSelectionView(showCardSelection: $showCardSelection)
        }
    }
    
    func queryTrackFamiliarity() {
        guard let sport = appState.competitionManager.sport else { return }
        var recordID: String = ""
        
        if sport == .Bike, let record = appState.competitionManager.currentBikeRecord {
            recordID = record.record_id
        } else if sport == .Running, let record = appState.competitionManager.currentRunningRecord {
            recordID = record.record_id
        } else {
            return
        }
        
        guard var components = URLComponents(string: "/competition/\(sport.rawValue)/query_record_familiarity") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: recordID)
        ]
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: Double.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        familiarityValue = unwrappedData
                    }
                }
            default: break
            }
        }
    }
    
    func queryTrainingState() {
        guard let sport = appState.competitionManager.sport else { return }
        
        guard let components = URLComponents(string: "/training/\(sport.rawValue)/training_states/me") else { return }
        guard let urlPath = components.url?.absoluteString else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: Int.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        stateValue = unwrappedData
                    }
                }
            default: break
            }
        }
    }
}



/*#Preview {
    let appState = AppState.shared
    let card = MagicCard(cardID: "qwe", name: "踏频仙人", sportType: .Bike, level: 5, levelSkill1: 2, levelSkill2: 3, levelSkill3: nil, imageURL: "Ads", sensorType: .heartSensor, sensorLocation: 7, lucky: 67.3, rarity: "A", description: "这是一段描述", descriptionSkill1: "技能1的描述", descriptionSkill2: "技能2的描述", descriptionSkill3: nil, version: AppVersion("1.0.0"), tags: ["team"], effectDef: MagicCardDef(cardID: "qwe", typeName: "pedal", params: .string("")))
    AssetManager.shared.magicCards.append(card)
    return CompetitionCardSelectView()
        .environmentObject(appState)
}*/
