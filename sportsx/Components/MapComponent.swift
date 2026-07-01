//
//  MapComponent.swift
//  sportsx
//
//  Created by 任杰 on 2025/8/22.
//

import MapKit
import SwiftUI


enum MapViewMode {
    case overview      // 显示起点与终点
    case followUser    // 跟随用户位置
    case manual        // 用户拖动后的自由模式
}

// MARK: - Polyline with speeds
class SpeedPolyline: MKPolyline {
    var speeds: [Double] = []
}

// MARK: - Renderer
class SpeedPolylineRenderer: MKOverlayRenderer {
    let polyline: SpeedPolyline
    
    init(polyline: SpeedPolyline) {
        self.polyline = polyline
        super.init(overlay: polyline)
    }
    
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        guard polyline.pointCount > 1 else { return }
        
        let points = polyline.points()
        
        for i in 0..<(polyline.speeds.count - 1) {
            let p1 = point(for: points[i])
            let p2 = point(for: points[i + 1])
            
            let color1 = colorForSpeed(polyline.speeds[i])
            let color2 = colorForSpeed(polyline.speeds[i + 1])
            let colors = [color1.cgColor, color2.cgColor] as CFArray
            
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                         colors: colors,
                                         locations: [0.0, 1.0]) {
                context.saveGState()
                
                let path = CGMutablePath()
                path.move(to: p1)
                path.addLine(to: p2)
                
                context.addPath(path)
                context.setLineWidth(5 / zoomScale)
                context.setLineJoin(.round)
                context.setLineCap(.round)
                
                // 关键：每段独立clip
                context.replacePathWithStrokedPath()
                context.clip()
                
                context.drawLinearGradient(
                    gradient,
                    start: p1,
                    end: p2,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                )
                
                context.restoreGState()
            }
        }
    }
    
    private func colorForSpeed(_ speed: Double) -> UIColor {
        // 蓝(慢) → 绿 → 黄 → 红(快)
        let ratio = min(max(speed / 30.0, 0), 1)
        return UIColor(hue: (0.6 - 0.6 * ratio), saturation: 1, brightness: 1, alpha: 1)
    }
}

// MARK: - 比赛进行时的路径 Map 视图
struct RaceRealtimeMapView: UIViewRepresentable {
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D
    let startRadius: CLLocationDistance
    let endRadius: CLLocationDistance
    let path: [PathPoint]
    let isShowSheet: Bool
    @Binding var mapMode: MapViewMode       // 新增
    @Binding var userLocation: CLLocation?  // 用于跟随模式

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        
        let parseFromCoordinate = CoordinateConverter.parseCoordinate(coordinate: fromCoordinate)
        let parseToCoordinate = CoordinateConverter.parseCoordinate(coordinate: toCoordinate)
        context.coordinator.fromAnnotation.coordinate = parseFromCoordinate
        context.coordinator.toAnnotation.coordinate = parseToCoordinate
        mapView.addAnnotations([context.coordinator.fromAnnotation, context.coordinator.toAnnotation])
        let circle1 = MKCircle(center: parseFromCoordinate, radius: startRadius)
        let circle2 = MKCircle(center: parseToCoordinate, radius: endRadius)
        mapView.addOverlays([circle1, circle2])
        
        context.coordinator.lastPointCount = 0
        
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserPan))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserGesture))
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        let from = CoordinateConverter.parseCoordinate(coordinate: fromCoordinate)
        let to = CoordinateConverter.parseCoordinate(coordinate: toCoordinate)
        
        switch mapMode {
        case .overview:
            guard context.coordinator.lastMode != .overview || context.coordinator.lastIsShowSheet != isShowSheet else { break }
            //print("switch to overview")
            var rect = MKMapRect.null
            let points = [MKMapPoint(from), MKMapPoint(to)]
            for p in points { rect = rect.union(MKMapRect(origin: p, size: .init(width: 0, height: 0))) }
            
            let padding = UIEdgeInsets(top: isShowSheet ? 20 : 50, left: 50, bottom: isShowSheet ? 550 : 250, right: 50)
            mapView.setVisibleMapRect(rect, edgePadding: padding, animated: true)
            context.coordinator.lastIsShowSheet = isShowSheet
        case .followUser:
            //print("switch to followuser")
            if let userLocation = userLocation {
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
                let insets = mapView.safeAreaInsets
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
            // 不自动更新region
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

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: RaceRealtimeMapView
        let fromAnnotation = TrackPointAnnotation(type: .start)
        let toAnnotation = TrackPointAnnotation(type: .end)
        // 缓存
        var lastPointCount: Int = 0
        var lastMode: MapViewMode = .followUser
        var lastIsShowSheet: Bool = false
        
        init(_ parent: RaceRealtimeMapView) {
            self.parent = parent
            self.fromAnnotation.title = "From"
            self.toAnnotation.title = "To"
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
            guard let annotation = annotation as? TrackPointAnnotation else { return nil }
            
            let identifier = "TrackPointAnnotationView.realtime"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            as? TrackPointAnnotationView
            ?? TrackPointAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            
            let imageName: String
            let titleText: String
            
            switch annotation.type {
            case .start:
                imageName = "flag_start"
                titleText = NSLocalizedString("competition.track.start", comment: "")
            case .end:
                imageName = "flag_finish"
                titleText = NSLocalizedString("competition.track.finish", comment: "")
            }
            
            view.image = UIImage(named: imageName)
            view.configure(title: titleText)
            
            return view
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
    }
}

// MARK: - 比赛数据结算的 Map 视图
struct GradientPathMapView: UIViewRepresentable {
    let path: [PathPoint]
    let highlightedIndex: Int
    
    private let highlightAnnotationId = "highlightAnnotation"
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        if !path.isEmpty {
            // 按 segment 分段绘制（free training 暂停缺口断开；race/route 单段无影响）
            var run: [PathPoint] = []
            var allCoords: [CLLocationCoordinate2D] = []
            func flush() {
                guard run.count >= 2 else { run = []; return }
                var coords = run.map { CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
                let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
                polyline.speeds = run.map { $0.speed }
                mapView.addOverlay(polyline)
                run = []
            }
            for point in path {
                if let last = run.last, last.segment != point.segment {
                    flush()
                }
                run.append(point)
                allCoords.append(CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)))
            }
            flush()
            // 整条轨迹的可视范围（用全部点，避免分段后只框住最后一段）
            let boundingPolyline = MKPolyline(coordinates: allCoords, count: allCoords.count)
            mapView.setVisibleMapRect(boundingPolyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
        }
        
        // 添加起点 annotation（绿色圆点）
        if let first = path.first {
            let parseFirst = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: first.lat, longitude: first.lon))
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = CLLocationCoordinate2D(latitude: parseFirst.latitude, longitude: parseFirst.longitude)
            startAnnotation.title = "startAnnotation"
            mapView.addAnnotation(startAnnotation)
        }
        // 添加终点 annotation（红色圆点）
        if let last = path.last {
            let parseLast = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: last.lat, longitude: last.lon))
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = CLLocationCoordinate2D(latitude: parseLast.latitude, longitude: parseLast.longitude)
            endAnnotation.title = "endAnnotation"
            mapView.addAnnotation(endAnnotation)
        }
        
        // 隐藏底部 "Legal" 图标
        for subview in mapView.subviews {
            if String(describing: type(of: subview)).contains("Attribution") {
                subview.isHidden = true
            }
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        guard !path.isEmpty, highlightedIndex < path.count else { return }
        let ratio = Double(path.count) / 80.0
        let sampleIndex = path.count < 80 ? highlightedIndex : Int(Double(highlightedIndex) * ratio)
        // 移除旧的高亮 annotation
        let existing = mapView.annotations.filter { $0.title == highlightAnnotationId }
        mapView.removeAnnotations(existing)
        
        // 添加新的高亮 annotation
        let coord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: path[Int(sampleIndex)].lat, longitude: path[Int(sampleIndex)].lon))
        let annotation = MKPointAnnotation()
        annotation.coordinate = coord
        annotation.title = highlightAnnotationId
        mapView.addAnnotation(annotation)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator() }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? SpeedPolyline {
                return SpeedPolylineRenderer(polyline: polyline)
            }
            return MKOverlayRenderer()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let title = annotation.title ?? nil else { return nil }
            if title == "highlightAnnotation" {
                let id = "highlightView"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view?.layer.cornerRadius = 7
                    view?.layer.borderColor = UIColor.white.cgColor
                    view?.layer.borderWidth = 2
                    view?.backgroundColor = UIColor.systemBlue
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                return view
            } else if title == "startAnnotation" {
                let id = "startView"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view?.layer.cornerRadius = 7
                    view?.layer.borderColor = UIColor.white.cgColor
                    view?.layer.borderWidth = 2
                    view?.backgroundColor = UIColor.systemGreen
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                return view
            } else if title == "endAnnotation" {
                let id = "endView"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    view?.frame = CGRect(x: 0, y: 0, width: 14, height: 14)
                    view?.layer.cornerRadius = 7
                    view?.layer.borderColor = UIColor.white.cgColor
                    view?.layer.borderWidth = 2
                    view?.backgroundColor = UIColor.systemRed
                    view?.canShowCallout = false
                } else {
                    view?.annotation = annotation
                }
                return view
            }
            return nil
        }
    }
}

