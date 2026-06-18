//
//  LocationManager.swift
//  sportsx
//
//  全局单例 + Combine 模式管理Location的更新，不同场景 -> 不同更新策略
//
//  可能存在订阅/取消订阅失败的情况，例如频繁快速订阅/取消订阅
//  场景之一是在某些容器视图（例如scrollview）内子视图appear和disappear时进行订阅和取消订阅，此时可能会频繁调用，
//  可能导致出现增加无效的订阅，后期可以考虑使用全局锁来锁住订阅和取消订阅的全过程
//
//  Created by 任杰 on 2024/12/6.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI
import MapKit


enum GPSStrength: String {
    case excellent, good, fair, poor, unknown
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .yellow
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .gray
        }
    }
    
    var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .poor: return 1
        case .unknown: return 0
        }
    }
}

struct Region: Identifiable, Equatable {
    var id: String { return regionID }
    let regionID: String
    let regionName: String
    
    static func == (lhs: Region, rhs: Region) -> Bool {
        return lhs.regionID == rhs.regionID
    }
}

final class RegionBoundaryStore {
    static let shared = RegionBoundaryStore()
    private init() {}
    
    // 简单缓存
    private var cache: [String: [MKPolygon]] = [:]
    
    func getBoundary(for regionID: String) async -> [MKPolygon] {
        // 有缓存直接返回
        if let cached = cache[regionID], !cached.isEmpty {
            return cached
        }
        
        // 没有就加载
        let boundary = await fetchBoundary(regionID: regionID)
        
        // 写缓存（主线程写，避免线程问题）
        await MainActor.run {
            self.cache[regionID] = boundary
        }
        
        return boundary
    }
    
    func fetchBoundary(regionID: String) async -> [MKPolygon] {
        var components = URLComponents(string: "/common/region_boundary")
        components?.queryItems = [
            URLQueryItem(name: "region_id", value: regionID)
        ]
        guard let urlPath = components?.url?.absoluteString else { return [] }
        
        let request = APIRequest(path: urlPath, method: .get)
        
        let result = await NetworkService.sendAsyncRequest(
            with: request,
            decodingType: JSONValue.self,
            showLoadingToast: true,
            showErrorToast: true
        )
        switch result {
        case .success(let data):
            guard let data else { return [] }
            return parseGeoJSON(data)
        default:
            return []
        }
    }
    
    func parseGeoJSON(_ boundary: JSONValue) -> [MKPolygon] {
        guard let data = boundary.toData() else { return [] }
        do {
            let features = try MKGeoJSONDecoder().decode(data)
            var polygons: [MKPolygon] = []
            for feature in features {
                guard let geoFeature = feature as? MKGeoJSONFeature else { continue }
                for geometry in geoFeature.geometry {
                    if let polygon = geometry as? MKPolygon {
                        polygons.append(polygon)
                    } else if let multi = geometry as? MKMultiPolygon {
                        polygons.append(contentsOf: multi.polygons)
                    }
                }
            }
            return polygons
        } catch {
            print("GeoJSON parse error:", error)
            return []
        }
    }
}

// todo: 考虑统一放到服务端管理regions
let regionTable_CN: [String: [Region]] = [
    "region.cn.shanghai": [Region(regionID: "CN-SH-SH", regionName: "region.cn.shanghai")],
    "region.cn.beijing": [Region(regionID: "CN-BJ-BJ", regionName: "region.cn.beijing")],
    "region.cn.guangdong": [
        Region(regionID: "CN-GD-GZ", regionName: "region.cn.guangzhou"),
        Region(regionID: "CN-GD-SZ", regionName: "region.cn.shenzhen"),
        Region(regionID: "CN-GD-FS", regionName: "region.cn.foshan")
    ],
    "region.cn.zhejiang": [
        Region(regionID: "CN-ZJ-HZ", regionName: "region.cn.hangzhou"),
        Region(regionID: "CN-ZJ-WZ", regionName: "region.cn.wenzhou"),
        Region(regionID: "CN-ZJ-NB", regionName: "region.cn.ningbo")
    ],
    "region.cn.jiangsu": [
        Region(regionID: "CN-JS-NJ", regionName: "region.cn.nanjing"),
        Region(regionID: "CN-JS-SZ", regionName: "region.cn.suzhou"),
        Region(regionID: "CN-JS-WX", regionName: "region.cn.wuxi")
    ],
    "region.cn.anhui": [
        Region(regionID: "CN-AH-HF", regionName: "region.cn.hefei"),
        Region(regionID: "CN-AH-HS", regionName: "region.cn.huangshan")
    ]
]

let regionTable_HK: [String: [Region]] = [
    "region.hk.xianggangdao": [
        Region(regionID: "HK-SOUTHERN", regionName: "region.hk.nanqu"),
        Region(regionID: "HK-CENTRAL-AND-WESTERN", regionName: "region.hk.zhongxiqu"),
        Region(regionID: "HK-WAN-CHAI", regionName: "region.hk.wanzaiqu"),
        Region(regionID: "HK-EASTERN", regionName: "region.hk.dongqu")
    ],
    "region.hk.jiulong": [
        Region(regionID: "HK-KWUN-TONG", regionName: "region.hk.guantangqu"),
        Region(regionID: "HK-KOWLOON-CITY", regionName: "region.hk.jiulongchengqu"),
        Region(regionID: "HK-YAU-TSIM-MONG", regionName: "region.hk.youjianwangqu"),
        Region(regionID: "HK-SHAM-SHUI-PO", regionName: "region.hk.shenshuipo"),
        Region(regionID: "HK-WONG-TAI-SIN", regionName: "region.hk.huangdaxianqu")
    ],
    "region.hk.xinjie": [
        Region(regionID: "HK-NORTH", regionName: "region.hk.beiqu"),
        Region(regionID: "HK-ISLANDS", regionName: "region.hk.lidaoqu"),
        Region(regionID: "HK-TSUEN-WAN", regionName: "region.hk.quanwan"),
        Region(regionID: "HK-TAI-PO", regionName: "region.hk.dapuqu"),
        Region(regionID: "HK-SHA-TIN", regionName: "region.hk.shatianqu"),
        Region(regionID: "HK-SAI-KUNG", regionName: "region.hk.xigongqu"),
        Region(regionID: "HK-KWAI-TSING", regionName: "region.hk.kuiqingqu"),
        Region(regionID: "HK-TUEN-MUN", regionName: "region.hk.tunmenqu"),
        Region(regionID: "HK-YUEN-LONG", regionName: "region.hk.yuanlangqu")
    ]
]

