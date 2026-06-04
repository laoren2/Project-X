//
//  RouteTrainingRealtimeView.swift
//  sportsx
//
//  Created by 任杰 on 2026/5/1.
//

import SwiftUI
import MapKit

struct RouteTrainingRealtimeView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var dataFusionManager = DataFusionManager.shared
    @ObservedObject var locationManager = LocationManager.shared
    @State private var chevronDirection: Bool = true
    @State private var chevronDirection2: Bool = true
    
    @State private var mapFrame: CGRect = .zero
    @State private var sheetHeight: CGFloat = 550
    @State private var mapMode: MapViewMode = .followUser
    
    
    // 定义两列布局
    let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    // 动态构建 items 数组
    var items: [(String, String, String, Color)] {
        var temp: [(String, String, String, Color)] = []
        let data = appState.competitionManager.realtimeStatisticData
        
        // 距离
        temp.append(("competition.realtime.distance", String(format: "%.2f ", data.distance / 1000), "distance.km", Color.orange))
        // 均速
        temp.append(("competition.realtime.avgspeed", appState.competitionManager.sport == .Bike ? String(format: "%.1f ", data.avgSpeed) : SpeedHelper.paceString(from: data.avgSpeed), appState.competitionManager.sport == .Bike ? "speed.km/h" : "/km", Color.yellow))
        // 累计爬升
        temp.append(("competition.realtime.elev_gain", String(format: "%.1f ", data.elevationGain), "distance.m", Color.purple))
        // 心率
        if let heartRate = data.heartRate {
            temp.append(("competition.realtime.heartrate", "\(Int(heartRate)) ", "heartrate.unit", Color.red))
        }
        // 能耗
        if let energy = data.totalEnergy {
            temp.append(("competition.realtime.energy", "\(Int(energy)) ", "energy.unit", Color.blue))
        }
        // 功率
        if let power = data.power {
            temp.append(("competition.realtime.power", "\(Int(power)) ", "power.unit", Color.green))
        }
        // 步频
        if let stepCadence = data.stepCadence {
            temp.append(("competition.result.stepcadence", "\(Int(stepCadence)) ", "stepCadence.unit", Color.pink))
        }
        return temp
    }
    
    private var currentRouteData: (
        routePoints: [RoutePointRealtime],
        routeType: RouteType
    )? {
        switch appState.competitionManager.sportFeature {
        case .bikeRouteTraining:
            guard let route = appState.competitionManager.currentBikeRoute else {
                return nil
            }
            return (
                route.routePoints,
                route.routeType
            )

        case .runningRouteTraining:
            guard let route = appState.competitionManager.currentRunningRoute else {
                return nil
            }
            return (
                route.routePoints,
                route.routeType
            )

        default:
            return nil
        }
    }
    
    var body: some View {
        //let _ = Self._printChanges()
        // 显示实时比赛数据
        ZStack(alignment: .bottom) {
            ZStack {
                if let route = currentRouteData {
                    RouteRealtimeMapView(
                        routePoints: route.routePoints,
                        routeType: route.routeType,
                        path: appState.competitionManager.basePathData,
                        nextRoutePointIndex: appState.competitionManager.nextCheckPointIndex,
                        mapMode: $mapMode,
                        userLocation: appState.competitionManager.userLocation,
                        isShowSheet: !chevronDirection
                    )
                    .ignoresSafeArea()
                }
                
                VStack(spacing: 20) {
                    HStack(alignment: .top) {
                        Button(action: { adjustNavigationPath() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20))
                                .bold()
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // 底部 sheet
            VStack {
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(mapMode == .overview ? Color.defaultBackground : Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(mapMode == .overview ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        Image("location2")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 25, height: 25)
                    }
                    .contentShape(Circle())
                    .exclusiveTouchTapGesture {
                        mapMode = .overview
                    }
                }
                .padding(.horizontal)
                
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(mapMode == .followUser ? Color.defaultBackground : Color.black.opacity(0.6))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle()
                                    .stroke(mapMode == .followUser ? Color.orange : Color.clear, lineWidth: 2)
                            )
                        Image("location")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    .contentShape(Circle())
                    .exclusiveTouchTapGesture {
                        mapMode = .followUser
                    }
                }
                .padding(.horizontal)
                
                ZStack {
                    HStack {
                        if let sport = appState.competitionManager.sport {
                            Image(sport.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 20)
                                .padding(6)
                                .background(Color.black.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        Spacer()
                        HStack(spacing: 2) {
                            if let feature = appState.competitionManager.sportFeature {
                                Image(feature.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 20)
                            }
                            Text(appState.competitionManager.isTeam ? "competition.register.team" : "competition.register.single")
                        }
                        .foregroundStyle(Color.white)
                        .padding(6)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    
                    HStack(alignment: .top, spacing: 5) {
                        Text("GPS")
                            .foregroundStyle(Color.white)
                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<4) { index in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(index < locationManager.signalStrength.bars ? locationManager.signalStrength.color : Color.white.opacity(0.3))
                                    .frame(width: 6, height: CGFloat(6 + index * 4))
                            }
                        }
                    }
                    .padding(6)
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(.horizontal)
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Image(systemName: chevronDirection2 ? "chevron.up" : "chevron.down")
                            .foregroundStyle(Color.white)
                            .bold()
                        //.padding(.vertical, 10)
                            .frame(height: 30)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .exclusiveTouchTapGesture {
                        chevronDirection2.toggle()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation(.easeIn(duration: 0.2)) {
                                chevronDirection.toggle()
                            }
                        }
                    }
                    if let route = currentRouteData, route.routeType == .multiPoints, appState.competitionManager.isRecording {
                        let checkPoints = route.routePoints.filter {
                            if case .checkpoint = $0 { return true }
                            return false
                        }.count - 2
                        let checkedPoints = min(max(route.routePoints.filter {
                            if case .checkpoint(let cp) = $0 {
                                return cp.isCheck
                            }
                            return false
                        }.count - 1, 0), checkPoints)
                        ZStack {
                            ProgressBar(progress: Double(checkedPoints) / Double(checkPoints))
                                .frame(height: 20)
                            Text("checked \(checkedPoints) / \(checkPoints)")
                                .foregroundStyle(Color.white)
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                        }
                        .padding(.horizontal)
                    }
                    ScrollView {
                        VStack(spacing: 20) {
                            if !appState.competitionManager.isRecording && !appState.competitionManager.isInValidArea {
                                Text("competition.realtime.start.out_of_area")
                                    .foregroundStyle(Color.thirdText)
                            }
                            HStack(spacing: 20) {
                                let isGray = (!appState.competitionManager.isInValidArea) || locationManager.signalStrength.bars < 2
                                if appState.competitionManager.isRecording {
                                    HStack(spacing: 10) {
                                        Text("\(TimeDisplay.formattedTime(dataFusionManager.elapsedTime))")
                                            .font(.system(size: 35, weight: .heavy, design: .rounded))
                                        
                                        VStack(spacing: 10) {
                                            let bonusTime = appState.competitionManager.matchContext.bonusEachCards.reduce(0) { result, item in
                                                guard item.bonus_time > 0 else {
                                                    return result
                                                }
                                                return result + item.bonus_time
                                            }
                                            Text("- \(Int(bonusTime))s")
                                                .foregroundStyle(Color.green)
                                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 10)
                                            
                                            if let route = currentRouteData, route.routeType == .multiPoints {
                                                let penaltyTime: Int = {
                                                    guard let lastCheckedIndex = route.routePoints.lastIndex(where: {
                                                        if case .checkpoint(let cp) = $0 {
                                                            return cp.isCheck
                                                        }
                                                        return false
                                                    }) else { return 0 }
                                                    return route.routePoints[0..<lastCheckedIndex].reduce(0) { result, point in
                                                        guard case .checkpoint(let cp) = point,
                                                              !cp.isCheck else {
                                                            return result
                                                        }
                                                        return result + (cp.penalty ?? 0)
                                                    }
                                                }()
                                                
                                                Text("+ \(penaltyTime)s")
                                                    .foregroundStyle(Color.pink)
                                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                                    .padding(.horizontal, 10)
                                            } else {
                                                Text("+ 0s")
                                                    .foregroundStyle(Color.pink)
                                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                                    .padding(.horizontal, 10)
                                            }
                                        }
                                    }
                                    .foregroundStyle(Color.white)
                                    
                                    // 背景按钮
                                    Text("training.realtime.action.finish")
                                        .foregroundColor(.white)
                                        .font(.system(size: 20))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 20)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                        .exclusiveTouchTapGesture {
                                            PopupWindowManager.shared.presentPopup(
                                                title: "training.realtime.action.finish",
                                                message: "training.realtime.popup.finish",
                                                bottomButtons: [
                                                    .cancel(),
                                                    .confirm() {
                                                        appState.competitionManager.stopRouteTraining()
                                                    }
                                                ]
                                            )
                                        }
                                } else {
                                    Spacer()
                                    Text("competition.realtime.action.start")
                                        .font(.title)
                                        .foregroundColor(.white)
                                        .frame(width: 100, height: 100)
                                        .background(isGray ? Color.gray : Color.green)
                                        .clipShape(Circle())
                                        .exclusiveTouchTapGesture {
                                            startTraining()
                                        }
                                    Spacer()
                                }
                            }
                            if appState.competitionManager.isRecording {
                                LazyVGrid(columns: columns, spacing: 16) {
                                    ForEach(items, id: \.0) { title, value, unit, color in
                                        VStack {
                                            Text(LocalizedStringKey(title))
                                                .font(.headline)
                                            (Text(value) + Text(LocalizedStringKey(unit)))
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity, minHeight: 80)
                                        .background(color.opacity(0.8))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("competition.realtime.card.benefit")
                                            .font(.title2)
                                            .bold()
                                            .foregroundStyle(Color.secondText)
                                            .padding(.horizontal)
                                        Spacer()
                                    }
                                    if !appState.competitionManager.selectedCards.isEmpty {
                                        ForEach(appState.competitionManager.selectedCards) { card in
                                            HStack(spacing: 16) {
                                                MagicCardView(card: card)
                                                    .frame(width: 60)
                                                VStack(alignment: .leading) {
                                                    Spacer()
                                                    Text(card.name)
                                                        .font(.headline)
                                                        .bold()
                                                        .foregroundStyle(Color.secondText)
                                                    Spacer()
                                                    if let index = appState.competitionManager.matchContext.bonusEachCards.firstIndex(where: { $0.card_id == card.cardID }) {
                                                        (Text("competition.realtime.card.time") + Text(": ") + Text(TimeDisplay.formattedTime( appState.competitionManager.matchContext.bonusEachCards[index].bonus_time, showFraction: true)))
                                                            .font(.subheadline)
                                                            .foregroundStyle(Color.white)
                                                        Spacer()
                                                    } else {
                                                        (Text("competition.realtime.card.time") + Text(": 00.00"))
                                                            .font(.subheadline)
                                                            .foregroundStyle(Color.secondText)
                                                        Spacer()
                                                    }
                                                }
                                                Spacer()
                                            }
                                            .padding()
                                            .cornerRadius(12)
                                            .padding(.horizontal)
                                        }
                                    } else {
                                        Text("competition.realtime.card.no_cards")
                                            .foregroundStyle(Color.secondText)
                                            .padding(.top, 50)
                                    }
                                }
                                .padding(.bottom, 50)
                            }
                        }
                        .padding(.top, 10)
                    }
                    .frame(height: 450)
                }
                .background(Color.black.opacity(0.8))
                .clipShape(.rect(topLeadingRadius: 20, topTrailingRadius: 20))
            }
            .offset(y: chevronDirection ? 300 : 0)
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBackGesture(false)
        .alert(isPresented: $appState.competitionManager.showAlert) {
            Alert(
                title: Text(LocalizedStringKey(appState.competitionManager.alertTitle)),
                message: Text(LocalizedStringKey(appState.competitionManager.alertMessage)),
                dismissButton: .default(Text("action.confirm"))
            )
        }
        .onStableAppear() {
            DispatchQueue.main.async {
                appState.competitionManager.isShowWidget = false
            }
            appState.competitionManager.requestLocationAlwaysAuthorization()
            if !appState.competitionManager.isRecording {
                LocationManager.shared.changeToMediumUpdate()
                appState.competitionManager.setupRouteTrainingLocationSubscription()
            }
        }
        .onStableDisappear() {
            DispatchQueue.main.async {
                appState.competitionManager.isShowWidget = appState.competitionManager.isRecording
            }
            if !appState.competitionManager.isRecording {
                appState.competitionManager.deleteRouteTrainingLocationSubscription()
            }
        }
    }
    
    private func startTraining() {
        if appState.competitionManager.sportFeature == .bikeRouteTraining {
            guard let route = appState.competitionManager.currentBikeRoute else {
                let toast = Toast(message: "competition.realtime.start.toast.record_error")
                ToastManager.shared.show(toast: toast)
                return
            }
        } else if appState.competitionManager.sportFeature == .runningRouteTraining {
            guard let route = appState.competitionManager.currentRunningRoute else {
                let toast = Toast(message: "competition.realtime.start.toast.record_error")
                ToastManager.shared.show(toast: toast)
                return
            }
        } else {
            let toast = Toast(message: "competition.realtime.start.toast.sport_not_support")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        // 检查精确位置权限
        guard locationManager.checkPreciseLocation() else {
            DispatchQueue.main.async {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.realtime.precise_location.popup.title",
                    message: "competition.realtime.precise_location.popup.content",
                    bottomButtons: [.confirm()]
                )
            }
            return
        }
        
        // 检查是否在出发区域内
        guard appState.competitionManager.isInValidArea else {
            let toast = Toast(message: "competition.realtime.start.out_of_area")
            ToastManager.shared.show(toast: toast)
            return
        }
        
        for (pos, dev) in DeviceManager.shared.deviceMap {
            if let device = dev, (appState.competitionManager.sensorRequest & (1 << (pos.rawValue + 1))) != 0 {
                if !device.connect() {
                    let toast = Toast(message: "competition.realtime.start.toast.sensor_unbind")
                    ToastManager.shared.show(toast: toast)
                    return
                }
            }
        }
        
        if !appState.competitionManager.isRecording {
            appState.competitionManager.startRouteTraining()
        }
    }
    
    private func adjustNavigationPath() {
        if !appState.competitionManager.isRecording {
            appState.navigationManager.removeLast()
        } else {
            var indexToLast = 1
            if let index = appState.navigationManager.path.firstIndex(where: { $0.string == "competitionCardSelectView" }) {
                indexToLast = appState.navigationManager.path.count - index
            }
            let lastToRemove = max(1, indexToLast)
            appState.navigationManager.removeLast(lastToRemove)
        }
    }
}



class RoutePointRealtimeAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let type: EditableCheckPointType
    var checkStatus: Bool
    var missStatus: Bool
    var isNext: Bool
    var distance: Double?
    
    init(
        coordinate: CLLocationCoordinate2D,
        type: EditableCheckPointType,
        checkStatus: Bool,
        missStatus: Bool,
        isNext: Bool
    ) {
        self.coordinate = coordinate
        self.type = type
        self.checkStatus = checkStatus
        self.missStatus = missStatus
        self.isNext = isNext
    }
}

class RoutePointRealtimeAnnotationView: MKAnnotationView {
    // Cached state properties
    private var lastIsNext: Bool = false
    private var lastCheckStatus: Bool = false
    private var lastMissStatus: Bool = false
    private var lastDistance: Double?
    private var didSetupBaseUI: Bool = false
    private let distanceLabel = UILabel()
    private var didSetupDistanceLabel: Bool = false
    
    override var annotation: MKAnnotation? {
        didSet {
            guard let ann = annotation as? RoutePointRealtimeAnnotation else { return }
            setup(for: ann)
        }
    }
    
    private func setupDistanceLabelIfNeeded() {
        guard !didSetupDistanceLabel else { return }

        distanceLabel.tag = 999
        distanceLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        distanceLabel.textColor = .white
        distanceLabel.textAlignment = .center
        distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        distanceLabel.layer.cornerRadius = 4
        distanceLabel.clipsToBounds = true
        distanceLabel.isHidden = true

        self.addSubview(distanceLabel)
        didSetupDistanceLabel = true
    }

    
    private func setup(for ann: RoutePointRealtimeAnnotation) {
        //print("setup annotations")
        // 1. Detect state changes
        let isStateChanged = (ann.checkStatus != lastCheckStatus) || (ann.missStatus != lastMissStatus) || !didSetupBaseUI
        let isNextChanged = (ann.isNext != lastIsNext)
        let distanceChanged: Bool = {
            guard let new = ann.distance, let old = lastDistance else {
                return ann.distance != lastDistance
            }
            let threshold: Double = new < 1000 ? 1.0 : 10.0
            return abs(new - old) > threshold
        }()

        // 2. Setup/reset base UI if needed
        if isStateChanged {
            self.subviews.forEach {
                if $0 !== distanceLabel {
                    $0.removeFromSuperview()
                }
            }

            let size: CGFloat = 24
            self.frame = CGRect(x: 0, y: 0, width: size, height: size)
            self.layer.cornerRadius = size / 2
            self.layer.masksToBounds = false

            switch ann.type {
            case .start:
                self.backgroundColor = .systemGreen
                self.layer.borderColor = UIColor.white.cgColor
                self.layer.borderWidth = 2

            case .end:
                self.backgroundColor = .systemRed
                self.layer.borderColor = UIColor.white.cgColor
                self.layer.borderWidth = 2

            case .checkPoint(let index):
                self.backgroundColor = .white
                self.layer.borderColor = ann.checkStatus ? UIColor.systemGreen.cgColor : (ann.missStatus ? UIColor.systemPink.cgColor : UIColor.systemOrange.cgColor)
                self.layer.borderWidth = 2

                let label = UILabel(frame: self.bounds)
                label.text = "\(index)"
                label.textAlignment = .center
                label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
                label.textColor = ann.checkStatus ? .systemGreen : (ann.missStatus ? .systemPink : .systemOrange)

                self.addSubview(label)
            }

            didSetupBaseUI = true
            setupDistanceLabelIfNeeded()
        }

        // 3. Handle next state and distance label
        if ann.isNext {
            if isNextChanged {
                let animation = CABasicAnimation(keyPath: "transform.scale")
                animation.fromValue = 1.0
                animation.toValue = 1.3
                animation.duration = 1.0
                animation.autoreverses = true
                animation.repeatCount = .infinity
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                self.layer.add(animation, forKey: "breathing")
            }

            if distanceChanged || isNextChanged {
                setupDistanceLabelIfNeeded()

                if let distance = ann.distance {
                    distanceLabel.isHidden = false
                    distanceLabel.text = formatDistance(distance)
                    distanceLabel.sizeToFit()
                    distanceLabel.frame = CGRect(
                        x: (self.bounds.width - distanceLabel.bounds.width) / 2,
                        y: -distanceLabel.bounds.height - 6,
                        width: distanceLabel.bounds.width + 8,
                        height: distanceLabel.bounds.height + 2
                    )
                }
            }
        } else {
            if isNextChanged {
                self.layer.removeAnimation(forKey: "breathing")
                self.transform = .identity
                distanceLabel.isHidden = true
            }
        }

        // 4. Update cached state
        lastIsNext = ann.isNext
        lastCheckStatus = ann.checkStatus
        lastMissStatus = ann.missStatus
        if distanceChanged || isNextChanged {
            lastDistance = ann.distance
        }
    }
    