// MARK: - 训练进行时的路径 Map 视图
struct BikeTrainingRealtimeMapView: UIViewRepresentable {
    let path: [PathPoint]
    @Binding var mapMode: MapViewMode
    @Binding var userLocation: CLLocation?  // 用于跟随模式
    let isShowSheet: Bool
    let showGrids: Bool
    var nearbyGrids: [NearbyGrid] = []      // 附近 buff 网格（指引）
    var showGridGuide: Bool = false         // 是否显示网格指引（独立于 showGrids 瓦片）

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator
        
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserPan))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserGesture))
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)
        
        context.coordinator.lastPointCount = 0

        // 网格指引控制器：持有 mapView，启动每帧边缘箭头计算
        context.coordinator.gridGuide.mapView = mapView
        context.coordinator.gridGuide.start()

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.showGrids = showGrids

        // 同步网格指引（与 showGrids 瓦片彼此独立）
        let guide = context.coordinator.gridGuide
        guide.userLocation = userLocation
        guide.nearbyGrids = nearbyGrids
        guide.showGridGuide = showGridGuide
        guide.showGrids = showGrids
        guide.isRecording = CompetitionManager.shared.isRecording
        guide.isShowSheet = isShowSheet
        guide.sync()

        if !showGrids {
            let removable = mapView.overlays.filter {
                $0 is TileOverlay
            }
            mapView.removeOverlays(removable)
            context.coordinator.renderedTiles.removeAll()

            let removableAnnotations = mapView.annotations.filter {
                $0 is BikeGridBuffAnnotation
            }
            mapView.removeAnnotations(removableAnnotations)
            context.coordinator.renderedBuffs.removeAll()
        } else {
            let locationManager = LocationManager.shared
            guard !locationManager.regionBoundary.isEmpty else { return }
            context.coordinator.updateVisibleTiles(mapView: mapView)
        }
        
        switch mapMode {
        case .followUser:
            //print("switch to followuser")
            if let userLocation = userLocation {
                let center = CoordinateConverter.parseCoordinate(coordinate: userLocation.coordinate)
                let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(center.latitude)
                let halfSize = 200 * mapPointsPerMeter
                
                let centerPoint = MKMapPoint(center)
                
                let rect = MKMapRect(
                    x: centerPoint.x - halfSize,
                    y: centerPoint.y - halfSize,
                    width: 2 * halfSize,
                    height: 2 * halfSize
                )
                // padding 决定用户在屏幕中的位置
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
        default:
            // 不自动更新region
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
            // 如果路径被重置，清除路径 overlay
            let removable = mapView.overlays.filter {
                $0 is SpeedPolyline
            }
            mapView.removeOverlays(removable)
            // 按 segment 分段绘制（暂停缺口自然断开）
            addPolylineSegment(to: mapView, from: path)
            if let firstPolyline = makePolyline(from: path) {
                mapView.setVisibleMapRect(firstPolyline.boundingMapRect, edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40), animated: false)
            }
        }
        context.coordinator.lastPointCount = path.count
    }

    private func addPolylineSegment(to mapView: MKMapView, from segment: [PathPoint]) {
        guard segment.count >= 2 else { return }
        // 仅连接同一活动段（segment 相同）内的相邻点，跨暂停的弦不绘制
        var run: [PathPoint] = []
        func flush() {
            guard run.count >= 2 else { run = []; return }
            var coords = run.map {
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
            }
            let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
            polyline.speeds = run.map { $0.speed }
            mapView.addOverlay(polyline, level: .aboveLabels)
            run = []
        }
        for point in segment {
            if let last = run.last, last.segment != point.segment {
                flush()
            }
            run.append(point)
        }
        flush()
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

    func makeCoordinator() -> Coordinator { Coordinator(self, showGrids: showGrids) }

    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) {
        coordinator.gridGuide.stop()
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: BikeTrainingRealtimeMapView
        // 缓存
        var lastPointCount: Int = 0
        var lastMode: MapViewMode = .followUser
        
        var showGrids: Bool
        let baseGridMeters: Double = 500
        let maxCacheTiles = 200
        
        var lastShowSheet: Bool = true

        func tileSize(for level: Int) -> Int {
            switch level {
            case 0: return 32
            case 1: return 32
            case 2: return 16
            default: return 8
            }
        }

        // Cache
        var cache: [TileKey: BikeTrainingGridTile] = [:]
        var tileAccessOrder: [TileKey] = []
        var renderedTiles: Set<TileKey> = []
        var renderedBuffs: Set<TileKey> = []
        
        var lastLevel: Int = -1

        // 附近 buff 网格实时指引
        let gridGuide = GridGuideController()

        init(_ parent: BikeTrainingRealtimeMapView, showGrids: Bool) {
            self.parent = parent
            self.showGrids = showGrids
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
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            updateVisibleTiles(mapView: mapView)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? TileOverlay {
                return TileRenderer(overlay: tileOverlay)
            }
            
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
        
        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let identifier = "UserLocation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKUserLocationView
                    ?? MKUserLocationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.canShowCallout = false
                view.isEnabled = false
                return view
            }

            // 网格指引 annotation
            if let guideView = GridGuideController.annotationView(for: annotation, in: mapView) {
                return guideView
            }

            guard annotation is BikeGridBuffAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: BikeGridBuffAnnotationView.reuseID
            ) as? BikeGridBuffAnnotationView

            if let view {
                view.annotation = annotation
                return view
            }

            return BikeGridBuffAnnotationView(
                annotation: annotation,
                reuseIdentifier: BikeGridBuffAnnotationView.reuseID
            )
        }
        
        func updateVisibleTiles(mapView: MKMapView) {
            guard showGrids else { return }
            
            let windowBbox = mapView.region
            
            let zoom = getZoomLevel(mapView: mapView)
            let level = levelForZoom(zoom)
            
            if level >= 3 && zoom < 10 {
                let removable = mapView.overlays.filter {
                    $0 is TileOverlay
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                
                let removableAnnotations = mapView.annotations.filter {
                    $0 is BikeGridBuffAnnotation
                }
                mapView.removeAnnotations(removableAnnotations)
                renderedBuffs.removeAll()
                return
            }
            
            let gridRange = convertBBoxToGridRange(bbox: windowBbox, level: level)
            
            let gridWidth = gridRange.maxX - gridRange.minX
            let gridHeight = gridRange.maxY - gridRange.minY
            let gridCount = gridWidth * gridHeight
            if gridCount > 1000 {
                let removable = mapView.overlays.filter {
                    $0 is TileOverlay
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                
                let removableAnnotations = mapView.annotations.filter {
                    $0 is BikeGridBuffAnnotation
                }
                mapView.removeAnnotations(removableAnnotations)
                renderedBuffs.removeAll()
                return
            }

            let neededTiles = computeTiles(gridRange: gridRange, level: level)

            let missingTiles = neededTiles.filter { cache[$0] == nil }

            // 请求 missingTiles
            fetchTiles(mapView: mapView, tiles: missingTiles)
            // 已有的缓存先渲染
            let shouldReload = level != lastLevel || mapView.overlays.count > 1000
            render(mapView: mapView, tiles: neededTiles, removeAll: shouldReload)
            lastLevel = level
        }
        
        func getZoomLevel(mapView: MKMapView) -> Double {
            let region = mapView.region
            return log2(360 * Double(mapView.frame.size.width / 256 / region.span.longitudeDelta)) + 1
        }

        func levelForZoom(_ zoom: Double) -> Int {
            if zoom > 14.5 { return 0 }     // 500m
            if zoom > 13 { return 1 }       // 1km
            if zoom > 11.5 { return 2 }     // 2km
            return 3                        // 4km
        }
        
        func convertBBoxToGridRange(
            bbox: MKCoordinateRegion,
            level: Int
        ) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
            let minLat = bbox.center.latitude - bbox.span.latitudeDelta / 2
            let maxLat = bbox.center.latitude + bbox.span.latitudeDelta / 2
            let minLng = bbox.center.longitude - bbox.span.longitudeDelta / 2
            let maxLng = bbox.center.longitude + bbox.span.longitudeDelta / 2
            
            let (minX, minY) = gridXY(lat: minLat, lng: minLng, level: level)
            let (maxX, maxY) = gridXY(lat: maxLat, lng: maxLng, level: level)
            
            return (
                min(minX, maxX),
                max(minX, maxX),
                min(minY, maxY),
                max(minY, maxY)
            )
        }
        
        func divFloor(_ a: Int, _ b: Int) -> Int {
            return Int(floor(Double(a) / Double(b)))
        }
        
        func computeTiles(
            gridRange: (minX: Int, maxX: Int, minY: Int, maxY: Int),
            level: Int
        ) -> [TileKey] {
            let tileSize = tileSize(for: level)

            let minTileX = divFloor(gridRange.minX, tileSize) - 1
            let maxTileX = divFloor(gridRange.maxX, tileSize) + 1

            let minTileY = divFloor(gridRange.minY, tileSize) - 1
            let maxTileY = divFloor(gridRange.maxY, tileSize) + 1

            var tiles: [TileKey] = []

            for x in minTileX...maxTileX {
                for y in minTileY...maxTileY {
                    tiles.append(TileKey(level: level, x: x, y: y))
                }
            }
            return tiles
        }
        
        func fetchTiles(mapView: MKMapView, tiles: [TileKey]) {
            guard !tiles.isEmpty, tiles.count < 50, let regionID = LocationManager.shared.regionID else { return }
            
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let requestData = TrainingGridTileRequest(region_id: regionID, tiles: tiles)
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            
            let request = APIRequest(path: "/training/bike/query_grid_tiles", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            
            NetworkService.sendRequest(with: request, decodingType: BikeTrainingGridTileResponse.self, showLoadingToast: false, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        var result: [TileKey: BikeTrainingGridTile] = [:]
                        for tile in unwrappedData.tiles {
                            result[tile.key] = tile
                        }
                        // 写 cache
                        for (tile, tileData) in result {
                            self.cache[tile] = tileData
                            self.tileAccessOrder.removeAll { $0 == tile }   // 去重
                            self.tileAccessOrder.append(tile)
                        }
                        // 清 cache
                        while self.cache.count > self.maxCacheTiles {
                            let oldest = self.tileAccessOrder.removeFirst()
                            self.cache.removeValue(forKey: oldest)
                            //print("remove cache key: \(oldest)")
                        }
                        
                        // 防止过期数据污染，如果当前视图 level 和返回 tile 的 level 不一致则丢弃渲染
                        let currentZoom = self.getZoomLevel(mapView: mapView)
                        let currentLevel = self.levelForZoom(currentZoom)
                        if let tileLevel = tiles.first?.level, tileLevel != currentLevel {
                            return
                        }
                        self.render(mapView: mapView, tiles: tiles, removeAll: false)
                    }
                default: break
                }
            }
        }
        
        func render(mapView: MKMapView, tiles: [TileKey], removeAll: Bool) {
            if removeAll {
                let removable = mapView.overlays.filter {
                    $0 is TileOverlay
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                
                let removableAnnotations = mapView.annotations.filter {
                    $0 is BikeGridBuffAnnotation
                }
                mapView.removeAnnotations(removableAnnotations)
                renderedBuffs.removeAll()
            }
            
            let visibleRect = mapView.visibleMapRect
            let padding = visibleRect.size.width * 0.2
            let paddedRect = visibleRect.insetBy(dx: -padding, dy: -padding)

            for tile in tiles {
                guard let tileData = cache[tile] else { continue }
                let cells = tileData.cells
                let buffs = tileData.buff_info
                
                // 避免重复添加同一个 tile overlay
                if !removeAll && renderedTiles.contains(tile) {
                    continue
                }
                
                let tileSize = tileSize(for: tile.level)
                let startX = tile.x * tileSize
                let endX = startX + tileSize - 1
                let startY = tile.y * tileSize
                let endY = startY + tileSize - 1
                
                var map: [String: Int] = [:]
                for cell in cells {
                    map["\(cell.grid_x)_\(cell.grid_y)"] = cell.count
                }
                
                var coords: [CLLocationCoordinate2D] = []
                var colors: [Int] = []
                
                for gx in startX...endX {
                    for gy in startY...endY {
                        let key = "\(gx)_\(gy)"
                        let count = map[key] ?? 0
                        // render
                        let polygon = makePolygon(gridX: gx, gridY: gy, level: tile.level)
                        coords.append(contentsOf: polygon.coordinates())
                        colors.append(count)
                    }
                }
                if !coords.isEmpty {
                    let overlay = TileOverlay(coordinates: coords, counts: colors, level: tile.level)
                    mapView.addOverlay(overlay, level: .aboveRoads)
                    renderedTiles.insert(tile)
                    //print("new upsert tile: \(tile)")
                }
                
                if renderedBuffs.contains(tile) { continue }
                
                for buff in buffs {
                    //print(buff.grid_x, buff.grid_y)
                    let polygon = makePolygon(
                        gridX: buff.grid_x,
                        gridY: buff.grid_y,
                        level: tile.level
                    )
                    let rect = polygon.boundingMapRect

                    let center = MKMapPoint(
                        x: rect.midX,
                        y: rect.midY
                    ).coordinate
                    
                    guard let ccassetType = CCAssetType(rawValue: buff.reward_type) else { continue }
                    
                    let annotation = BikeGridBuffAnnotation(
                        coordinate: center,
                        gridX: buff.grid_x,
                        gridY: buff.grid_y,
                        level: tile.level,
                        rewardType: ccassetType,
                        conditionType: buff.condition_type
                    )
                    mapView.addAnnotation(annotation)
                }
                renderedBuffs.insert(tile)
            }
        }
        
        func makePolygon(gridX: Int, gridY: Int, level: Int) -> MKPolygon {
            let gridSize = baseGridMeters * pow(2.0, Double(level))
            
            let minX = Double(gridX) * gridSize
            let minY = Double(gridY) * gridSize
            let maxX = minX + gridSize
            let maxY = minY + gridSize
            
            let p1 = CoordinateConverter.mercatorToLatLng(x: minX, y: minY)
            let p2 = CoordinateConverter.mercatorToLatLng(x: maxX, y: minY)
            let p3 = CoordinateConverter.mercatorToLatLng(x: maxX, y: maxY)
            let p4 = CoordinateConverter.mercatorToLatLng(x: minX, y: maxY)
            
            let coords = [
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p1.lat, longitude: p1.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p2.lat, longitude: p2.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p3.lat, longitude: p3.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p4.lat, longitude: p4.lng))
            ]
            return MKPolygon(coordinates: coords, count: coords.count)
        }
        
        func gridXY(lat: Double, lng: Double, level: Int) -> (Int, Int) {
            let (x, y) = CoordinateConverter.latLngToMercator(lat: lat, lng: lng)
            let gridSize = baseGridMeters * pow(2.0, Double(level))
            let gx = Int(floor(x / gridSize))
            let gy = Int(floor(y / gridSize))
            return (gx, gy)
        }
    }
}