let regionTable_TW: [String: [Region]] = [
    "region.tw.beiqu": [
        Region(regionID: "TW-TAI-PEI-CITY", regionName: "region.tw.taibei"),
        Region(regionID: "TW-NEW-TAI-PEI-CITY", regionName: "region.tw.xinbei"),
        Region(regionID: "TW-KEE-LUNG-CITY", regionName: "region.tw.jilong"),
        Region(regionID: "TW-TAO-YUAN", regionName: "region.tw.taoyuan"),
        Region(regionID: "TW-HSIN-CHU-CITY", regionName: "region.tw.xinzhushi"),
        Region(regionID: "TW-HSIN-CHU", regionName: "region.tw.xinzhu"),
        Region(regionID: "TW-YI-LAN", regionName: "region.tw.yilan")
    ],
    "region.tw.zhongqu": [
        Region(regionID: "TW-MIAO-LI", regionName: "region.tw.miaoli"),
        Region(regionID: "TW-TAI-CHUNG", regionName: "region.tw.taizhong"),
        Region(regionID: "TW-CHANG-HUA", regionName: "region.tw.zhanghua"),
        Region(regionID: "TW-NAN-TOU", regionName: "region.tw.nantou"),
        Region(regionID: "TW-YUN-LIN", regionName: "region.tw.yunlin")
    ],
    "region.tw.nanqu": [
        Region(regionID: "TW-CHIA-YI-CITY", regionName: "region.tw.jiayishi"),
        Region(regionID: "TW-CHIA-YI", regionName: "region.tw.jiayi"),
        Region(regionID: "TW-TAI-NAN-CITY", regionName: "region.tw.tainan"),
        Region(regionID: "TW-KAOH-SIUNG-CITY", regionName: "region.tw.gaoxiong"),
        Region(regionID: "TW-PING-TUNG", regionName: "region.tw.pingdong"),
        Region(regionID: "TW-PENG-HU", regionName: "region.tw.penghu")
    ],
    "region.tw.dongqu": [
        Region(regionID: "TW-TAI-TUNG", regionName: "region.tw.taidong"),
        Region(regionID: "TW-HUA-LIEN", regionName: "region.tw.hualian")
    ],
    "region.tw.waidao": [
        Region(regionID: "TW-KIN-MEN", regionName: "region.tw.jinmen"),
        Region(regionID: "TW-MATSU-ISLANDS", regionName: "region.tw.mazu")
    ]
]

let regionTable_KR: [String: [Region]] = [
    "region.kr.gongwan": [
        Region(regionID: "KR-GONG-WAN", regionName: "region.kr.gongwan")
    ],
    "region.kr.gyeonggi": [
        Region(regionID: "KR-GYEONG-GI", regionName: "region.kr.gyeonggi")
    ],
    "region.kr.southchungcheong": [
        Region(regionID: "KR-SOUTH-CHUNG-CHEONG", regionName: "region.kr.southchungcheong")
    ],
    "region.kr.incheon": [
        Region(regionID: "KR-IN-CHEON", regionName: "region.kr.incheon")
    ],
    "region.kr.northjeolla": [
        Region(regionID: "KR-NORTH-JEOLLA", regionName: "region.kr.northjeolla")
    ],
    "region.kr.southjeolla": [
        Region(regionID: "KR-SOUTH-JEOLLA", regionName: "region.kr.southjeolla")
    ],
    "region.kr.southgyeongsang": [
        Region(regionID: "KR-SOUTH-GYEONG-SANG", regionName: "region.kr.southgyeongsang")
    ],
    "region.kr.busan": [
        Region(regionID: "KR-BU-SAN", regionName: "region.kr.busan")
    ],
    "region.kr.ulsan": [
        Region(regionID: "KR-UL-SAN", regionName: "region.kr.ulsan")
    ],
    "region.kr.northgyeongsang": [
        Region(regionID: "KR-NORTH-GYEONG-SANG", regionName: "region.kr.northgyeongsang")
    ],
    "region.kr.jeju": [
        Region(regionID: "KR-JE-JU", regionName: "region.kr.jeju")
    ],
    "region.kr.seoul": [
        Region(regionID: "KR-SEO-UL", regionName: "region.kr.seoul")
    ],
    "region.kr.daejeon": [
        Region(regionID: "KR-DAE-JEON", regionName: "region.kr.daejeon")
    ],
    "region.kr.sejong": [
        Region(regionID: "KR-SE-JONG", regionName: "region.kr.sejong")
    ],
    "region.kr.northchungcheong": [
        Region(regionID: "KR-NORTH-CHUNG-CHEONG", regionName: "region.kr.northchungcheong")
    ],
    "region.kr.gwangju": [
        Region(regionID: "KR-GWANG-JU", regionName: "region.kr.gwangju")
    ],
    "region.kr.daegu": [
        Region(regionID: "KR-DAE-GU", regionName: "region.kr.daegu")
    ]
]

