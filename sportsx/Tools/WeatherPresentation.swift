//
//  WeatherPresentation.swift
//  sportsx
//
//  统一天气条件（服务端 buff 条件、历史训练快照）与网格角标的展示规则。
//

import CoreLocation
import SwiftUI
import UIKit
import WeatherKit

enum WeatherConditionIcon: String {
    case clear
    case cloudy
    case rain
    case snow
    case fog

    var symbolName: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snowflake"
        case .fog: return "cloud.fog.fill"
        }
    }

    static func symbolName(for rawValue: String?, fallback: String = "cloud.sun.fill") -> String {
        WeatherConditionIcon(rawValue: rawValue ?? "")?.symbolName ?? fallback
    }
}

enum GridConditionBadge: Equatable {
    case asset(String)
    case systemSymbol(String)

    var uiImage: UIImage? {
        switch self {
        case .asset(let name):
            return UIImage(named: name)
        case .systemSymbol(let name):
            return UIImage(systemName: name)?.withTintColor(.white, renderingMode: .alwaysOriginal)
        }
    }
}

enum GridConditionPresentation {
    static func badge(conditionType: String, conditionParams: JSONValue? = nil) -> GridConditionBadge? {
        switch conditionType {
        case "distance":
            return .asset("buff_condition_distance")
        case "speed":
            return .asset("buff_condition_speed")
        case "weather":
            return .systemSymbol(WeatherConditionIcon.symbolName(for: conditionParams?["match"]?.stringValue))
        default:
            return nil
        }
    }
}

struct GridConditionBadgeImage: View {
    let badge: GridConditionBadge

    var body: some View {
        switch badge {
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
        case .systemSymbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.white)
        }
    }
}

struct CurrentWeatherSnapshot {
    let symbolName: String
    let temperatureCelsius: Double
    let location: CLLocation
    let fetchedAt: Date
    let expiresAt: Date

    var temperatureText: String {
        "\(Int(temperatureCelsius.rounded()))°C"
    }
}

/// 只用于 UI 展示的全局 WeatherKit 状态。
/// 同一有效期内且距离上次请求不足 15km 时复用缓存；相同区域的并发请求合并。
@MainActor
final class WeatherStore: ObservableObject {
    static let shared = WeatherStore()

    private static let reuseDistance: CLLocationDistance = 15_000
    private static let maximumCacheAge: TimeInterval = 15 * 60
    private static let failureRetryDelay: TimeInterval = 5 * 60

    @Published private(set) var snapshots: [CurrentWeatherSnapshot] = []
    @Published private(set) var attribution: WeatherAttribution?

    private var inFlightLocations: [CLLocation] = []
    private var recentAttempts: [(location: CLLocation, date: Date)] = []
    private var isLoadingAttribution = false

    private init() {}

    func snapshot(for location: CLLocation?) -> CurrentWeatherSnapshot? {
        guard let location else { return snapshots.max(by: { $0.fetchedAt < $1.fetchedAt }) }
        return snapshots
            .filter { location.distance(from: $0.location) <= Self.reuseDistance }
            .max(by: { $0.fetchedAt < $1.fetchedAt })
    }