struct RunningTrainingRealtimeMapView: UIViewRepresentable {
    let path: [PathPoint]
    @Binding var mapMode: MapViewMode
    @Binding var userLocation: CLLocation?  // 用于跟随模式
    let isShowSheet: Bool
    let showGrids: Bool
    var nearbyGrids: [NearbyGrid] = []      // 附近 buff 网格（指引）
    var showGridGuide: Bool = false         // 是否显示网格指引（独立于 showGrids 瓦片）

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsUserLocation = true
        mapView.delegate = context.coordinator

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserPan))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.onUserGesture))
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)

        context.coordinator.lastPointCount = 0

        // 网格指引控制器：持有 mapView，启动每帧边缘箭头计算
        context.coordinator.gridGuide.mapView = mapView
        context.coordinator.gridGuide.start()

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.showGrids = showGrids

        // 同步网格指引（与 showGrids 瓦片彼此独立）
        let guide = context.coordinator.gridGuide
        guide.userLocation = userLocation
        guide.nearbyGrids = nearbyGrids
        guide.showGridGuide = showGridGuide
        guide.showGrids = showGrids
        guide.isRecording = CompetitionManager.shared.isRecording
        guide.isShowSheet = isShowSheet
        guide.sync()

        if !showGrids {
            let removable = mapView.overlays.filter {
                $0 is TileOverlay
            }
            mapView.removeOverlays(removable)
            context.coordinator.renderedTiles.removeAll()

            let removableAnnotations = mapView.annotations.filter {
                $0 is RunningGridBuffAnnotation
            }
            mapView.removeAnnotations(removableAnnotations)
            context.coordinator.renderedBuffs.removeAll()
        } else {
            let locationManager = LocationManager.shared
            guard !locationManager.regionBoundary.isEmpty else { return }
            context.coordinator.updateVisibleTiles(mapView: mapView)
        }
        
        switch mapMode {
        case .followUser:
            //print("switch to followuser")
            if let userLocation = userLocation {
                let center = CoordinateConverter.parseCoordinate(coordinate: userLocation.coordinate)
                let mapPointsPerMeter = MKMapPointsPerMeterAtLatitude(center.latitude)
                let halfSize = 200 * mapPointsPerMeter
                
                let centerPoint = MKMapPoint(center)
                
                let rect = MKMapRect(
                    x: centerPoint.x - halfSize,
                    y: centerPoint.y - halfSize,
                    width: 2 * halfSize,
                    height: 2 * halfSize
                )
                // padding 决定用户在屏幕中的位置
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
        default:
            // 不自动更新region
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
            // 如果路径被重置，清除路径 overlay
            let removable = mapView.overlays.filter {
                $0 is SpeedPolyline
            }
            mapView.removeOverlays(removable)
            // 按 segment 分段绘制（暂停缺口自然断开）
            addPolylineSegment(to: mapView, from: path)
            if let firstPolyline = makePolyline(from: path) {
                mapView.setVisibleMapRect(firstPolyline.boundingMapRect, edgePadding: .init(top: 40, left: 40, bottom: 40, right: 40), animated: false)
            }
        }
        context.coordinator.lastPointCount = path.count
    }

    private func addPolylineSegment(to mapView: MKMapView, from segment: [PathPoint]) {
        guard segment.count >= 2 else { return }
        // 仅连接同一活动段（segment 相同）内的相邻点，跨暂停的弦不绘制
        var run: [PathPoint] = []
        func flush() {
            guard run.count >= 2 else { run = []; return }
            var coords = run.map {
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon))
            }
            let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
            polyline.speeds = run.map { $0.speed }
            mapView.addOverlay(polyline, level: .aboveLabels)
            run = []
        }
        for point in segment {
            if let last = run.last, last.segment != point.segment {
                flush()
            }
            run.append(point)
        }
        flush()
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

    func makeCoordinator() -> Coordinator { Coordinator(self, showGrids: showGrids) }

    static func dismantleUIView(_ uiView: MKMapView, coordinator: Coordinator) {
        coordinator.gridGuide.stop()
    }

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: RunningTrainingRealtimeMapView
        // 缓存
        var lastPointCount: Int = 0
        var lastMode: MapViewMode = .followUser
        
        var showGrids: Bool
        let baseGridMeters: Double = 500
        let maxCacheTiles = 200
        
        var lastShowSheet: Bool = true

        func tileSize(for level: Int) -> Int {
            switch level {
            case 0: return 32
            case 1: return 32
            case 2: return 16
            default: return 8
            }
        }

        // Cache
        var cache: [TileKey: RunningTrainingGridTile] = [:]
        var tileAccessOrder: [TileKey] = []
        var renderedTiles: Set<TileKey> = []
        var renderedBuffs: Set<TileKey> = []
        
        var lastLevel: Int = -1

        // 附近 buff 网格实时指引
        let gridGuide = GridGuideController()

        init(_ parent: RunningTrainingRealtimeMapView, showGrids: Bool) {
            self.parent = parent
            self.showGrids = showGrids
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
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            updateVisibleTiles(mapView: mapView)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? TileOverlay {
                return TileRenderer(overlay: tileOverlay)
            }
            
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
        
        func mapView(
            _ mapView: MKMapView,
            viewFor annotation: MKAnnotation
        ) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                let identifier = "UserLocation"
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKUserLocationView
                    ?? MKUserLocationView(annotation: annotation, reuseIdentifier: identifier)
                view.annotation = annotation
                view.canShowCallout = false
                view.isEnabled = false
                return view
            }

            // 网格指引 annotation
            if let guideView = GridGuideController.annotationView(for: annotation, in: mapView) {
                return guideView
            }

            guard annotation is RunningGridBuffAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: RunningGridBuffAnnotationView.reuseID
            ) as? RunningGridBuffAnnotationView

            if let view {
                view.annotation = annotation
                return view
            }

            return RunningGridBuffAnnotationView(
                annotation: annotation,
                reuseIdentifier: RunningGridBuffAnnotationView.reuseID
            )
        }
        
        func updateVisibleTiles(mapView: MKMapView) {
            guard showGrids else { return }
            
            let windowBbox = mapView.region
            
            let zoom = getZoomLevel(mapView: mapView)
            let level = levelForZoom(zoom)
            
            if level >= 3 && zoom < 10 {
                let removable = mapView.overlays.filter {
                    $0 is TileOverlay
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                
                let removableAnnotations = mapView.annotations.filter {
                    $0 is RunningGridBuffAnnotation
                }
                mapView.removeAnnotations(removableAnnotations)
                renderedBuffs.removeAll()
                return
            }
            
            let gridRange = convertBBoxToGridRange(bbox: windowBbox, level: level)
            
            let gridWidth = gridRange.maxX - gridRange.minX
            let gridHeight = gridRange.maxY - gridRange.minY
            let gridCount = gridWidth * gridHeight
            if gridCount > 1000 {
                let removable = mapView.overlays.filter {
                    $0 is TileOverlay
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                
                let removableAnnotations = mapView.annotations.filter {
                    $0 is RunningGridBuffAnnotation
                }
                mapView.removeAnnotations(removableAnnotations)
                renderedBuffs.removeAll()
                return
            }

            let neededTiles = computeTiles(gridRange: gridRange, level: level)

            let missingTiles = neededTiles.filter { cache[$0] == nil }

            // 请求 missingTiles
            fetchTiles(mapView: mapView, tiles: missingTiles)
            // 已有的缓存先渲染
            let shouldReload = level != lastLevel || mapView.overlays.count > 1000
            render(mapView: mapView, tiles: neededTiles, removeAll: shouldReload)
            lastLevel = level
        }
        
        func getZoomLevel(mapView: MKMapView) -> Double {
            let region = mapView.region
            return log2(360 * Double(mapView.frame.size.width / 256 / region.span.longitudeDelta)) + 1
        }

        func levelForZoom(_ zoom: Double) -> Int {
            if zoom > 14.5 { return 0 }     // 500m
            if zoom > 13 { return 1 }       // 1km
            if zoom > 11.5 { return 2 }     // 2km
            return 3                        // 4km
        }
        
        func convertBBoxToGridRange(
            bbox: MKCoordinateRegion,
            level: Int
        ) -> (minX: Int, maxX: Int, minY: Int, maxY: Int) {
            let minLat = bbox.center.latitude - bbox.span.latitudeDelta / 2
            let maxLat = bbox.center.latitude + bbox.span.latitudeDelta / 2
            let minLng = bbox.center.longitude - bbox.span.longitudeDelta / 2
            let maxLng = bbox.center.longitude + bbox.span.longitudeDelta / 2
            
            let (minX, minY) = gridXY(lat: minLat, lng: minLng, level: level)
            let (maxX, maxY) = gridXY(lat: maxLat, lng: maxLng, level: level)
            
            return (
                min(minX, maxX),
                max(minX, maxX),
                min(minY, maxY),
                max(minY, maxY)
            )
        }
        
        func divFloor(_ a: Int, _ b: Int) -> Int {
            return Int(floor(Double(a) / Double(b)))
        }
        
        func computeTiles(
            gridRange: (minX: Int, maxX: Int, minY: Int, maxY: Int),
            level: Int
        ) -> [TileKey] {
            let tileSize = tileSize(for: level)

            let minTileX = divFloor(gridRange.minX, tileSize) - 1
            let maxTileX = divFloor(gridRange.maxX, tileSize) + 1

            let minTileY = divFloor(gridRange.minY, tileSize) - 1
            let maxTileY = divFloor(gridRange.maxY, tileSize) + 1

            var tiles: [TileKey] = []

            for x in minTileX...maxTileX {
                for y in minTileY...maxTileY {
                    tiles.append(TileKey(level: level, x: x, y: y))
                }
            }
            return tiles
        }
        
        func fetchTiles(mapView: MKMapView, tiles: [TileKey]) {
            guard !tiles.isEmpty, tiles.count < 50, let regionID = LocationManager.shared.regionID else { return }
            
            var headers: [String: String] = [:]
            headers["Content-Type"] = "application/json"
            let requestData = TrainingGridTileRequest(region_id: regionID, tiles: tiles)
            guard let encodedBody = try? JSONEncoder().encode(requestData) else { return }
            
            let request = APIRequest(path: "/training/running/query_grid_tiles", method: .post, headers: headers, body: encodedBody, requiresAuth: true)
            
            NetworkService.sendRequest(with: request, decodingType: RunningTrainingGridTileResponse.self, showLoadingToast: false, showErrorToast: true) { result in
                switch result {
                case .success(let data):
                    guard let unwrappedData = data else { return }
                    DispatchQueue.main.async {
                        var result: [TileKey: RunningTrainingGridTile] = [:]
                        for tile in unwrappedData.tiles {
                            result[tile.key] = tile
                        }
                        // 写 cache
                        for (tile, tileData) in result {
                            self.cache[tile] = tileData
                            self.tileAccessOrder.removeAll { $0 == tile }   // 去重
                            self.tileAccessOrder.append(tile)
                        }
                        // 清 cache
                        while self.cache.count > self.maxCacheTiles {
                            let oldest = self.tileAccessOrder.removeFirst()
                            self.cache.removeValue(forKey: oldest)
                            //print("remove cache key: \(oldest)")
                        }
                        
                        // 防止过期数据污染，如果当前视图 level 和返回 tile 的 level 不一致则丢弃渲染
                        let currentZoom = self.getZoomLevel(mapView: mapView)
                        let currentLevel = self.levelForZoom(currentZoom)
                        if let tileLevel = tiles.first?.level, tileLevel != currentLevel {
                            return
                        }
                        self.render(mapView: mapView, tiles: tiles, removeAll: false)
                    }
                default: break
                }
            }
        }
        
        func render(mapView: MKMapView, tiles: [TileKey], removeAll: Bool) {
            if removeAll {
                let removable = mapView.overlays.filter {
                    $0 is TileOverlay
                }
                mapView.removeOverlays(removable)
                renderedTiles.removeAll()
                
                let removableAnnotations = mapView.annotations.filter {
                    $0 is RunningGridBuffAnnotation
                }
                mapView.removeAnnotations(removableAnnotations)
                renderedBuffs.removeAll()
            }
            
            let visibleRect = mapView.visibleMapRect
            let padding = visibleRect.size.width * 0.2
            let paddedRect = visibleRect.insetBy(dx: -padding, dy: -padding)

            for tile in tiles {
                guard let tileData = cache[tile] else { continue }
                let cells = tileData.cells
                let buffs = tileData.buff_info
                
                // 避免重复添加同一个 tile overlay
                if !removeAll && renderedTiles.contains(tile) {
                    continue
                }
                
                let tileSize = tileSize(for: tile.level)
                let startX = tile.x * tileSize
                let endX = startX + tileSize - 1
                let startY = tile.y * tileSize
                let endY = startY + tileSize - 1
                
                var map: [String: Int] = [:]
                for cell in cells {
                    map["\(cell.grid_x)_\(cell.grid_y)"] = cell.count
                }
                
                var coords: [CLLocationCoordinate2D] = []
                var colors: [Int] = []
                
                for gx in startX...endX {
                    for gy in startY...endY {
                        let key = "\(gx)_\(gy)"
                        let count = map[key] ?? 0
                        // render
                        let polygon = makePolygon(gridX: gx, gridY: gy, level: tile.level)
                        coords.append(contentsOf: polygon.coordinates())
                        colors.append(count)
                    }
                }
                if !coords.isEmpty {
                    let overlay = TileOverlay(coordinates: coords, counts: colors, level: tile.level)
                    mapView.addOverlay(overlay, level: .aboveRoads)
                    renderedTiles.insert(tile)
                    //print("new upsert tile: \(tile)")
                }
                
                if renderedBuffs.contains(tile) { continue }
                
                for buff in buffs {
                    //print(buff.grid_x, buff.grid_y)
                    let polygon = makePolygon(
                        gridX: buff.grid_x,
                        gridY: buff.grid_y,
                        level: tile.level
                    )
                    let rect = polygon.boundingMapRect

                    let center = MKMapPoint(
                        x: rect.midX,
                        y: rect.midY
                    ).coordinate
                    
                    guard let ccassetType = CCAssetType(rawValue: buff.reward_type) else { continue }
                    
                    let annotation = RunningGridBuffAnnotation(
                        coordinate: center,
                        gridX: buff.grid_x,
                        gridY: buff.grid_y,
                        level: tile.level,
                        rewardType: ccassetType,
                        conditionType: buff.condition_type
                    )
                    mapView.addAnnotation(annotation)
                }
                renderedBuffs.insert(tile)
            }
        }

        func makePolygon(gridX: Int, gridY: Int, level: Int) -> MKPolygon {
            let gridSize = baseGridMeters * pow(2.0, Double(level))

            let minX = Double(gridX) * gridSize
            let minY = Double(gridY) * gridSize
            let maxX = minX + gridSize
            let maxY = minY + gridSize

            let p1 = CoordinateConverter.mercatorToLatLng(x: minX, y: minY)
            let p2 = CoordinateConverter.mercatorToLatLng(x: maxX, y: minY)
            let p3 = CoordinateConverter.mercatorToLatLng(x: maxX, y: maxY)
            let p4 = CoordinateConverter.mercatorToLatLng(x: minX, y: maxY)

            let coords = [
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p1.lat, longitude: p1.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p2.lat, longitude: p2.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p3.lat, longitude: p3.lng)),
                CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: p4.lat, longitude: p4.lng))
            ]
            return MKPolygon(coordinates: coords, count: coords.count)
        }

        func gridXY(lat: Double, lng: Double, level: Int) -> (Int, Int) {
            let (x, y) = CoordinateConverter.latLngToMercator(lat: lat, lng: lng)
            let gridSize = baseGridMeters * pow(2.0, Double(level))
            let gx = Int(floor(x / gridSize))
            let gy = Int(floor(y / gridSize))
            return (gx, gy)
        }
    }
}

