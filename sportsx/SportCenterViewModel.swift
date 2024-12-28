//
//  SportCenterViewModel.swift
//  sportsx
//
//  Created by 任杰 on 2024/12/28.
//

import Foundation


class PVPTrainingViewModel: ObservableObject {
    @Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }
}

class RVRTrainingViewModel: ObservableObject {
    @Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }
}

class RVRCompetitionViewModel: ObservableObject {
    @Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }
}

class PVPCompetitionViewModel: ObservableObject {
    @Published var sport: SportName
    var category: SportCategory { sport.category }
    
    init(sport: SportName) {
        self.sport = sport
    }
}