    func refreshIfNeeded(for location: CLLocation?) {
        guard let location,
              location.horizontalAccuracy >= 0,
              location.coordinate.latitude.isFinite,
              location.coordinate.longitude.isFinite else { return }

        let now = Date()
        if let cached = snapshot(for: location), cached.expiresAt > now {
            return
        }
        recentAttempts.removeAll { now.timeIntervalSince($0.date) >= Self.failureRetryDelay }
        guard !recentAttempts.contains(where: {
            location.distance(from: $0.location) <= Self.reuseDistance
        }) else { return }
        guard !inFlightLocations.contains(where: { location.distance(from: $0) <= Self.reuseDistance }) else { return }

        recentAttempts.append((location, now))
        inFlightLocations.append(location)
        Task { [weak self] in
            defer {
                self?.inFlightLocations.removeAll { location.distance(from: $0) <= Self.reuseDistance }
            }
            do {
                //print("weather query...")
                let current = try await WeatherService.shared.weather(for: location, including: .current)
                let fetchedAt = Date()
                let providerExpiration = max(
                    current.metadata.expirationDate,
                    fetchedAt.addingTimeInterval(Self.failureRetryDelay)
                )
                let expiresAt = min(
                    providerExpiration,
                    fetchedAt.addingTimeInterval(Self.maximumCacheAge)
                )
                let snapshot = CurrentWeatherSnapshot(
                    symbolName: current.symbolName,
                    temperatureCelsius: current.temperature.converted(to: .celsius).value,
                    location: location,
                    fetchedAt: fetchedAt,
                    expiresAt: expiresAt
                )
                self?.store(snapshot)
            } catch {
                // 天气为装饰性信息：失败时保留旧缓存，不干扰训练流程，也不弹错误提示。
            }
        }
    }

    func loadAttributionIfNeeded() {
        guard attribution == nil, !isLoadingAttribution else { return }

        isLoadingAttribution = true
        Task { [weak self] in
            defer { self?.isLoadingAttribution = false }
            self?.attribution = try? await WeatherService.shared.attribution
        }
    }

    private func store(_ snapshot: CurrentWeatherSnapshot) {
        snapshots.removeAll { snapshot.location.distance(from: $0.location) <= Self.reuseDistance }
        snapshots.append(snapshot)
        if snapshots.count > 12 {
            snapshots.sort { $0.fetchedAt > $1.fetchedAt }
            snapshots.removeLast(snapshots.count - 12)
        }
    }
}

struct CurrentWeatherChip: View {
    enum Style {
        /// 地图顶部使用：天气信息纵向排布，不占用居中的运动图标空间。
        case mapOverlay
        /// 实时训练使用：与 GPS 状态模块保持相同的高度。
        case realtime
    }

    @ObservedObject private var weatherStore = WeatherStore.shared
    let location: CLLocation?
    let style: Style

    init(location: CLLocation?, style: Style = .realtime) {
        self.location = location
        self.style = style
    }

    var body: some View {
        if let weather = weatherStore.snapshot(for: location) {
            Group {
                if let attribution = weatherStore.attribution {
                    Link(destination: attribution.legalPageURL) {
                        chipContent(weather)
                    }
                    .accessibilityLabel("Apple Weather")
                } else {
                    chipContent(weather)
                }
            }
            .task {
                weatherStore.loadAttributionIfNeeded()
            }
        }
    }

    private func chipContent(_ weather: CurrentWeatherSnapshot) -> some View {
        Group {
            switch style {
            case .mapOverlay:
                VStack(spacing: 4) {
                    weatherSummary(weather, iconSize: 13, fontSize: 13)
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 50, height: 0.5)
                    attributionMark(height: 10)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            case .realtime:
                HStack(spacing: 6) {
                    weatherSummary(weather, iconSize: 14, fontSize: 13)
                    Rectangle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 0.5, height: 20)
                    attributionMark(height: 11)
                }
                .padding(.horizontal, 8)
                .frame(height: 32)
            }
        }
        .foregroundStyle(Color.white)
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func weatherSummary(_ weather: CurrentWeatherSnapshot, iconSize: CGFloat, fontSize: CGFloat) -> some View {
        HStack(spacing: 4) {
            Image(systemName: weather.symbolName)
                .font(.system(size: iconSize, weight: .semibold))
            Text(weather.temperatureText)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
        }
    }

    @ViewBuilder
    private func attributionMark(height: CGFloat) -> some View {
        if let attribution = weatherStore.attribution {
            AsyncImage(url: attribution.combinedMarkDarkURL) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                } else {
                    Color.clear
                }
            }
            .frame(width: height * 5.2, height: height)
        }
    }
}