let regionTable_US: [String: [Region]] = [
    "region.us.northeast": [
        Region(regionID: "US-MAINE", regionName: "region.us.maine"),
        Region(regionID: "US-NEW-HAMPSHIRE", regionName: "region.us.newhampshire"),
        Region(regionID: "US-VERMONT", regionName: "region.us.vermont"),
        Region(regionID: "US-MASSACHUSETTS", regionName: "region.us.massachusetts"),
        Region(regionID: "US-RHODE-ISLAND", regionName: "region.us.rhodeisland"),
        Region(regionID: "US-CONNECTICUT", regionName: "region.us.connecticut"),
        Region(regionID: "US-NEW-YORK", regionName: "region.us.newyork"),
        Region(regionID: "US-NEW-JERSEY", regionName: "region.us.newjersey"),
        Region(regionID: "US-PENNSYLVANIA", regionName: "region.us.pennsylvania"),
        Region(regionID: "US-DELAWARE", regionName: "region.us.delaware"),
        Region(regionID: "US-MARYLAND", regionName: "region.us.maryland"),
        Region(regionID: "US-WASHINGTONDC", regionName: "region.us.washingtondc")
    ],
    "region.us.midwest": [
        Region(regionID: "US-OHIO", regionName: "region.us.ohio"),
        Region(regionID: "US-MICHIGAN", regionName: "region.us.michigan"),
        Region(regionID: "US-INDIANA", regionName: "region.us.indiana"),
        Region(regionID: "US-ILLINOIS", regionName: "region.us.illinois"),
        Region(regionID: "US-WISCONSIN", regionName: "region.us.wisconsin"),
        Region(regionID: "US-MINNESOTA", regionName: "region.us.minnesota"),
        Region(regionID: "US-IOWA", regionName: "region.us.iowa"),
        Region(regionID: "US-MISSOURI", regionName: "region.us.missouri"),
        Region(regionID: "US-NORTH-DAKOTA", regionName: "region.us.northdakota"),
        Region(regionID: "US-SOUTH-DAKOTA", regionName: "region.us.southdakota"),
        Region(regionID: "US-NEBRASKA", regionName: "region.us.nebraska"),
        Region(regionID: "US-KANSAS", regionName: "region.us.kansas")
    ],
    "region.us.southeast": [
        Region(regionID: "US-VIRGINIA", regionName: "region.us.virginia"),
        Region(regionID: "US-WEST-VIRGINIA", regionName: "region.us.westvirginia"),
        Region(regionID: "US-KENTUCKY", regionName: "region.us.kentucky"),
        Region(regionID: "US-NORTH-CAROLINA", regionName: "region.us.northcarolina"),
        Region(regionID: "US-SOUTH-CAROLINA", regionName: "region.us.southcarolina"),
        Region(regionID: "US-TENNESSEE", regionName: "region.us.tennessee"),
        Region(regionID: "US-GEORGIA", regionName: "region.us.georgia"),
        Region(regionID: "US-FLORIDA", regionName: "region.us.florida"),
        Region(regionID: "US-ALABAMA", regionName: "region.us.alabama"),
        Region(regionID: "US-MISSISSIPPI", regionName: "region.us.mississippi"),
        Region(regionID: "US-ARKANSAS", regionName: "region.us.arkansas"),
        Region(regionID: "US-LOUISIANA", regionName: "region.us.louisiana")
    ],
    "region.us.southwest": [
        Region(regionID: "US-TEXAS", regionName: "region.us.texas"),
        Region(regionID: "US-OKLAHOMA", regionName: "region.us.oklahoma"),
        Region(regionID: "US-NEW-MEXICO", regionName: "region.us.newmexico"),
        Region(regionID: "US-ARIZONA", regionName: "region.us.arizona")
    ],
    "region.us.west": [
        Region(regionID: "US-COLORADO", regionName: "region.us.colorado"),
        Region(regionID: "US-WYOMING", regionName: "region.us.wyoming"),
        Region(regionID: "US-MONTANA", regionName: "region.us.montana"),
        Region(regionID: "US-IDAHO", regionName: "region.us.idaho"),
        Region(regionID: "US-UTAH", regionName: "region.us.utah"),
        Region(regionID: "US-NEVADA", regionName: "region.us.nevada"),
        Region(regionID: "US-CALIFORNIA", regionName: "region.us.california"),
        Region(regionID: "US-OREGON", regionName: "region.us.oregon"),
        Region(regionID: "US-WASHINGTON", regionName: "region.us.washington"),
        Region(regionID: "US-ALASKA", regionName: "region.us.alaska"),
        Region(regionID: "US-HAWAII", regionName: "region.us.hawaii")
    ]
]

let regionTable_JP: [String: [Region]] = [
    "region.jp.hokkaido": [
        Region(regionID: "JP-01", regionName: "region.jp.hokkaido")
    ],
    "region.jp.tohoku": [
        Region(regionID: "JP-02", regionName: "region.jp.aomori"),
        Region(regionID: "JP-03", regionName: "region.jp.iwate"),
        Region(regionID: "JP-04", regionName: "region.jp.miyagi"),
        Region(regionID: "JP-05", regionName: "region.jp.akita"),
        Region(regionID: "JP-06", regionName: "region.jp.yamagata"),
        Region(regionID: "JP-07", regionName: "region.jp.fukushima")
    ],
    "region.jp.kanto": [
        Region(regionID: "JP-08", regionName: "region.jp.ibaraki"),
        Region(regionID: "JP-09", regionName: "region.jp.tochigi"),
        Region(regionID: "JP-10", regionName: "region.jp.gunma"),
        Region(regionID: "JP-11", regionName: "region.jp.saitama"),
        Region(regionID: "JP-12", regionName: "region.jp.chiba"),
        Region(regionID: "JP-13", regionName: "region.jp.tokyo"),
        Region(regionID: "JP-14", regionName: "region.jp.kanagawa")
    ],
    "region.jp.chubu": [
        Region(regionID: "JP-15", regionName: "region.jp.niigata"),
        Region(regionID: "JP-16", regionName: "region.jp.toyama"),
        Region(regionID: "JP-17", regionName: "region.jp.ishikawa"),
        Region(regionID: "JP-18", regionName: "region.jp.fukui"),
        Region(regionID: "JP-19", regionName: "region.jp.yamanashi"),
        Region(regionID: "JP-20", regionName: "region.jp.nagano"),
        Region(regionID: "JP-21", regionName: "region.jp.gifu"),
        Region(regionID: "JP-22", regionName: "region.jp.shizuoka"),
        Region(regionID: "JP-23", regionName: "region.jp.aichi")
    ],
    "region.jp.kinki": [
        Region(regionID: "JP-24", regionName: "region.jp.mie"),
        Region(regionID: "JP-25", regionName: "region.jp.shiga"),
        Region(regionID: "JP-26", regionName: "region.jp.kyoto"),
        Region(regionID: "JP-27", regionName: "region.jp.osaka"),
        Region(regionID: "JP-28", regionName: "region.jp.hyogo"),
        Region(regionID: "JP-29", regionName: "region.jp.nara"),
        Region(regionID: "JP-30", regionName: "region.jp.wakayama")
    ],
    "region.jp.chugoku": [
        Region(regionID: "JP-31", regionName: "region.jp.tottori"),
        Region(regionID: "JP-32", regionName: "region.jp.shimane"),
        Region(regionID: "JP-33", regionName: "region.jp.okayama"),
        Region(regionID: "JP-34", regionName: "region.jp.hiroshima"),
        Region(regionID: "JP-35", regionName: "region.jp.yamaguchi")
    ],
    "region.jp.shikoku": [
        Region(regionID: "JP-36", regionName: "region.jp.tokushima"),
        Region(regionID: "JP-37", regionName: "region.jp.kagawa"),
        Region(regionID: "JP-38", regionName: "region.jp.ehime"),
        Region(regionID: "JP-39", regionName: "region.jp.kochi")
    ],
    "region.jp.kyushu": [
        Region(regionID: "JP-40", regionName: "region.jp.fukuoka"),
        Region(regionID: "JP-41", regionName: "region.jp.saga"),
        Region(regionID: "JP-42", regionName: "region.jp.nagasaki"),
        Region(regionID: "JP-43", regionName: "region.jp.kumamoto"),
        Region(regionID: "JP-44", regionName: "region.jp.oita"),
        Region(regionID: "JP-45", regionName: "region.jp.miyazaki"),
        Region(regionID: "JP-46", regionName: "region.jp.kagoshima"),
        Region(regionID: "JP-47", regionName: "region.jp.okinawa")
    ]
]