    func updateUI() {
        guard let ann = annotation as? RoutePointRealtimeAnnotation else { return }
        setup(for: ann)
    }
    
    func formatDistance(_ d: Double) -> String {
        if d < 1000 {
            return "\(Int(d))m"
        } else {
            return String(format: "%.1fkm", d / 1000)
        }
    }
}

struct RouteRealtimeMapView: UIViewRepresentable {
    let routePoints: [RoutePointRealtime]
    let routeType: RouteType
    let path: [PathPoint]
    let nextRoutePointIndex: Int?
    @Binding var mapMode: MapViewMode
    let userLocation: CLLocation?  // 用于跟随模式
    let coords: [CLLocationCoordinate2D]
    let isShowSheet: Bool

    init(
        routePoints: [RoutePointRealtime],
        routeType: RouteType,
        path: [PathPoint],
        nextRoutePointIndex: Int?,
        mapMode: Binding<MapViewMode>,
        userLocation: CLLocation?,
        isShowSheet: Bool
    ) {
        self.routePoints = routePoints
        self.routeType = routeType
        self.path = path
        self.nextRoutePointIndex = nextRoutePointIndex
        self._mapMode = mapMode
        self.userLocation = userLocation
        self.isShowSheet = isShowSheet

        var tempCoords: [CLLocationCoordinate2D] = []
        for point in routePoints {
            if case .checkpoint(let cp) = point {
                tempCoords.append(CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng)))
            }
        }
        self.coords = tempCoords
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        mapView.pointOfInterestFilter = .excludingAll
        
        context.coordinator.lastPointCount = 0
        context.coordinator.hasInitialized = false
        
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserPan))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserGesture))
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)
        
        context.coordinator.mapView = mapView
        context.coordinator.start()
        
        
        let arrowContainer = UIView(frame: mapView.bounds)
        arrowContainer.isUserInteractionEnabled = false

        let imageView = UIImageView(image: UIImage(systemName: "arrow.up"))
        imageView.tintColor = .orange
        imageView.frame = CGRect(x: 0, y: 0, width: 24, height: 24)

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true

        arrowContainer.addSubview(imageView)
        arrowContainer.addSubview(label)

        mapView.addSubview(arrowContainer)

        context.coordinator.arrowContainer = arrowContainer
        context.coordinator.arrowImageView = imageView
        context.coordinator.distanceLabel = label
        
        imageView.isHidden = true
        label.isHidden = true
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard routePoints.first != nil else { return }
        
        context.coordinator.currentUserLocation = userLocation
        context.coordinator.currentNextIndex = nextRoutePointIndex
        context.coordinator.currentRoutePoints = routePoints
        context.coordinator.isShowSheet = isShowSheet
        
        // 初始化（只执行一次）
        if !context.coordinator.hasInitialized {
            var annotations: [RoutePointRealtimeAnnotation] = []
            var circles: [MKCircle] = []

            for (index, point) in routePoints.enumerated() {
                if case .checkpoint(let cp) = point {
                    let coord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng))

                    let type: EditableCheckPointType
                    if index == 0 {
                        type = .start
                    } else if index == routePoints.count - 1 {
                        type = .end
                    } else {
                        type = .checkPoint(index)
                    }

                    let ann = RoutePointRealtimeAnnotation(
                        coordinate: coord,
                        type: type,
                        checkStatus: cp.isCheck,
                        missStatus: cp.isMiss,
                        isNext: index == nextRoutePointIndex
                    )
                    annotations.append(ann)

                    let circle = MKCircle(center: coord, radius: cp.radius)
                    circles.append(circle)
                }
            }

            mapView.addAnnotations(annotations)
            mapView.addOverlays(circles)

            context.coordinator.checkpointAnnotations = annotations
            context.coordinator.checkpointCircles = circles
            context.coordinator.hasInitialized = true
        } else {
            for (index, point) in routePoints.enumerated() {
                guard case .checkpoint(let cp) = point else { continue }
                guard index < context.coordinator.checkpointAnnotations.count else { continue }

                let ann = context.coordinator.checkpointAnnotations[index]
                let newIsNext = index == nextRoutePointIndex

                if ann.checkStatus != cp.isCheck || ann.isNext != newIsNext || ann.missStatus != cp.isMiss {
                    ann.checkStatus = cp.isCheck
                    ann.missStatus = cp.isMiss
                    ann.isNext = newIsNext

                    if let view = mapView.view(for: ann) as? RoutePointRealtimeAnnotationView {
                        view.updateUI()
                    }
                }
                
                if let userLocation = userLocation, ann.isNext {
                    let user = CLLocation(latitude: userLocation.coordinate.latitude,
                                          longitude: userLocation.coordinate.longitude)

                    let target = CLLocation(latitude: cp.lat, longitude: cp.lng)
                    let distance = user.distance(from: target)

                    ann.distance = distance
                    if let view = mapView.view(for: ann) as? RoutePointRealtimeAnnotationView {
                        view.updateUI()
                    }
                    //print(distance)
                }

                // 更新 circle 渲染
                if index < context.coordinator.checkpointCircles.count {
                    let circle = context.coordinator.checkpointCircles[index]
                    if let renderer = mapView.renderer(for: circle) as? MKCircleRenderer {
                        renderer.fillColor = cp.isCheck ? UIColor.systemGreen.withAlphaComponent(0.2) : (cp.isMiss ? UIColor.systemPink.withAlphaComponent(0.2) : UIColor.systemOrange.withAlphaComponent(0.2))
                        renderer.strokeColor = cp.isCheck ? UIColor.systemGreen.withAlphaComponent(0.6) : (cp.isMiss ? UIColor.systemPink.withAlphaComponent(0.6) : UIColor.systemOrange.withAlphaComponent(0.6))
                    }
                }
            }
        }

        switch mapMode {
        case .overview:
            guard context.coordinator.lastMode != .overview || context.coordinator.lastIsShowSheet != isShowSheet else { break }
            //print("switch to overview")
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            let rect = polyline.boundingMapRect
            let padding = UIEdgeInsets(top: isShowSheet ? 20 : 50, left: 50, bottom: isShowSheet ? 550 : 250, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
            context.coordinator.lastIsShowSheet = isShowSheet
        case .followUser:
            if let userLocation = userLocation {
                //print("switch to followuser")
                let center = CoordinateConverter.parseCoordinate(coordinate: userLocation.coordinate)
                // 固定 100m 半径（200m x 200m rect）
                let meters: Double = 100
                let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(center.latitude)
                let halfSize = meters * mapPointsPerMeter
                let centerPoint = MKMapPoint(center)
                let rect = MKMapRect(
                    x: centerPoint.x - halfSize,
                    y: centerPoint.y - halfSize,
                    width: halfSize * 2,
                    height: halfSize * 2
                )
                // padding 决定用户在屏幕中的位置
                //let insets = mapView.safeAreaInsets
                let padding = UIEdgeInsets(
                    top: 20,
                    left: 40,
                    bottom: (isShowSheet ? 550 : 250),
                    right: 40
                )
                mapView.setVisibleMapRect(
                    rect,
                    edgePadding: padding,
                    animated: true
                )
            }
        case .manual:
            //print("switch to manual")
            break
        }
        if context.coordinator.lastMode != mapMode {
            context.coordinator.lastMode = mapMode
        }

        guard path.count > 1 else { return }
        // 检查是否有新点添加
        let lastCount = context.coordinator.lastPointCount
        if path.count > lastCount + 1 {
            // 多个新点：批量更新
            let newPoints = Array(path[lastCount...])
            addPolylineSegment(to: mapView, from: newPoints)
        } else if path.count == lastCount + 1 {
            // 单个新点：增量更新
            let segment = Array(path.suffix(2))
            addPolylineSegment(to: mapView, from: segment)
        } else if path.count < lastCount {
            // 如果路径被重置，清除所有overlay
            mapView.removeOverlays(mapView.overlays)
            if let firstPolyline = makePolyline(from: path) {
                mapView.addOverlay(firstPolyline)
                mapView.setVisibleMapRect(firstPolyline.boundingMapRect, edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40), animated: false)
            }
        }
        context.coordinator.lastPointCount = path.count
    }
    
    private func addPolylineSegment(to mapView: MKMapView, from segment: [PathPoint]) {
        guard segment.count >= 2 else { return }
        
        var coords = segment.map {
            CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
        }
        let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
        polyline.speeds = segment.map { $0.speed }
        mapView.addOverlay(polyline)
    }
    
    private func makePolyline(from path: [PathPoint]) -> SpeedPolyline? {
        guard !path.isEmpty else { return nil }
        var coords = path.map {
            CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
        }
        let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
        polyline.speeds = path.map { $0.speed }
        return polyline
    }
    
    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) {
        coordinator.stop()
        coordinator.arrowContainer?.removeFromSuperview()
        coordinator.arrowContainer = nil
        coordinator.arrowImageView = nil
        coordinator.distanceLabel = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: RouteRealtimeMapView
        // 缓存
        var lastPointCount: Int = 0
        var lastMode: MapViewMode = .followUser
        
        var checkpointAnnotations: [RoutePointRealtimeAnnotation] = []
        var checkpointCircles: [MKCircle] = []
        var hasInitialized: Bool = false
        
        class DisplayLinkProxy {
            weak var target: RouteRealtimeMapView.Coordinator?
            init(target: RouteRealtimeMapView.Coordinator) {
                self.target = target
            }
            @objc func step() {
                target?.step()
            }
        }
        weak var mapView: MKMapView?
        var displayLink: CADisplayLink?
        var proxy: DisplayLinkProxy?
        
        var currentUserLocation: CLLocation?
        var currentNextIndex: Int?
        var currentRoutePoints: [RoutePointRealtime] = []
        var isShowSheet: Bool = false
        var lastIsShowSheet: Bool = false
        
        
        // Arrow overlay properties
        var arrowContainer: UIView?
        var arrowImageView: UIImageView?
        var distanceLabel: UILabel?
        
        init(_ parent: RouteRealtimeMapView) {
            self.parent = parent
        }
        
        @objc func onUserPan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began {
                if parent.mapMode != .manual {
                    parent.mapMode = .manual
                }
            }
        }

        @objc func onUserGesture(_ gesture: UIGestureRecognizer) {
            if gesture.state == .began {
                if parent.mapMode != .manual {
                    parent.mapMode = .manual
                }
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.2)
                renderer.strokeColor = UIColor.orange.withAlphaComponent(0.6)
                renderer.lineWidth = 2
                return renderer
            }
            if let polyline = overlay as? SpeedPolyline {
                return SpeedPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let identifier = "UserLocation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKUserLocationView
                    ?? MKUserLocationView(annotation: annotation, reuseIdentifier: identifier)

                view.annotation = annotation
                view.canShowCallout = false
                view.isEnabled = false

                return view
            }
            let view = RoutePointRealtimeAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.canShowCallout = false
            return view
        }
        
        func start() {
            proxy = DisplayLinkProxy(target: self)
            displayLink = CADisplayLink(target: proxy!, selector: #selector(DisplayLinkProxy.step))
            displayLink?.add(to: .main, forMode: .common)
        }
        
        func stop() {
            displayLink?.invalidate()
            displayLink = nil
            proxy = nil
        }

        @objc func step() {
            guard let mapView = mapView else { return }
            guard let nextIndex = currentNextIndex,
                  case .checkpoint(let cp) = parent.routePoints[nextIndex] else {
                
                return
            }

            let targetParseCoord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: cp.lat, longitude: cp.lng))
            
            let screenPoint = mapView.convert(targetParseCoord, toPointTo: mapView)
            let insets = mapView.safeAreaInsets

            let topInset = insets.top + 10
            let bottomInset = (isShowSheet ? 520 : 220) + insets.bottom

            let rect = CGRect(
                x: 20,
                y: topInset,
                width: mapView.bounds.width - 40,
                height: mapView.bounds.height - topInset - bottomInset - 10
            )

            let isInside = rect.contains(screenPoint)
            
            let visibleHeight = mapView.bounds.height - (isShowSheet ? 520 : 220)
            let center = CGPoint(
                x: mapView.bounds.midX,
                y: visibleHeight / 2
            )
            
            /*DispatchQueue.main.async {
                // Remove previous debug layers
                mapView.layer.sublayers?.removeAll(where: { $0.name == "debug_layer" })
                
                // Draw rect
                let rectLayer = CAShapeLayer()
                rectLayer.name = "debug_layer"
                rectLayer.frame = mapView.bounds
                rectLayer.strokeColor = UIColor.red.cgColor
                rectLayer.fillColor = UIColor.clear.cgColor
                rectLayer.lineWidth = 2
                rectLayer.path = UIBezierPath(rect: rect).cgPath
                mapView.layer.addSublayer(rectLayer)
                
                // Draw line from center to screenPoint
                let linePath = UIBezierPath()
                linePath.move(to: center)
                linePath.addLine(to: screenPoint)
                
                let lineLayer = CAShapeLayer()
                lineLayer.name = "debug_layer"
                lineLayer.frame = mapView.bounds
                lineLayer.strokeColor = UIColor.blue.cgColor
                lineLayer.lineWidth = 2
                lineLayer.path = linePath.cgPath
                mapView.layer.addSublayer(lineLayer)
                
                // Draw screenPoint
                let pointLayer = CAShapeLayer()
                pointLayer.name = "debug_layer"
                pointLayer.frame = mapView.bounds
                pointLayer.fillColor = UIColor.green.cgColor
                pointLayer.path = UIBezierPath(ovalIn: CGRect(x: screenPoint.x - 4, y: screenPoint.y - 4, width: 8, height: 8)).cgPath
                mapView.layer.addSublayer(pointLayer)
            }*/
            
            let dx = screenPoint.x - center.x
            let dy = screenPoint.y - center.y
            let angle = atan2(dx, -dy)
            var edgePoint = screenPoint

            if !isInside {
                let scaleX = dx == 0 ? CGFloat.infinity :
                    (dx > 0 ? (rect.maxX - center.x)/dx : (rect.minX - center.x)/dx)
                let scaleY = dy == 0 ? CGFloat.infinity :
                    (dy > 0 ? (rect.maxY - center.y)/dy : (rect.minY - center.y)/dy)
                let scale = min(scaleX, scaleY)
                edgePoint = CGPoint(
                    x: center.x + dx * scale,
                    y: center.y + dy * scale
                )
            }
            
            guard let userLocation = currentUserLocation else { return }
            let targetLoc = CLLocation(latitude: cp.lat, longitude: cp.lng)
            let distance = userLocation.distance(from: targetLoc)
            
            guard let arrow = arrowImageView,
                  let label = distanceLabel else { return }

            arrow.center = edgePoint
            arrow.transform = CGAffineTransform(rotationAngle: angle)

            let text: String
            text = DistanceHelper.paceString(from: distance / 1000)
            
            label.text = text
            label.sizeToFit()
            label.frame = CGRect(
                x: edgePoint.x - label.bounds.width / 2 - 4,
                y: edgePoint.y + 14,
                width: label.bounds.width + 8,
                height: label.bounds.height + 4
            )

            arrow.isHidden = isInside
            label.isHidden = isInside
            
            if let ann = checkpointAnnotations.first(where: { $0.isNext }) {
                ann.distance = distance
                if let view = mapView.view(for: ann) as? RoutePointRealtimeAnnotationView {
                    view.updateUI()
                }
            }
        }
    }
}

#Preview {
    let appState = AppState.shared
    appState.competitionManager.isRecording = true
    return RouteTrainingRealtimeView()
        .environmentObject(appState)
}