// MARK: - free training 附近 buff 网格实时指引

// 指引 annotation：标在网格中心，显示 reward 图标 + 实时距离。
// 与 tile 级的 BikeGridBuffAnnotation/RunningGridBuffAnnotation 是不同类，清理时互不干扰。
final class NearbyGridGuideAnnotation: NSObject, MKAnnotation {
    let id: String
    dynamic var coordinate: CLLocationCoordinate2D
    let reward: CCAssetType
    var distance: Double?          // 与用户的实时距离（米）
    var hideRewardIcon: Bool = false   // 与 showGrids 瓦片同开时隐藏图标，避免与 buff 瓦片图标重叠

    init(id: String, coordinate: CLLocationCoordinate2D, reward: CCAssetType) {
        self.id = id
        self.coordinate = coordinate
        self.reward = reward
    }
}

final class NearbyGridGuideAnnotationView: MKAnnotationView {
    static let reuseID = "NearbyGridGuideAnnotationView"

    private let iconImageView = UIImageView()
    private let distanceLabel = UILabel()
    private var lastDistance: Double?
    private var didSetup = false

    override var annotation: MKAnnotation? {
        didSet { configure() }
    }

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupUI()
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupUI() {
        guard !didSetup else { return }
        frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        backgroundColor = .clear
        canShowCallout = false

        // reward 图标 + 金色光晕（风格对齐 BikeGridBuffAnnotationView）
        iconImageView.frame = CGRect(x: 8, y: 8, width: 24, height: 24)
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.layer.shadowColor = UIColor.systemYellow.cgColor
        iconImageView.layer.shadowRadius = 7
        iconImageView.layer.shadowOpacity = 1
        iconImageView.layer.shadowOffset = .zero
        iconImageView.layer.masksToBounds = false
        addSubview(iconImageView)

        // 上方距离标签（风格对齐 RoutePointRealtimeAnnotationView 的 distanceLabel）
        distanceLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        distanceLabel.textColor = .white
        distanceLabel.textAlignment = .center
        distanceLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        distanceLabel.layer.cornerRadius = 4
        distanceLabel.clipsToBounds = true
        distanceLabel.isHidden = true
        addSubview(distanceLabel)

        didSetup = true
    }