let regionTable_UK: [String: [Region]] = [
    "region.uk.england": [
        Region(regionID: "UK-ENG-LON", regionName: "region.uk.london"),
        Region(regionID: "UK-ENG-SE", regionName: "region.uk.southeast"),
        Region(regionID: "UK-ENG-SW", regionName: "region.uk.southwest"),
        Region(regionID: "UK-ENG-WM", regionName: "region.uk.west_midlands"),
        Region(regionID: "UK-ENG-NW", regionName: "region.uk.northwest"),
        Region(regionID: "UK-ENG-NE", regionName: "region.uk.northeast"),
        Region(regionID: "UK-ENG-YH", regionName: "region.uk.yorkshire_humber"),
        Region(regionID: "UK-ENG-EM", regionName: "region.uk.east_midlands"),
        Region(regionID: "UK-ENG-EE", regionName: "region.uk.east_of_england")
    ],
    "region.uk.scotland": [
        Region(regionID: "UK-SCT-CEN", regionName: "region.uk.central_scotland"),
        Region(regionID: "UK-SCT-HIG", regionName: "region.uk.highlands")
    ],
    "region.uk.wales": [
        Region(regionID: "UK-WLS-N", regionName: "region.uk.north_wales"),
        Region(regionID: "UK-WLS-S", regionName: "region.uk.south_wales")
    ],
    "region.uk.northern_ireland": [
        Region(regionID: "UK-NIR", regionName: "region.uk.northern_ireland")
    ]
]

let regionTable_CA: [String: [Region]] = [
    "region.ca.alberta": [
        Region(regionID: "CA-AB", regionName: "region.ca.alberta")
    ],
    "region.ca.british_columbia": [
        Region(regionID: "CA-BC", regionName: "region.ca.british_columbia")
    ],
    "region.ca.manitoba": [
        Region(regionID: "CA-MB", regionName: "region.ca.manitoba")
    ],
    "region.ca.new_brunswick": [
        Region(regionID: "CA-NB", regionName: "region.ca.new_brunswick")
    ],
    "region.ca.newfoundland_and_labrador": [
        Region(regionID: "CA-NL", regionName: "region.ca.newfoundland_and_labrador")
    ],
    "region.ca.nova_scotia": [
        Region(regionID: "CA-NS", regionName: "region.ca.nova_scotia")
    ],
    "region.ca.northwest_territories": [
        Region(regionID: "CA-NT", regionName: "region.ca.northwest_territories")
    ],
    "region.ca.nunavut": [
        Region(regionID: "CA-NU", regionName: "region.ca.nunavut")
    ],
    "region.ca.ontario": [
        Region(regionID: "CA-ON", regionName: "region.ca.ontario")
    ],
    "region.ca.prince_edward_island": [
        Region(regionID: "CA-PE", regionName: "region.ca.prince_edward_island")
    ],
    "region.ca.quebec": [
        Region(regionID: "CA-QC", regionName: "region.ca.quebec")
    ],
    "region.ca.saskatchewan": [
        Region(regionID: "CA-SK", regionName: "region.ca.saskatchewan")
    ],
    "region.ca.yukon": [
        Region(regionID: "CA-YT", regionName: "region.ca.yukon")
    ]
]

let regionTable_AU: [String: [Region]] = [
    "region.au.australian_capital_territory": [
        Region(regionID: "AU-ACT", regionName: "region.au.australian_capital_territory")
    ],
    "region.au.new_south_wales": [
        Region(regionID: "AU-NSW", regionName: "region.au.new_south_wales")
    ],
    "region.au.northern_territory": [
        Region(regionID: "AU-NT", regionName: "region.au.northern_territory")
    ],
    "region.au.queensland": [
        Region(regionID: "AU-QLD", regionName: "region.au.queensland")
    ],
    "region.au.south_australia": [
        Region(regionID: "AU-SA", regionName: "region.au.south_australia")
    ],
    "region.au.tasmania": [
        Region(regionID: "AU-TAS", regionName: "region.au.tasmania")
    ],
    "region.au.victoria": [
        Region(regionID: "AU-VIC", regionName: "region.au.victoria")
    ],
    "region.au.western_australia": [
        Region(regionID: "AU-WA", regionName: "region.au.western_australia")
    ]
]

// NL：由 tools/gen_regions.py 从 GISCO NUTS2 自动生成，勿手改；改粒度请改脚本重跑。
let regionTable_NL: [String: [Region]] = [
    "region.nl.nl11": [
        Region(regionID: "NL11", regionName: "region.nl.nl11")
    ],
    "region.nl.nl12": [
        Region(regionID: "NL12", regionName: "region.nl.nl12")
    ],
    "region.nl.nl13": [
        Region(regionID: "NL13", regionName: "region.nl.nl13")
    ],
    "region.nl.nl21": [
        Region(regionID: "NL21", regionName: "region.nl.nl21")
    ],
    "region.nl.nl22": [
        Region(regionID: "NL22", regionName: "region.nl.nl22")
    ],
    "region.nl.nl23": [
        Region(regionID: "NL23", regionName: "region.nl.nl23")
    ],
    "region.nl.nl31": [
        Region(regionID: "NL31", regionName: "region.nl.nl31")
    ],
    "region.nl.nl32": [
        Region(regionID: "NL32", regionName: "region.nl.nl32")
    ],
    "region.nl.nl33": [
        Region(regionID: "NL33", regionName: "region.nl.nl33")
    ],
    "region.nl.nl34": [
        Region(regionID: "NL34", regionName: "region.nl.nl34")
    ],
    "region.nl.nl41": [
        Region(regionID: "NL41", regionName: "region.nl.nl41")
    ],
    "region.nl.nl42": [
        Region(regionID: "NL42", regionName: "region.nl.nl42")
    ]
]

