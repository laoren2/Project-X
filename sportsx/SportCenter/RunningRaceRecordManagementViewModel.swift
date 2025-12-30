//
//  RunningRaceRecordManagementViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/5.
//

import Foundation
//import SwiftUI
import Combine

class RunningRaceRecordManagementViewModel: ObservableObject {
    let user = UserManager.shared
    private let assetManager = AssetManager.shared
    private let competitionManager = CompetitionManager.shared
    private let navigationManager = NavigationManager.shared

    @Published var selectedTab: Int = 0  // 0: 未完成, 1: 已完成
    // 比赛记录
    @Published var records: [RunningRaceRecord] = []
    // 未完成的比赛
    @Published var incompleteRecords: [RunningRaceRecord] = []
    // 已完成的比赛
    @Published var completedRecords: [RunningRaceRecord] = []
    
    var hasMoreIncompleteRecords: Bool = true
    var hasMoreCompletedRecords: Bool = true
    var incompletePage: Int = 1
    var completedPage: Int = 1
    let pageSize: Int = 10
    
    @Published var isIncompleteLoading: Bool = false
    @Published var isCompletedLoading: Bool = false
    
    
    @MainActor
    func queryIncompleteRecords(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            incompleteRecords.removeAll()
            incompletePage = 1
        }
        isIncompleteLoading = true
        
        guard var components = URLComponents(string: "/competition/running/query_incompleted_records") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(incompletePage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningRaceRecordResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        isIncompleteLoading = false
        
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for record in unwrappedData.records {
                    incompleteRecords.append(RunningRaceRecord(from: record))
                }
                if unwrappedData.records.count < self.pageSize {
                    hasMoreIncompleteRecords = false
                } else {
                    hasMoreIncompleteRecords = true
                    incompletePage += 1
                }
            }
        default: break
        }
    }
    
    @MainActor
    func queryCompletedRecords(withLoadingToast: Bool, reset: Bool) async {
        if reset {
            completedRecords.removeAll()
            completedPage = 1
        }
        isCompletedLoading = true
        
        guard var components = URLComponents(string: "/competition/running/query_completed_records") else { return }
        components.queryItems = [
            URLQueryItem(name: "page", value: "\(completedPage)"),
            URLQueryItem(name: "size", value: "\(pageSize)")
        ]
        guard let urlPath = components.string else { return }
        
        let request = APIRequest(path: urlPath, method: .get, requiresAuth: true)
        
        let result = await NetworkService.sendAsyncRequest(with: request, decodingType: RunningRaceRecordResponse.self, showLoadingToast: withLoadingToast, showErrorToast: true)
        
        await MainActor.run {
            isCompletedLoading = false
        }
        switch result {
        case .success(let data):
            if let unwrappedData = data {
                for record in unwrappedData.records {
                    completedRecords.append(RunningRaceRecord(from: record))
                }
                if unwrappedData.records.count < self.pageSize {
                    self.hasMoreCompletedRecords = false
                } else {
                    self.hasMoreCompletedRecords = true
                    self.completedPage += 1
                }
            }
        default: break
        }
    }
    
    func enterCompetitionLink(record: RunningRaceRecord) {
        guard var components = URLComponents(string: "/competition/running/enter_team_competition_link") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: record.record_id)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: EmptyResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success:
                // 进入比赛链路
                DispatchQueue.main.async {
                    self.competitionManager.resetRunningRaceRecord(record: record)
                    self.navigationManager.append(.competitionCardSelectView)
                }
            default: break
            }
        }
    }
    
    // 开始比赛
    func startCompetition(record: RunningRaceRecord) {
        guard !competitionManager.isRecording else {
            let toast = Toast(message: "比赛进行中，无法重复开始")
            ToastManager.shared.show(toast: toast)
            return
        }
        if record.isTeam {
            enterCompetitionLink(record: record)
        } else {
            guard let competitionDate = record.trackEndDate , Date() < competitionDate else {
                let toast = Toast(message: "不在比赛有效时间内")
                ToastManager.shared.show(toast: toast)
                return
            }
            // 进入比赛链路
            competitionManager.resetRunningRaceRecord(record: record)
            navigationManager.append(.competitionCardSelectView)
        }
    }
    
    // 取消比赛报名
    func cancelCompetition(record: RunningRaceRecord) {
        cancelRegister(record_id: record.record_id)
    }
    
    func cancelRegister(record_id: String) {
        guard var components = URLComponents(string: "/competition/running/cancel_register") else { return }
        components.queryItems = [
            URLQueryItem(name: "record_id", value: record_id)
        ]
        guard let urlPath = components.string else { return }
        let request = APIRequest(path: urlPath, method: .post, requiresAuth: true)
        
        NetworkService.sendRequest(with: request, decodingType: CPAssetResponse.self, showLoadingToast: true, showErrorToast: true) { result in
            switch result {
            case .success(let data):
                if let unwrappedData = data {
                    DispatchQueue.main.async {
                        self.assetManager.updateCPAsset(assetID: unwrappedData.asset_id, newBalance: unwrappedData.new_balance)
                    }
                }
                Task {
                    await self.queryIncompleteRecords(withLoadingToast: true, reset: true)
                }
            default: break
            }
        }
    }
    
    func feedback(record: RunningRaceRecord) {
        //print("对id: \(record.record_id) 提出疑问")
    }
}