    // 持续呼吸放大（对齐 route 的 breathing）。annotation 复用时图层动画会被移除，
    // 故每次 configure 都检查并按需重新挂上，避免重复开关后呼吸效果丢失。
    private func applyBreathingIfNeeded() {
        guard iconImageView.layer.animation(forKey: "breathing") == nil else { return }
        let breathing = CABasicAnimation(keyPath: "transform.scale")
        breathing.fromValue = 1.0
        breathing.toValue = 1.25
        breathing.duration = 1.0
        breathing.autoreverses = true
        breathing.repeatCount = .infinity
        breathing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconImageView.layer.add(breathing, forKey: "breathing")
    }

    private func configure() {
        guard let ann = annotation as? NearbyGridGuideAnnotation else { return }
        setupUI()
        // 与 showGrids 瓦片同开时隐藏 reward 图标（瓦片自带 buff 图标，避免重叠），
        // 但距离 label 仍展示。隐藏时停掉呼吸动画，显示时按需重挂。
        iconImageView.isHidden = ann.hideRewardIcon
        if ann.hideRewardIcon {
            iconImageView.image = nil
            iconImageView.layer.removeAnimation(forKey: "breathing")
        } else {
            iconImageView.image = UIImage(named: ann.reward.iconName)
            applyBreathingIfNeeded()
        }
        updateDistance(ann.distance)
    }