// FR：由 tools/gen_regions.py 从 GISCO NUTS3 自动生成，勿手改；改粒度请改脚本重跑。
let regionTable_FR: [String: [Region]] = [
    "region.fr.fr1": [
        Region(regionID: "FR101", regionName: "region.fr.fr101"),
        Region(regionID: "FR102", regionName: "region.fr.fr102"),
        Region(regionID: "FR103", regionName: "region.fr.fr103"),
        Region(regionID: "FR104", regionName: "region.fr.fr104"),
        Region(regionID: "FR105", regionName: "region.fr.fr105"),
        Region(regionID: "FR106", regionName: "region.fr.fr106"),
        Region(regionID: "FR107", regionName: "region.fr.fr107"),
        Region(regionID: "FR108", regionName: "region.fr.fr108")
    ],
    "region.fr.frb": [
        Region(regionID: "FRB01", regionName: "region.fr.frb01"),
        Region(regionID: "FRB02", regionName: "region.fr.frb02"),
        Region(regionID: "FRB03", regionName: "region.fr.frb03"),
        Region(regionID: "FRB04", regionName: "region.fr.frb04"),
        Region(regionID: "FRB05", regionName: "region.fr.frb05"),
        Region(regionID: "FRB06", regionName: "region.fr.frb06")
    ],
    "region.fr.frc": [
        Region(regionID: "FRC11", regionName: "region.fr.frc11"),
        Region(regionID: "FRC12", regionName: "region.fr.frc12"),
        Region(regionID: "FRC13", regionName: "region.fr.frc13"),
        Region(regionID: "FRC14", regionName: "region.fr.frc14"),
        Region(regionID: "FRC21", regionName: "region.fr.frc21"),
        Region(regionID: "FRC22", regionName: "region.fr.frc22"),
        Region(regionID: "FRC23", regionName: "region.fr.frc23"),
        Region(regionID: "FRC24", regionName: "region.fr.frc24")
    ],
    "region.fr.frd": [
        Region(regionID: "FRD11", regionName: "region.fr.frd11"),
        Region(regionID: "FRD12", regionName: "region.fr.frd12"),
        Region(regionID: "FRD13", regionName: "region.fr.frd13"),
        Region(regionID: "FRD21", regionName: "region.fr.frd21"),
        Region(regionID: "FRD22", regionName: "region.fr.frd22")
    ],
    "region.fr.fre": [
        Region(regionID: "FRE11", regionName: "region.fr.fre11"),
        Region(regionID: "FRE12", regionName: "region.fr.fre12"),
        Region(regionID: "FRE21", regionName: "region.fr.fre21"),
        Region(regionID: "FRE22", regionName: "region.fr.fre22"),
        Region(regionID: "FRE23", regionName: "region.fr.fre23")
    ],
    "region.fr.frf": [
        Region(regionID: "FRF11", regionName: "region.fr.frf11"),
        Region(regionID: "FRF12", regionName: "region.fr.frf12"),
        Region(regionID: "FRF21", regionName: "region.fr.frf21"),
        Region(regionID: "FRF22", regionName: "region.fr.frf22"),
        Region(regionID: "FRF23", regionName: "region.fr.frf23"),
        Region(regionID: "FRF24", regionName: "region.fr.frf24"),
        Region(regionID: "FRF31", regionName: "region.fr.frf31"),
        Region(regionID: "FRF32", regionName: "region.fr.frf32"),
        Region(regionID: "FRF33", regionName: "region.fr.frf33"),
        Region(regionID: "FRF34", regionName: "region.fr.frf34")
    ],
    "region.fr.frg": [
        Region(regionID: "FRG01", regionName: "region.fr.frg01"),
        Region(regionID: "FRG02", regionName: "region.fr.frg02"),
        Region(regionID: "FRG03", regionName: "region.fr.frg03"),
        Region(regionID: "FRG04", regionName: "region.fr.frg04"),
        Region(regionID: "FRG05", regionName: "region.fr.frg05")
    ],
    "region.fr.frh": [
        Region(regionID: "FRH01", regionName: "region.fr.frh01"),
        Region(regionID: "FRH02", regionName: "region.fr.frh02"),
        Region(regionID: "FRH03", regionName: "region.fr.frh03"),
        Region(regionID: "FRH04", regionName: "region.fr.frh04")
    ],
    "region.fr.fri": [
        Region(regionID: "FRI11", regionName: "region.fr.fri11"),
        Region(regionID: "FRI12", regionName: "region.fr.fri12"),
        Region(regionID: "FRI13", regionName: "region.fr.fri13"),
        Region(regionID: "FRI14", regionName: "region.fr.fri14"),
        Region(regionID: "FRI15", regionName: "region.fr.fri15"),
        Region(regionID: "FRI21", regionName: "region.fr.fri21"),
        Region(regionID: "FRI22", regionName: "region.fr.fri22"),
        Region(regionID: "FRI23", regionName: "region.fr.fri23"),
        Region(regionID: "FRI31", regionName: "region.fr.fri31"),
        Region(regionID: "FRI32", regionName: "region.fr.fri32"),
        Region(regionID: "FRI33", regionName: "region.fr.fri33"),
        Region(regionID: "FRI34", regionName: "region.fr.fri34")
    ],
    "region.fr.frj": [
        Region(regionID: "FRJ11", regionName: "region.fr.frj11"),
        Region(regionID: "FRJ12", regionName: "region.fr.frj12"),
        Region(regionID: "FRJ13", regionName: "region.fr.frj13"),
        Region(regionID: "FRJ14", regionName: "region.fr.frj14"),
        Region(regionID: "FRJ15", regionName: "region.fr.frj15"),
        Region(regionID: "FRJ21", regionName: "region.fr.frj21"),
        Region(regionID: "FRJ22", regionName: "region.fr.frj22"),
        Region(regionID: "FRJ23", regionName: "region.fr.frj23"),
        Region(regionID: "FRJ24", regionName: "region.fr.frj24"),
        Region(regionID: "FRJ25", regionName: "region.fr.frj25"),
        Region(regionID: "FRJ26", regionName: "region.fr.frj26"),
        Region(regionID: "FRJ27", regionName: "region.fr.frj27"),
        Region(regionID: "FRJ28", regionName: "region.fr.frj28")
    ],
    "region.fr.frk": [
        Region(regionID: "FRK11", regionName: "region.fr.frk11"),
        Region(regionID: "FRK12", regionName: "region.fr.frk12"),
        Region(regionID: "FRK13", regionName: "region.fr.frk13"),
        Region(regionID: "FRK14", regionName: "region.fr.frk14"),
        Region(regionID: "FRK21", regionName: "region.fr.frk21"),
        Region(regionID: "FRK22", regionName: "region.fr.frk22"),
        Region(regionID: "FRK23", regionName: "region.fr.frk23"),
        Region(regionID: "FRK24", regionName: "region.fr.frk24"),
        Region(regionID: "FRK25", regionName: "region.fr.frk25"),
        Region(regionID: "FRK26", regionName: "region.fr.frk26"),
        Region(regionID: "FRK27", regionName: "region.fr.frk27"),
        Region(regionID: "FRK28", regionName: "region.fr.frk28")
    ],
    "region.fr.frl": [
        Region(regionID: "FRL01", regionName: "region.fr.frl01"),
        Region(regionID: "FRL02", regionName: "region.fr.frl02"),
        Region(regionID: "FRL03", regionName: "region.fr.frl03"),
        Region(regionID: "FRL04", regionName: "region.fr.frl04"),
        Region(regionID: "FRL05", regionName: "region.fr.frl05"),
        Region(regionID: "FRL06", regionName: "region.fr.frl06")
    ],
    "region.fr.frm": [
        Region(regionID: "FRM01", regionName: "region.fr.frm01"),
        Region(regionID: "FRM02", regionName: "region.fr.frm02")
    ],
    "region.fr.fry": [
        Region(regionID: "FRY10", regionName: "region.fr.fry10"),
        Region(regionID: "FRY20", regionName: "region.fr.fry20"),
        Region(regionID: "FRY30", regionName: "region.fr.fry30"),
        Region(regionID: "FRY40", regionName: "region.fr.fry40"),
        Region(regionID: "FRY50", regionName: "region.fr.fry50")
    ]
]

