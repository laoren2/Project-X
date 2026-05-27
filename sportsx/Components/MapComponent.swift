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
            var coords = path.map { CoordinateConverter.parseCoordinate(coordinate: CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon)) }
            let polyline = SpeedPolyline(coordinates: &coords, count: coords.count)
            polyline.speeds = path.map { $0.speed }
            mapView.addOverlay(polyline)
            mapView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: false)
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
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.showGrids = showGrids
        
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
            if let firstPolyline = makePolyline(from: path) {
                mapView.addOverlay(firstPolyline, level: .aboveLabels)
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
        mapView.addOverlay(polyline, level: .aboveLabels)
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
        
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.showGrids = showGrids
        
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
            if let firstPolyline = makePolyline(from: path) {
                mapView.addOverlay(firstPolyline, level: .aboveLabels)
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
        mapView.addOverlay(polyline, level: .aboveLabels)
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