    // showGrids 切换时由 controller 调用，重新读取 hideRewardIcon 并刷新图标显隐/呼吸动画
    func refreshIconVisibility() {
        configure()
    }

    // 距离变化超阈值才刷新 label，避免每帧重排
    func updateDistance(_ distance: Double?) {
        let changed: Bool = {
            guard let new = distance, let old = lastDistance else { return distance != lastDistance }
            let threshold: Double = new < 1000 ? 1.0 : 10.0
            return abs(new - old) > threshold
        }()
        guard changed else { return }
        lastDistance = distance

        guard let distance else {
            distanceLabel.isHidden = true
            return
        }
        distanceLabel.isHidden = false
        distanceLabel.text = Self.formatDistance(distance)
        distanceLabel.sizeToFit()
        distanceLabel.frame = CGRect(
            x: (bounds.width - distanceLabel.bounds.width) / 2 - 4,
            y: -distanceLabel.bounds.height - 4,
            width: distanceLabel.bounds.width + 8,
            height: distanceLabel.bounds.height + 2
        )
    }

    static func formatDistance(_ d: Double) -> String {
        d < 1000 ? "\(Int(d.rounded()))m" : String(format: "%.1fkm", d / 1000)
    }
}

// 网格指引控制器：bike/running 两个 realtime map 共用，封装
// 1) 网格中心 annotation 的增量 add/remove + 实时距离刷新；
// 2) CADisplayLink 驱动的屏幕外边缘箭头（每个网格一套，指向其方位 + 距离）。
// 镜像 RouteRealtimeMapView 对「下一个检查点」的边缘箭头实现。
final class GridGuideController {
    weak var mapView: MKMapView?