// NZ：由 tools/gen_regions_geo.py 从 geoBoundaries ADM1 自动生成，勿手改；改粒度/译名请改脚本重跑。
let regionTable_NZ: [String: [Region]] = [
    "region.nz.north_island": [
        Region(regionID: "NZ-NTL", regionName: "region.nz.northland"),
        Region(regionID: "NZ-AUK", regionName: "region.nz.auckland"),
        Region(regionID: "NZ-WKO", regionName: "region.nz.waikato"),
        Region(regionID: "NZ-BOP", regionName: "region.nz.bay_of_plenty"),
        Region(regionID: "NZ-GIS", regionName: "region.nz.gisborne"),
        Region(regionID: "NZ-HKB", regionName: "region.nz.hawkes_bay"),
        Region(regionID: "NZ-TKI", regionName: "region.nz.taranaki"),
        Region(regionID: "NZ-MWT", regionName: "region.nz.manawatu_whanganui"),
        Region(regionID: "NZ-WGN", regionName: "region.nz.wellington")
    ],
    "region.nz.south_island": [
        Region(regionID: "NZ-TAS", regionName: "region.nz.tasman"),
        Region(regionID: "NZ-NLS", regionName: "region.nz.nelson"),
        Region(regionID: "NZ-MBH", regionName: "region.nz.marlborough"),
        Region(regionID: "NZ-WTC", regionName: "region.nz.west_coast"),
        Region(regionID: "NZ-CAN", regionName: "region.nz.canterbury"),
        Region(regionID: "NZ-OTA", regionName: "region.nz.otago"),
        Region(regionID: "NZ-STL", regionName: "region.nz.southland"),
        Region(regionID: "NZ-CIT", regionName: "region.nz.chatham_islands")
    ]
]

// IE：由 tools/gen_regions_geo.py 从 Natural Earth admin-1 自动生成（按 iso_3166_2 合并郡内拆分），勿手改；改粒度/译名请改脚本重跑。
let regionTable_IE: [String: [Region]] = [
    "region.ie.leinster": [
        Region(regionID: "IE-CW", regionName: "region.ie.carlow"),
        Region(regionID: "IE-D", regionName: "region.ie.dublin"),
        Region(regionID: "IE-KE", regionName: "region.ie.kildare"),
        Region(regionID: "IE-KK", regionName: "region.ie.kilkenny"),
        Region(regionID: "IE-LS", regionName: "region.ie.laois"),
        Region(regionID: "IE-LD", regionName: "region.ie.longford"),
        Region(regionID: "IE-LH", regionName: "region.ie.louth"),
        Region(regionID: "IE-MH", regionName: "region.ie.meath"),
        Region(regionID: "IE-OY", regionName: "region.ie.offaly"),
        Region(regionID: "IE-WH", regionName: "region.ie.westmeath"),
        Region(regionID: "IE-WX", regionName: "region.ie.wexford"),
        Region(regionID: "IE-WW", regionName: "region.ie.wicklow")
    ],
    "region.ie.munster": [
        Region(regionID: "IE-CE", regionName: "region.ie.clare"),
        Region(regionID: "IE-CO", regionName: "region.ie.cork"),
        Region(regionID: "IE-KY", regionName: "region.ie.kerry"),
        Region(regionID: "IE-LK", regionName: "region.ie.limerick"),
        Region(regionID: "IE-TA", regionName: "region.ie.tipperary"),
        Region(regionID: "IE-WD", regionName: "region.ie.waterford")
    ],
    "region.ie.connacht": [
        Region(regionID: "IE-G", regionName: "region.ie.galway"),
        Region(regionID: "IE-LM", regionName: "region.ie.leitrim"),
        Region(regionID: "IE-MO", regionName: "region.ie.mayo"),
        Region(regionID: "IE-RN", regionName: "region.ie.roscommon"),
        Region(regionID: "IE-SO", regionName: "region.ie.sligo")
    ],
    "region.ie.ulster": [
        Region(regionID: "IE-CN", regionName: "region.ie.cavan"),
        Region(regionID: "IE-DL", regionName: "region.ie.donegal"),
        Region(regionID: "IE-MN", regionName: "region.ie.monaghan")
    ]
]

// SG：由 tools/gen_regions_geo.py 从 geoBoundaries ADM2(URA 规划区) 自动生成，按 5 大区分组，勿手改；改粒度/译名请改脚本重跑。
let regionTable_SG: [String: [Region]] = [
    "region.sg.central": [
        Region(regionID: "SG-BISHAN", regionName: "region.sg.bishan"),
        Region(regionID: "SG-BUKIT-MERAH", regionName: "region.sg.bukit_merah"),
        Region(regionID: "SG-BUKIT-TIMAH", regionName: "region.sg.bukit_timah"),
        Region(regionID: "SG-DOWNTOWN-CORE", regionName: "region.sg.downtown_core"),
        Region(regionID: "SG-GEYLANG", regionName: "region.sg.geylang"),
        Region(regionID: "SG-KALLANG", regionName: "region.sg.kallang"),
        Region(regionID: "SG-MARINA-EAST", regionName: "region.sg.marina_east"),
        Region(regionID: "SG-MARINA-SOUTH", regionName: "region.sg.marina_south"),
        Region(regionID: "SG-MARINE-PARADE", regionName: "region.sg.marine_parade"),
        Region(regionID: "SG-MUSEUM", regionName: "region.sg.museum"),
        Region(regionID: "SG-NEWTON", regionName: "region.sg.newton"),
        Region(regionID: "SG-NOVENA", regionName: "region.sg.novena"),
        Region(regionID: "SG-ORCHARD", regionName: "region.sg.orchard"),
        Region(regionID: "SG-OUTRAM", regionName: "region.sg.outram"),
        Region(regionID: "SG-QUEENSTOWN", regionName: "region.sg.queenstown"),
        Region(regionID: "SG-RIVER-VALLEY", regionName: "region.sg.river_valley"),
        Region(regionID: "SG-ROCHOR", regionName: "region.sg.rochor"),
        Region(regionID: "SG-SINGAPORE-RIVER", regionName: "region.sg.singapore_river"),
        Region(regionID: "SG-SOUTHERN-ISLANDS", regionName: "region.sg.southern_islands"),
        Region(regionID: "SG-STRAITS-VIEW", regionName: "region.sg.straits_view"),
        Region(regionID: "SG-TANGLIN", regionName: "region.sg.tanglin"),
        Region(regionID: "SG-TOA-PAYOH", regionName: "region.sg.toa_payoh")
    ],
    "region.sg.east": [
        Region(regionID: "SG-BEDOK", regionName: "region.sg.bedok"),
        Region(regionID: "SG-CHANGI", regionName: "region.sg.changi"),
        Region(regionID: "SG-CHANGI-BAY", regionName: "region.sg.changi_bay"),
        Region(regionID: "SG-PASIR-RIS", regionName: "region.sg.pasir_ris"),
        Region(regionID: "SG-PAYA-LEBAR", regionName: "region.sg.paya_lebar"),
        Region(regionID: "SG-TAMPINES", regionName: "region.sg.tampines")
    ],
    "region.sg.north": [
        Region(regionID: "SG-CENTRAL-WATER-CATCHMENT", regionName: "region.sg.central_water_catchment"),
        Region(regionID: "SG-LIM-CHU-KANG", regionName: "region.sg.lim_chu_kang"),
        Region(regionID: "SG-MANDAI", regionName: "region.sg.mandai"),
        Region(regionID: "SG-SEMBAWANG", regionName: "region.sg.sembawang"),
        Region(regionID: "SG-SIMPANG", regionName: "region.sg.simpang"),
        Region(regionID: "SG-SUNGEI-KADUT", regionName: "region.sg.sungei_kadut"),
        Region(regionID: "SG-WOODLANDS", regionName: "region.sg.woodlands"),
        Region(regionID: "SG-YISHUN", regionName: "region.sg.yishun")
    ],
    "region.sg.north_east": [
        Region(regionID: "SG-ANG-MO-KIO", regionName: "region.sg.ang_mo_kio"),
        Region(regionID: "SG-HOUGANG", regionName: "region.sg.hougang"),
        Region(regionID: "SG-NORTH-EASTERN-ISLANDS", regionName: "region.sg.north_eastern_islands"),
        Region(regionID: "SG-PUNGGOL", regionName: "region.sg.punggol"),
        Region(regionID: "SG-SELETAR", regionName: "region.sg.seletar"),
        Region(regionID: "SG-SENGKANG", regionName: "region.sg.sengkang"),
        Region(regionID: "SG-SERANGOON", regionName: "region.sg.serangoon")
    ],
    "region.sg.west": [
        Region(regionID: "SG-BOON-LAY", regionName: "region.sg.boon_lay"),
        Region(regionID: "SG-BUKIT-BATOK", regionName: "region.sg.bukit_batok"),
        Region(regionID: "SG-BUKIT-PANJANG", regionName: "region.sg.bukit_panjang"),
        Region(regionID: "SG-CHOA-CHU-KANG", regionName: "region.sg.choa_chu_kang"),
        Region(regionID: "SG-CLEMENTI", regionName: "region.sg.clementi"),
        Region(regionID: "SG-JURONG-EAST", regionName: "region.sg.jurong_east"),
        Region(regionID: "SG-JURONG-WEST", regionName: "region.sg.jurong_west"),
        Region(regionID: "SG-PIONEER", regionName: "region.sg.pioneer"),
        Region(regionID: "SG-TENGAH", regionName: "region.sg.tengah"),
        Region(regionID: "SG-TUAS", regionName: "region.sg.tuas"),
        Region(regionID: "SG-WESTERN-ISLANDS", regionName: "region.sg.western_islands"),
        Region(regionID: "SG-WESTERN-WATER-CATCHMENT", regionName: "region.sg.western_water_catchment")
    ]
]

struct RegionStore {
    static let tables: [String: [String: [Region]]] = [
        "CN": regionTable_CN,
        "HK": regionTable_HK,
        "TW": regionTable_TW,
        "KR": regionTable_KR,
        "US": regionTable_US,
        "JP": regionTable_JP,
        "CA": regionTable_CA,
        "AU": regionTable_AU,
        "UK": regionTable_UK,
        "NL": regionTable_NL,
        "FR": regionTable_FR,
        "NZ": regionTable_NZ,
        "IE": regionTable_IE,
        "SG": regionTable_SG
    ]
    
    static let index: [String: Region] = {
        var dict: [String: Region] = [:]
        for (_, country) in tables {
            for (_, regions) in country {
                for r in regions {
                    dict[r.regionID] = r
                }
            }
        }
        return dict
    }()
}

/*enum RealNameMethod: String {
    case idcard = "idcard"
    case passport = "passport"
    case drivingLicense = "drivingLicense"
    
    var displayName: LocalizedStringKey {
        switch self {
        case .idcard: return "user.setup.realname_auth.method.idcard"
        case .passport: return "user.setup.realname_auth.method.passport"
        case .drivingLicense: return "user.setup.realname_auth.method.driving_license"
        }
    }
}*/

enum Country: String, CaseIterable {
    case hk = "HK"
    case tw = "TW"
    case kr = "KR"
    case cn = "CN"
    case us = "US"
    case jp = "JP"
    case ca = "CA"
    case au = "AU"
    case uk = "UK"
    case nl = "NL"
    case fr = "FR"
    case nz = "NZ"
    case ie = "IE"
    case sg = "SG"

    var supported: Bool {
        switch self {
        case .hk, .tw, .kr, .us, .jp, .ca, .au, .uk, .nl, .fr, .nz, .ie, .sg: return true
        case .cn: return false
        }
    }

    var phoneCode: String {
        switch self {
        case .hk: return "852"
        case .tw: return "886"
        case .kr: return "82"
        case .cn: return "86"
        case .us: return "1"
        case .jp: return "81"
        case .ca: return "1"
        case .au: return "61"
        case .uk: return "44"
        case .nl: return "31"
        case .fr: return "33"
        case .nz: return "64"
        case .ie: return "353"
        case .sg: return "65"
        }
    }

    var displayName: LocalizedStringKey {
        switch self {
        case .hk: return "region.hk"
        case .tw: return "region.tw"
        case .kr: return "region.kr"
        case .cn: return "region.cn"
        case .us: return "region.us"
        case .jp: return "region.jp"
        case .ca: return "region.ca"
        case .au: return "region.au"
        case .uk: return "region.uk"
        case .nl: return "region.nl"
        case .fr: return "region.fr"
        case .nz: return "region.nz"
        case .ie: return "region.ie"
        case .sg: return "region.sg"
        }
    }

    var phoneNumberLength: ClosedRange<Int> {
        switch self {
        case .hk: return 8...8
        case .tw: return 9...9
        case .kr: return 10...11
        case .cn: return 11...11
        case .us: return 10...10
        case .jp: return 11...11
        case .ca: return 10...10
        case .au: return 9...9
        case .uk: return 10...10
        case .nl: return 9...9
        case .fr: return 9...9
        case .nz: return 8...10
        case .ie: return 9...9
        case .sg: return 8...8
        }
    }
    
    /*var realnameMethod: [RealNameMethod] {
        switch self {
        case .hk: return [.idcard, .passport]
        case .tw: return [.idcard, .passport]
        case .kr: return [.idcard, .passport]
        case .cn: return [.idcard]
        case .us: return [.drivingLicense, .passport]
        }
    }*/
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    private var lastDesiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyKilometer
    private var lastDistanceFilter: CLLocationDistance = kCLLocationAccuracyKilometer
    private var lastAllowsBackgroundLocationUpdates: Bool = false
    private var lastPausesLocationUpdatesAutomatically: Bool = true
    