    // 由 updateUIView 同步的输入
    var userLocation: CLLocation?
    var nearbyGrids: [NearbyGrid] = []
    var showGridGuide: Bool = false
    var showGrids: Bool = false             // showGrids 瓦片是否同时开启（开启时隐藏指引的 reward 图标，避免重叠）
    var isRecording: Bool = false
    var isShowSheet: Bool = false

    private var guideAnnotations: [String: NearbyGridGuideAnnotation] = [:]

    private struct ArrowViews {
        let container: UIView
        let image: UIImageView
        let label: UILabel
    }
    private var arrows: [String: ArrowViews] = [:]

    private var displayLink: CADisplayLink?
    private var proxy: DisplayLinkProxy?

    final class DisplayLinkProxy {
        weak var target: GridGuideController?
        init(target: GridGuideController) { self.target = target }
        @objc func step() { target?.step() }
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
        clearAll()
    }

    // 移除全部 annotation 与边缘箭头
    private func clearAll() {
        if let mapView, !guideAnnotations.isEmpty {
            mapView.removeAnnotations(Array(guideAnnotations.values))
        }
        guideAnnotations.removeAll()
        for a in arrows.values { a.container.removeFromSuperview() }
        arrows.removeAll()
    }

    // 根据 showGridGuide & nearbyGrids 增量同步网格 annotation，并刷新距离
    func sync() {
        guard let mapView else { return }

        guard showGridGuide && isRecording else {
            clearAll()
            return
        }

        let incomingIDs = Set(nearbyGrids.map { $0.id })

        // 移除已离开集合的网格
        for (id, ann) in guideAnnotations where !incomingIDs.contains(id) {
            mapView.removeAnnotation(ann)
            guideAnnotations[id] = nil
            arrows[id]?.container.removeFromSuperview()
            arrows[id] = nil
        }

        // 新增网格
        for grid in nearbyGrids where guideAnnotations[grid.id] == nil {
            let coord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: grid.lat, longitude: grid.lon))
            let ann = NearbyGridGuideAnnotation(id: grid.id, coordinate: coord, reward: grid.reward)
            ann.hideRewardIcon = showGrids
            guideAnnotations[grid.id] = ann
            mapView.addAnnotation(ann)
        }

        // 刷新距离 + reward 图标显隐（showGrids 切换时同步）
        if let user = userLocation {
            for grid in nearbyGrids {
                guard let ann = guideAnnotations[grid.id] else { continue }
                ann.distance = user.distance(from: CLLocation(latitude: grid.lat, longitude: grid.lon))
                if let view = mapView.view(for: ann) as? NearbyGridGuideAnnotationView {
                    if ann.hideRewardIcon != showGrids {
                        ann.hideRewardIcon = showGrids
                        view.refreshIconVisibility()
                    }
                    view.updateDistance(ann.distance)
                }
            }
        }
    }

    // 每帧：网格在可视区外时，在地图边缘画指向它的橙色箭头 + 距离
    @objc func step() {
        guard let mapView, showGridGuide, isRecording, let user = userLocation else {
            for a in arrows.values { a.container.isHidden = true }
            return
        }

        let insets = mapView.safeAreaInsets
        let topInset = insets.top + 10
        let bottomInset = (isShowSheet ? 520 : 220) + insets.bottom
        let rect = CGRect(
            x: 20,
            y: topInset,
            width: mapView.bounds.width - 40,
            height: mapView.bounds.height - topInset - bottomInset - 10
        )
        let visibleHeight = mapView.bounds.height - (isShowSheet ? 520 : 220)
        let center = CGPoint(x: mapView.bounds.midX, y: visibleHeight / 2)

        let activeIDs = Set(nearbyGrids.map { $0.id })
        // 隐藏已不在集合中的箭头
        for (id, a) in arrows where !activeIDs.contains(id) { a.container.isHidden = true }

        for grid in nearbyGrids {
            let coord = CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: grid.lat, longitude: grid.lon))
            let screenPoint = mapView.convert(coord, toPointTo: mapView)
            let arrow = arrowViews(for: grid.id, in: mapView)
            arrow.container.frame = mapView.bounds

            if rect.contains(screenPoint) {
                // 屏幕内：距离改由网格 annotation 上的 label 展示，隐藏边缘箭头
                arrow.container.isHidden = true
                continue
            }

            let dx = screenPoint.x - center.x
            let dy = screenPoint.y - center.y
            let angle = atan2(dx, -dy)
            let scaleX = dx == 0 ? CGFloat.infinity : (dx > 0 ? (rect.maxX - center.x) / dx : (rect.minX - center.x) / dx)
            let scaleY = dy == 0 ? CGFloat.infinity : (dy > 0 ? (rect.maxY - center.y) / dy : (rect.minY - center.y) / dy)
            let scale = min(scaleX, scaleY)
            let edgePoint = CGPoint(x: center.x + dx * scale, y: center.y + dy * scale)

            let distance = user.distance(from: CLLocation(latitude: grid.lat, longitude: grid.lon))

            arrow.container.isHidden = false
            arrow.image.center = edgePoint
            arrow.image.transform = CGAffineTransform(rotationAngle: angle)

            arrow.label.text = NearbyGridGuideAnnotationView.formatDistance(distance)
            arrow.label.sizeToFit()
            arrow.label.frame = CGRect(
                x: edgePoint.x - arrow.label.bounds.width / 2 - 4,
                y: edgePoint.y + 14,
                width: arrow.label.bounds.width + 8,
                height: arrow.label.bounds.height + 4
            )
        }
    }

    // 懒创建某网格的边缘箭头（橙色 arrow.up + 黑底距离 label），加为 mapView 子视图
    private func arrowViews(for id: String, in mapView: MKMapView) -> ArrowViews {
        if let existing = arrows[id] { return existing }

        let container = UIView(frame: mapView.bounds)
        container.isUserInteractionEnabled = false

        let image = UIImageView(image: UIImage(systemName: "arrow.up"))
        image.tintColor = .orange
        image.frame = CGRect(x: 0, y: 0, width: 24, height: 24)

        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true

        container.addSubview(image)
        container.addSubview(label)
        container.isHidden = true
        mapView.addSubview(container)

        let views = ArrowViews(container: container, image: image, label: label)
        arrows[id] = views
        return views
    }

    // 提供给 Coordinator 的 viewFor annotation 复用
    static func annotationView(for annotation: MKAnnotation, in mapView: MKMapView) -> MKAnnotationView? {
        guard annotation is NearbyGridGuideAnnotation else { return nil }
        if let view = mapView.dequeueReusableAnnotationView(withIdentifier: NearbyGridGuideAnnotationView.reuseID) as? NearbyGridGuideAnnotationView {
            view.annotation = annotation
            return view
        }
        return NearbyGridGuideAnnotationView(annotation: annotation, reuseIdentifier: NearbyGridGuideAnnotationView.reuseID)
    }
}