    // GPS信号强度
    @Published var signalStrength: GPSStrength = .unknown
    // 设备国家定位
    @Published var country: Country? = nil
    // 运动中心已选择的地区
    @Published var regionID: String? = nil
    var regionName: LocalizedStringKey? {
        guard let regionID = regionID, let region = RegionStore.index[regionID] else { return nil }
        return LocalizedStringKey(region.regionName)
    }
    @Published var regionBoundary: [MKPolygon] = []
    
    // 使用 @Published 来发布授权状态变化
    @Published var authorizationStatus: CLAuthorizationStatus
    
    // 使用 PassthroughSubject 发布位置更新
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    
    // 订阅者计数及其锁，确保多线程安全
    private var subscribersCount = 0
    private let subscribersCountLock = NSLock()
    
    // 全局锁，防止可能存在某些未知特殊情况下的订阅/取消订阅失败
    //let testLock = NSLock()
    
    private var cancellables = Set<AnyCancellable>()

    
    override private init() {
        // 初始化授权状态
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = kCLLocationAccuracyKilometer
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
        // 注意：此时并不立即开始更新位置，等待订阅者出现后再启动
        
        $regionID
            .removeDuplicates()
            .sink { [weak self] regionID in
                guard let self else { return }
                Task { @MainActor in
                    guard let regionID else {
                        self.regionBoundary = []
                        return
                    }
                    let boundary = await RegionBoundaryStore.shared.getBoundary(for: regionID)
                    self.regionBoundary = boundary
                }
            }
            .store(in: &cancellables)
    }
    
    // 提供位置更新的Publisher
    func locationPublisher() -> AnyPublisher<CLLocation, Never> {
        // 利用 handleEvents 在订阅和取消订阅时动态启动/停止位置更新
        return locationSubject
            .handleEvents(
                receiveSubscription: { [weak self] _ in
                    //print("receiveSubscription")
                    self?.incrementSubscribers()
                },
                receiveCancel: { [weak self] in
                    //print("receiveCancel")
                    self?.decrementSubscribers()
                }
            )
            .share()
            .eraseToAnyPublisher()
    }
    
    // 提供授权状态的Publisher（可直接使用 $authorizationStatus）
    // 如果想要AnyPublisher则：
    func authorizationPublisher() -> AnyPublisher<CLAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }
    
    // 检查准确位置权限
    func checkPreciseLocation() -> Bool {
        return locationManager.accuracyAuthorization == .fullAccuracy
    }
    
    private func incrementSubscribers() {
        subscribersCountLock.lock()
        subscribersCount += 1
        let count = subscribersCount
        subscribersCountLock.unlock()
        
        if count == 1 {
            // 第一个订阅者出现，开始位置更新（如果权限允许）
            startUpdatingLocationIfNeeded()
        }
        //print("incrementSubscribers - Thread: \(Thread.current)")
        //print("+count: ",count)
    }
    
    private func decrementSubscribers() {
        subscribersCountLock.lock()
        subscribersCount = max(subscribersCount - 1, 0)
        let count = subscribersCount
        subscribersCountLock.unlock()
        
        if count == 0 {
            // 没有订阅者了，停止位置更新以节省资源
            stopUpdatingLocation()
        }
        //print("decrementSubscribers - Thread: \(Thread.current)")
        //print("-count: ",count)
    }
    
    func startUpdatingLocationIfNeeded() {
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.startUpdatingLocation()
        } else if status == .notDetermined {
            // 请求WhenInUse权限
            locationManager.requestWhenInUseAuthorization()
        } else {
            // Denied或Restricted时无法启动更新
            DispatchQueue.main.async {
                PopupWindowManager.shared.presentPopup(
                    title: "competition.location_select.no_auth.popup.title",
                    message: "competition.location_select.no_auth.popup.content",
                    bottomButtons: [.confirm()]
                )
            }
        }
    }
    
    private func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // 手动强制开始位置更新
    func startUpdating() {
        // 调用此方法时，可确保即使没有订阅者也开始更新位置（谨慎使用）
        locationManager.startUpdatingLocation()
    }
    
    // 手动强制停止位置更新
    func stopUpdating() {
        locationManager.stopUpdatingLocation()
    }
    
    // 手动请求一次位置更新
    func requestUpdateOnce() {
        locationManager.requestLocation()
    }
    
    func getLocation() -> CLLocation? {
        return locationManager.location
    }
    
    func requestAlwaysAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }
    
    func changeToLowUpdate() {
        //print("LowUpdate")
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = kCLLocationAccuracyKilometer
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
    }
    
    func saveLowToLast() {
        lastDesiredAccuracy = kCLLocationAccuracyKilometer
        lastDistanceFilter = kCLLocationAccuracyKilometer
        lastPausesLocationUpdatesAutomatically = true
        lastAllowsBackgroundLocationUpdates = false
    }
    
    func changeToMediumUpdate() {
        //print("MediumUpdate")
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    func saveMediumToLast() {
        lastDesiredAccuracy = kCLLocationAccuracyBest
        lastDistanceFilter = kCLDistanceFilterNone
        lastPausesLocationUpdatesAutomatically = true
        lastAllowsBackgroundLocationUpdates = false
    }
    
    func changeToHighUpdate() {
        //print("HighUpdate")
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func backToLastSet() {
        locationManager.desiredAccuracy = lastDesiredAccuracy
        locationManager.distanceFilter = lastDistanceFilter
        locationManager.pausesLocationUpdatesAutomatically = lastPausesLocationUpdatesAutomatically
        locationManager.allowsBackgroundLocationUpdates = lastAllowsBackgroundLocationUpdates
        //print("back to \(locationManager.desiredAccuracy)")
        //print("back to \(locationManager.allowsBackgroundLocationUpdates)")
    }
    
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            //print("didChangeAuthorization to : \(status)")
            self.authorizationStatus = status
            // 授权状态改变后，如果有订阅者，应再次检查是否可以启动更新
            if self.subscribersCount > 0 && (status == .authorizedAlways || status == .authorizedWhenInUse) {
                self.startUpdatingLocationIfNeeded()
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        locationSubject.send(location)
        //print(locationManager.desiredAccuracy)
        //print(locationManager.allowsBackgroundLocationUpdates)
        DispatchQueue.main.async {
            let accuracy = location.horizontalAccuracy
            //print(accuracy)
            switch accuracy {
            case 0..<5:
                self.signalStrength = .excellent
            case 5..<10:
                self.signalStrength = .good
            case 10..<25:
                self.signalStrength = .fair
            case 25..<50:
                self.signalStrength = .poor
            default:
                self.signalStrength = .unknown
            }
        }
        //print("send location \(location)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("LocationManager failed with error: \(error)")
    }
}
