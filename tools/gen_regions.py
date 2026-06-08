#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_regions.py —— 从 Eurostat GISCO NUTS 数据生成 region 划分产物。

设计目标（见与团队的讨论）：
- 直接采用官方行政层级（“一步到位”），不手工合并几何。
- 二级分组（大区/省 → 子单元）完全来自 NUTS 编码前缀，无需任何几何运算。
- region_id 直接采用 NUTS_ID（如 FRK26 / NL32），保证“客户端 regionTable”与
  “服务端边界导入”共用同一主键。

当前粒度（团队选定：原生省级·偏粗）：
- 法国 FR：NUTS3 = 省（département，~101 个），按 NUTS1 = 大区分组。
- 荷兰 NL：NUTS2 = 省（12 个），扁平（每省一个 region，类似 CA/AU）。

================ 使用步骤 ================
1) 下载 GISCO NUTS（Polygon/RG，含全部层级）GeoJSON，EPSG:4326。
   ⚠️ 官网下载页常卡在“下载进行中”——直接打 CDN 文件地址即可绕过：
   curl -L -o nuts_all.geojson \
     "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/NUTS_RG_03M_2021_4326.geojson"
   （比例尺可选 01M/03M/10M/20M；年份 2021/2024。生成客户端表/本地化只看编码+名称，
     几何精度不影响；服务端边界导入想要更细可换 01M 再做 mapshaper 简化。
     要素属性含 NUTS_ID / LEVL_CODE / CNTR_CODE / NAME_LATN。）

2) （强烈建议）先用 mapshaper 做“拓扑保持简化”，避免相邻边界出现缝隙/重叠：
   mapshaper NUTS_RG_01M_2021_4326.geojson \
     -simplify visvalingam keep-shapes interval=150 \
     -clean \
     -o nuts_simplified.geojson format=geojson precision=0.00001
   （interval 单位是米；按 500m 网格玩法，100~250m 足够。）

3) 生成产物：
   python3 tools/gen_regions.py nuts_simplified.geojson --out-dir build_regions

   产出：
   - build_regions/RegionTables.generated.swift   # regionTable_NL / regionTable_FR（直接替换 LocationManager.swift 中对应两表）
   - build_regions/Localizable.<lang>.region.txt   # 5 份 region.* 本地化块（替换各 .strings 中的 region.nl.* / region.fr.* 段）
   - build_regions/regions_import.geojson          # 喂给服务端边界导入（属性: region_id, country_code, group_id, name_latn）

4) 客户端：把生成的两张表贴回 LocationManager.swift，并在 RegionStore.tables 注册 "NL"/"FR"（若尚未）。
   本地化：用生成的 region.* 块替换各 .strings 里现有的 region.nl.* / region.fr.* 段。
   服务端：用 regions_import.geojson 走边界导入（from_shape→ST_MakeValid→算 grid_count）。

注：CJK 译名优先取下方 SEED_I18N（已内置荷兰 12 省、法国 13 大区的 5 语言译名）；
    未覆盖的法国省份等暂回退到 NAME_LATN（法文名），符合“新区域先 fallback 英语”的策略，
    后续可往 SEED_I18N 增补热门单元的译名再重跑。
"""

import argparse
import json
import os
import re
import sys

LANGS = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

# 选定粒度：country -> 取哪个 NUTS 层级作为 region 单元，以及按哪个上级层级分组
# group_level=None 表示扁平（每个单元独立成组，无父级）
COUNTRY_CONFIG = {
    "NL": {"unit_level": 2, "group_level": None},  # 省（NUTS2），扁平
    "FR": {"unit_level": 3, "group_level": 1},     # 省（NUTS3），按大区（NUTS1）分组
}

# 翻译种子：键 = NUTS_ID，值 = 各语言显示名。未命中的单元各 CJK 语言回退到 NAME_LATN。
# 已内置：荷兰 12 省（NUTS2）+ 法国 13 大区（NUTS1，作为分组名）。
SEED_I18N = {
    "NL11": {
        "zh-Hans": "格罗宁根",
        "zh-Hant": "格羅寧根",
        "ja": "フローニンゲン",
        "ko": "흐로닝언"
    },
    "NL12": {
        "zh-Hans": "弗里斯兰",
        "zh-Hant": "弗里斯蘭",
        "ja": "フリースラント",
        "ko": "프리슬란트"
    },
    "NL13": {
        "zh-Hans": "德伦特",
        "zh-Hant": "德倫特",
        "ja": "ドレンテ",
        "ko": "드렌터"
    },
    "NL21": {
        "zh-Hans": "上艾瑟尔",
        "zh-Hant": "上艾瑟爾",
        "ja": "オーファーアイセル",
        "ko": "오베레이설"
    },
    "NL22": {
        "zh-Hans": "海尔德兰",
        "zh-Hant": "海爾德蘭",
        "ja": "ヘルダーラント",
        "ko": "헬데를란트"
    },
    "NL23": {
        "zh-Hans": "弗莱福兰",
        "zh-Hant": "弗萊福蘭",
        "ja": "フレヴォラント",
        "ko": "플레볼란트"
    },
    "NL31": {
        "zh-Hans": "乌得勒支",
        "zh-Hant": "烏特勒支",
        "ja": "ユトレヒト",
        "ko": "위트레흐트"
    },
    "NL32": {
        "zh-Hans": "北荷兰",
        "zh-Hant": "北荷蘭",
        "ja": "北ホラント",
        "ko": "노르트홀란트"
    },
    "NL33": {
        "zh-Hans": "南荷兰",
        "zh-Hant": "南荷蘭",
        "ja": "南ホラント",
        "ko": "자위트홀란트"
    },
    "NL34": {
        "zh-Hans": "泽兰",
        "zh-Hant": "澤蘭",
        "ja": "ゼーラント",
        "ko": "제일란트"
    },
    "NL41": {
        "zh-Hans": "北布拉班特",
        "zh-Hant": "北布拉班特",
        "ja": "北ブラバント",
        "ko": "노르트브라반트"
    },
    "NL42": {
        "zh-Hans": "林堡",
        "zh-Hant": "林堡",
        "ja": "リンブルフ",
        "ko": "림뷔르흐"
    },
    "FR1": {
        "zh-Hans": "法兰西岛",
        "zh-Hant": "法蘭西島",
        "ja": "イル＝ド＝フランス",
        "ko": "일드프랑스"
    },
    "FRB": {
        "zh-Hans": "中央-卢瓦尔河谷",
        "zh-Hant": "中央-盧瓦爾河谷",
        "ja": "サントル＝ヴァル・ド・ロワール",
        "ko": "상트르발드루아르"
    },
    "FRC": {
        "zh-Hans": "勃艮第-弗朗什-孔泰",
        "zh-Hant": "勃艮第-弗朗什-孔泰",
        "ja": "ブルゴーニュ＝フランシュ＝コンテ",
        "ko": "부르고뉴프랑슈콩테"
    },
    "FRD": {
        "zh-Hans": "诺曼底",
        "zh-Hant": "諾曼第",
        "ja": "ノルマンディー",
        "ko": "노르망디"
    },
    "FRE": {
        "zh-Hans": "上法兰西",
        "zh-Hant": "上法蘭西",
        "ja": "オー＝ド＝フランス",
        "ko": "오드프랑스"
    },
    "FRF": {
        "zh-Hans": "大东部",
        "zh-Hant": "大東部",
        "ja": "グラン・テスト",
        "ko": "그랑테스트"
    },
    "FRG": {
        "zh-Hans": "卢瓦尔河地区",
        "zh-Hant": "盧瓦爾河地區",
        "ja": "ペイ・ド・ラ・ロワール",
        "ko": "페이드라루아르"
    },
    "FRH": {
        "zh-Hans": "布列塔尼",
        "zh-Hant": "布列塔尼",
        "ja": "ブルターニュ",
        "ko": "브르타뉴"
    },
    "FRI": {
        "zh-Hans": "新阿基坦",
        "zh-Hant": "新阿基坦",
        "ja": "ヌーヴェル＝アキテーヌ",
        "ko": "누벨아키텐"
    },
    "FRJ": {
        "zh-Hans": "奥克西塔尼",
        "zh-Hant": "奧克西塔尼",
        "ja": "オクシタニー",
        "ko": "옥시타니"
    },
    "FRK": {
        "zh-Hans": "奥弗涅-罗讷-阿尔卑斯",
        "zh-Hant": "奧弗涅-羅訥-阿爾卑斯",
        "ja": "オーヴェルニュ＝ローヌ＝アルプ",
        "ko": "오베르뉴론알프"
    },
    "FRL": {
        "zh-Hans": "普罗旺斯-阿尔卑斯-蓝色海岸",
        "zh-Hant": "普羅旺斯-阿爾卑斯-蔚藍海岸",
        "ja": "プロヴァンス＝アルプ＝コート・ダジュール",
        "ko": "프로방스알프코트다쥐르"
    },
    "FRM": {
        "zh-Hans": "科西嘉",
        "zh-Hant": "科西嘉",
        "ja": "コルス",
        "ko": "코르시카"
    },
    "FRY": {
        "zh-Hans": "法国海外",
        "zh-Hant": "法國海外",
        "ja": "フランス海外",
        "ko": "프랑스 해외"
    },
    "FR101": {
        "zh-Hans": "巴黎",
        "zh-Hant": "巴黎",
        "ja": "パリ",
        "ko": "파리"
    },
    "FR102": {
        "zh-Hans": "塞纳-马恩",
        "zh-Hant": "塞納-馬恩",
        "ja": "セーヌ＝エ＝マルヌ",
        "ko": "센에마른"
    },
    "FR103": {
        "zh-Hans": "伊夫林",
        "zh-Hant": "伊夫林",
        "ja": "イヴリーヌ",
        "ko": "이블린"
    },
    "FR104": {
        "zh-Hans": "埃松",
        "zh-Hant": "埃松",
        "ja": "エソンヌ",
        "ko": "에손"
    },
    "FR105": {
        "zh-Hans": "上塞纳",
        "zh-Hant": "上塞納",
        "ja": "オー＝ド＝セーヌ",
        "ko": "오드센"
    },
    "FR106": {
        "zh-Hans": "塞纳-圣但尼",
        "zh-Hant": "塞納-聖但尼",
        "ja": "セーヌ＝サン＝ドニ",
        "ko": "센생드니"
    },
    "FR107": {
        "zh-Hans": "马恩河谷",
        "zh-Hant": "馬恩河谷",
        "ja": "ヴァル＝ド＝マルヌ",
        "ko": "발드마른"
    },
    "FR108": {
        "zh-Hans": "瓦勒德瓦兹",
        "zh-Hant": "瓦勒德瓦茲",
        "ja": "ヴァル＝ドワーズ",
        "ko": "발두아즈"
    },
    "FRB01": {
        "zh-Hans": "谢尔",
        "zh-Hant": "謝爾",
        "ja": "シェール",
        "ko": "셰르"
    },
    "FRB02": {
        "zh-Hans": "厄尔-卢瓦尔",
        "zh-Hant": "厄爾-盧瓦爾",
        "ja": "ウール＝エ＝ロワール",
        "ko": "외르에루아르"
    },
    "FRB03": {
        "zh-Hans": "安德尔",
        "zh-Hant": "安德爾",
        "ja": "アンドル",
        "ko": "앵드르"
    },
    "FRB04": {
        "zh-Hans": "安德尔-卢瓦尔",
        "zh-Hant": "安德爾-盧瓦爾",
        "ja": "アンドル＝エ＝ロワール",
        "ko": "앵드르에루아르"
    },
    "FRB05": {
        "zh-Hans": "卢瓦尔-谢尔",
        "zh-Hant": "盧瓦爾-謝爾",
        "ja": "ロワール＝エ＝シェール",
        "ko": "루아르에셰르"
    },
    "FRB06": {
        "zh-Hans": "卢瓦雷",
        "zh-Hant": "盧瓦雷",
        "ja": "ロワレ",
        "ko": "루아레"
    },
    "FRC11": {
        "zh-Hans": "科多尔",
        "zh-Hant": "科多爾",
        "ja": "コート＝ドール",
        "ko": "코트도르"
    },
    "FRC12": {
        "zh-Hans": "涅夫勒",
        "zh-Hant": "涅夫勒",
        "ja": "ニエーヴル",
        "ko": "니에브르"
    },
    "FRC13": {
        "zh-Hans": "索恩-卢瓦尔",
        "zh-Hant": "索恩-盧瓦爾",
        "ja": "ソーヌ＝エ＝ロワール",
        "ko": "손에루아르"
    },
    "FRC14": {
        "zh-Hans": "约讷",
        "zh-Hant": "約訥",
        "ja": "ヨンヌ",
        "ko": "욘"
    },
    "FRC21": {
        "zh-Hans": "杜",
        "zh-Hant": "杜",
        "ja": "ドゥー",
        "ko": "두"
    },
    "FRC22": {
        "zh-Hans": "汝拉",
        "zh-Hant": "汝拉",
        "ja": "ジュラ",
        "ko": "쥐라"
    },
    "FRC23": {
        "zh-Hans": "上索恩",
        "zh-Hant": "上索恩",
        "ja": "オート＝ソーヌ",
        "ko": "오트손"
    },
    "FRC24": {
        "zh-Hans": "贝尔福",
        "zh-Hant": "貝爾福",
        "ja": "ベルフォール",
        "ko": "벨포르"
    },
    "FRD11": {
        "zh-Hans": "卡尔瓦多斯",
        "zh-Hant": "卡爾瓦多斯",
        "ja": "カルヴァドス",
        "ko": "칼바도스"
    },
    "FRD12": {
        "zh-Hans": "芒什",
        "zh-Hant": "芒什",
        "ja": "マンシュ",
        "ko": "망슈"
    },
    "FRD13": {
        "zh-Hans": "奥恩",
        "zh-Hant": "奧恩",
        "ja": "オルヌ",
        "ko": "오른"
    },
    "FRD21": {
        "zh-Hans": "厄尔",
        "zh-Hant": "厄爾",
        "ja": "ウール",
        "ko": "외르"
    },
    "FRD22": {
        "zh-Hans": "滨海塞纳",
        "zh-Hant": "濱海塞納",
        "ja": "セーヌ＝マリティーム",
        "ko": "센마리팀"
    },
    "FRE11": {
        "zh-Hans": "诺尔",
        "zh-Hant": "諾爾",
        "ja": "ノール",
        "ko": "노르"
    },
    "FRE12": {
        "zh-Hans": "加来海峡",
        "zh-Hant": "加來海峽",
        "ja": "パ＝ド＝カレー",
        "ko": "파드칼레"
    },
    "FRE21": {
        "zh-Hans": "埃纳",
        "zh-Hant": "埃納",
        "ja": "エーヌ",
        "ko": "엔"
    },
    "FRE22": {
        "zh-Hans": "瓦兹",
        "zh-Hant": "瓦茲",
        "ja": "オワーズ",
        "ko": "우아즈"
    },
    "FRE23": {
        "zh-Hans": "索姆",
        "zh-Hant": "索姆",
        "ja": "ソンム",
        "ko": "솜"
    },
    "FRF11": {
        "zh-Hans": "下莱茵",
        "zh-Hant": "下萊茵",
        "ja": "バ＝ラン",
        "ko": "바랭"
    },
    "FRF12": {
        "zh-Hans": "上莱茵",
        "zh-Hant": "上萊茵",
        "ja": "オー＝ラン",
        "ko": "오랭"
    },
    "FRF21": {
        "zh-Hans": "阿登",
        "zh-Hant": "阿登",
        "ja": "アルデンヌ",
        "ko": "아르덴"
    },
    "FRF22": {
        "zh-Hans": "奥布",
        "zh-Hant": "奧布",
        "ja": "オーブ",
        "ko": "오브"
    },
    "FRF23": {
        "zh-Hans": "马恩",
        "zh-Hant": "馬恩",
        "ja": "マルヌ",
        "ko": "마른"
    },
    "FRF24": {
        "zh-Hans": "上马恩",
        "zh-Hant": "上馬恩",
        "ja": "オート＝マルヌ",
        "ko": "오트마른"
    },
    "FRF31": {
        "zh-Hans": "默尔特-摩泽尔",
        "zh-Hant": "默爾特-摩澤爾",
        "ja": "ムルト＝エ＝モゼル",
        "ko": "뫼르트에모젤"
    },
    "FRF32": {
        "zh-Hans": "默兹",
        "zh-Hant": "默茲",
        "ja": "ムーズ",
        "ko": "뫼즈"
    },
    "FRF33": {
        "zh-Hans": "摩泽尔",
        "zh-Hant": "摩澤爾",
        "ja": "モゼル",
        "ko": "모젤"
    },
    "FRF34": {
        "zh-Hans": "孚日",
        "zh-Hant": "孚日",
        "ja": "ヴォージュ",
        "ko": "보주"
    },
    "FRG01": {
        "zh-Hans": "大西洋卢瓦尔",
        "zh-Hant": "大西洋盧瓦爾",
        "ja": "ロワール＝アトランティック",
        "ko": "루아르아틀랑티크"
    },
    "FRG02": {
        "zh-Hans": "曼恩-卢瓦尔",
        "zh-Hant": "曼恩-盧瓦爾",
        "ja": "メーヌ＝エ＝ロワール",
        "ko": "멘에루아르"
    },
    "FRG03": {
        "zh-Hans": "马耶讷",
        "zh-Hant": "馬耶訥",
        "ja": "マイエンヌ",
        "ko": "마옌"
    },
    "FRG04": {
        "zh-Hans": "萨尔特",
        "zh-Hant": "薩爾特",
        "ja": "サルト",
        "ko": "사르트"
    },
    "FRG05": {
        "zh-Hans": "旺代",
        "zh-Hant": "旺代",
        "ja": "ヴァンデ",
        "ko": "방데"
    },
    "FRH01": {
        "zh-Hans": "阿摩尔滨海",
        "zh-Hant": "阿摩爾濱海",
        "ja": "コート＝ダルモール",
        "ko": "코트다르모르"
    },
    "FRH02": {
        "zh-Hans": "菲尼斯泰尔",
        "zh-Hant": "菲尼斯泰爾",
        "ja": "フィニステール",
        "ko": "피니스테르"
    },
    "FRH03": {
        "zh-Hans": "伊勒-维兰",
        "zh-Hant": "伊勒-維蘭",
        "ja": "イル＝エ＝ヴィレーヌ",
        "ko": "일에빌렌"
    },
    "FRH04": {
        "zh-Hans": "莫尔比昂",
        "zh-Hant": "莫爾比昂",
        "ja": "モルビアン",
        "ko": "모르비앙"
    },
    "FRI11": {
        "zh-Hans": "多尔多涅",
        "zh-Hant": "多爾多涅",
        "ja": "ドルドーニュ",
        "ko": "도르도뉴"
    },
    "FRI12": {
        "zh-Hans": "吉伦特",
        "zh-Hant": "吉倫特",
        "ja": "ジロンド",
        "ko": "지롱드"
    },
    "FRI13": {
        "zh-Hans": "朗德",
        "zh-Hant": "朗德",
        "ja": "ランド",
        "ko": "랑드"
    },
    "FRI14": {
        "zh-Hans": "洛特-加龙",
        "zh-Hant": "洛特-加龍",
        "ja": "ロット＝エ＝ガロンヌ",
        "ko": "로트에가론"
    },
    "FRI15": {
        "zh-Hans": "大西洋比利牛斯",
        "zh-Hant": "大西洋比利牛斯",
        "ja": "ピレネー＝アトランティック",
        "ko": "피레네아틀랑티크"
    },
    "FRI21": {
        "zh-Hans": "科雷兹",
        "zh-Hant": "科雷茲",
        "ja": "コレーズ",
        "ko": "코레즈"
    },
    "FRI22": {
        "zh-Hans": "克勒兹",
        "zh-Hant": "克勒茲",
        "ja": "クルーズ",
        "ko": "크뢰즈"
    },
    "FRI23": {
        "zh-Hans": "上维埃纳",
        "zh-Hant": "上維埃納",
        "ja": "オート＝ヴィエンヌ",
        "ko": "오트비엔"
    },
    "FRI31": {
        "zh-Hans": "夏朗德",
        "zh-Hant": "夏朗德",
        "ja": "シャラント",
        "ko": "샤랑트"
    },
    "FRI32": {
        "zh-Hans": "滨海夏朗德",
        "zh-Hant": "濱海夏朗德",
        "ja": "シャラント＝マリティーム",
        "ko": "샤랑트마리팀"
    },
    "FRI33": {
        "zh-Hans": "德塞夫勒",
        "zh-Hant": "德塞夫勒",
        "ja": "ドゥー＝セーヴル",
        "ko": "되세브르"
    },
    "FRI34": {
        "zh-Hans": "维埃纳",
        "zh-Hant": "維埃納",
        "ja": "ヴィエンヌ",
        "ko": "비엔"
    },
    "FRJ11": {
        "zh-Hans": "奥德",
        "zh-Hant": "奧德",
        "ja": "オード",
        "ko": "오드"
    },
    "FRJ12": {
        "zh-Hans": "加尔",
        "zh-Hant": "加爾",
        "ja": "ガール",
        "ko": "가르"
    },
    "FRJ13": {
        "zh-Hans": "埃罗",
        "zh-Hant": "埃羅",
        "ja": "エロー",
        "ko": "에로"
    },
    "FRJ14": {
        "zh-Hans": "洛泽尔",
        "zh-Hant": "洛澤爾",
        "ja": "ロゼール",
        "ko": "로제르"
    },
    "FRJ15": {
        "zh-Hans": "东比利牛斯",
        "zh-Hant": "東比利牛斯",
        "ja": "ピレネー＝オリアンタル",
        "ko": "피레네조리앙탈"
    },
    "FRJ21": {
        "zh-Hans": "阿列日",
        "zh-Hant": "阿列日",
        "ja": "アリエージュ",
        "ko": "아리에주"
    },
    "FRJ22": {
        "zh-Hans": "阿韦龙",
        "zh-Hant": "阿韋龍",
        "ja": "アヴェロン",
        "ko": "아베롱"
    },
    "FRJ23": {
        "zh-Hans": "上加龙",
        "zh-Hant": "上加龍",
        "ja": "オート＝ガロンヌ",
        "ko": "오트가론"
    },
    "FRJ24": {
        "zh-Hans": "热尔",
        "zh-Hant": "熱爾",
        "ja": "ジェール",
        "ko": "제르"
    },
    "FRJ25": {
        "zh-Hans": "洛特",
        "zh-Hant": "洛特",
        "ja": "ロット",
        "ko": "로트"
    },
    "FRJ26": {
        "zh-Hans": "上比利牛斯",
        "zh-Hant": "上比利牛斯",
        "ja": "オート＝ピレネー",
        "ko": "오트피레네"
    },
    "FRJ27": {
        "zh-Hans": "塔恩",
        "zh-Hant": "塔恩",
        "ja": "タルン",
        "ko": "타른"
    },
    "FRJ28": {
        "zh-Hans": "塔恩-加龙",
        "zh-Hant": "塔恩-加龍",
        "ja": "タルン＝エ＝ガロンヌ",
        "ko": "타른에가론"
    },
    "FRK11": {
        "zh-Hans": "阿列",
        "zh-Hant": "阿列",
        "ja": "アリエ",
        "ko": "알리에"
    },
    "FRK12": {
        "zh-Hans": "康塔尔",
        "zh-Hant": "康塔爾",
        "ja": "カンタル",
        "ko": "캉탈"
    },
    "FRK13": {
        "zh-Hans": "上卢瓦尔",
        "zh-Hant": "上盧瓦爾",
        "ja": "オート＝ロワール",
        "ko": "오트루아르"
    },
    "FRK14": {
        "zh-Hans": "多姆山",
        "zh-Hant": "多姆山",
        "ja": "ピュイ＝ド＝ドーム",
        "ko": "퓌드돔"
    },
    "FRK21": {
        "zh-Hans": "安",
        "zh-Hant": "安",
        "ja": "アン",
        "ko": "앵"
    },
    "FRK22": {
        "zh-Hans": "阿尔代什",
        "zh-Hant": "阿爾代什",
        "ja": "アルデシュ",
        "ko": "아르데슈"
    },
    "FRK23": {
        "zh-Hans": "德龙",
        "zh-Hant": "德龍",
        "ja": "ドローム",
        "ko": "드롬"
    },
    "FRK24": {
        "zh-Hans": "伊泽尔",
        "zh-Hant": "伊澤爾",
        "ja": "イゼール",
        "ko": "이제르"
    },
    "FRK25": {
        "zh-Hans": "卢瓦尔",
        "zh-Hant": "盧瓦爾",
        "ja": "ロワール",
        "ko": "루아르"
    },
    "FRK26": {
        "zh-Hans": "罗讷",
        "zh-Hant": "羅訥",
        "ja": "ローヌ",
        "ko": "론"
    },
    "FRK27": {
        "zh-Hans": "萨瓦",
        "zh-Hant": "薩瓦",
        "ja": "サヴォワ",
        "ko": "사부아"
    },
    "FRK28": {
        "zh-Hans": "上萨瓦",
        "zh-Hant": "上薩瓦",
        "ja": "オート＝サヴォワ",
        "ko": "오트사부아"
    },
    "FRL01": {
        "zh-Hans": "上普罗旺斯阿尔卑斯",
        "zh-Hant": "上普羅旺斯阿爾卑斯",
        "ja": "アルプ＝ド＝オート＝プロヴァンス",
        "ko": "알프드오트프로방스"
    },
    "FRL02": {
        "zh-Hans": "上阿尔卑斯",
        "zh-Hant": "上阿爾卑斯",
        "ja": "オート＝ザルプ",
        "ko": "오트잘프"
    },
    "FRL03": {
        "zh-Hans": "滨海阿尔卑斯",
        "zh-Hant": "濱海阿爾卑斯",
        "ja": "アルプ＝マリティーム",
        "ko": "알프마리팀"
    },
    "FRL04": {
        "zh-Hans": "罗讷河口",
        "zh-Hant": "羅訥河口",
        "ja": "ブーシュ＝デュ＝ローヌ",
        "ko": "부슈뒤론"
    },
    "FRL05": {
        "zh-Hans": "瓦尔",
        "zh-Hant": "瓦爾",
        "ja": "ヴァール",
        "ko": "바르"
    },
    "FRL06": {
        "zh-Hans": "沃克吕兹",
        "zh-Hant": "沃克呂茲",
        "ja": "ヴォクリューズ",
        "ko": "보클뤼즈"
    },
    "FRM01": {
        "zh-Hans": "南科西嘉",
        "zh-Hant": "南科西嘉",
        "ja": "コルス＝デュ＝シュド",
        "ko": "코르스뒤쉬드"
    },
    "FRM02": {
        "zh-Hans": "上科西嘉",
        "zh-Hant": "上科西嘉",
        "ja": "オート＝コルス",
        "ko": "오트코르스"
    },
    "FRY10": {
        "zh-Hans": "瓜德罗普",
        "zh-Hant": "瓜德羅普",
        "ja": "グアドループ",
        "ko": "과들루프"
    },
    "FRY20": {
        "zh-Hans": "马提尼克",
        "zh-Hant": "馬提尼克",
        "ja": "マルティニーク",
        "ko": "마르티니크"
    },
    "FRY30": {
        "zh-Hans": "法属圭亚那",
        "zh-Hant": "法屬圭亞那",
        "ja": "フランス領ギアナ",
        "ko": "프랑스령 기아나"
    },
    "FRY40": {
        "zh-Hans": "留尼汪",
        "zh-Hant": "留尼旺",
        "ja": "レユニオン",
        "ko": "레위니옹"
    },
    "FRY50": {
        "zh-Hans": "马约特",
        "zh-Hant": "馬約特",
        "ja": "マヨット",
        "ko": "마요트"
    }
}


def nuts_parent(nuts_id: str, target_level: int) -> str:
    """NUTS_ID 前缀即上级编码：NUTS0=2 字符, NUTS1=3, NUTS2=4, NUTS3=5。"""
    return nuts_id[: target_level + 2]


def loc_key(country: str, nuts_id: str) -> str:
    return f"region.{country.lower()}.{nuts_id.lower()}"


def display_names(nuts_id: str, name_latn: str) -> dict:
    seed = SEED_I18N.get(nuts_id)
    names = {}
    for lang in LANGS:
        if seed and seed.get(lang):
            names[lang] = seed[lang]
        elif lang == "en":
            names[lang] = name_latn
        else:
            names[lang] = name_latn  # CJK 未命中 → 回退 NAME_LATN（法文/原文名）
    return names


def main():
    ap = argparse.ArgumentParser(description="Generate region tables & localization from GISCO NUTS GeoJSON.")
    ap.add_argument("geojson", help="GISCO NUTS RG GeoJSON (EPSG:4326, 含全部层级)")
    ap.add_argument("--out-dir", default="build_regions")
    ap.add_argument("--countries", default="NL,FR", help="逗号分隔，默认 NL,FR")
    args = ap.parse_args()

    countries = [c.strip().upper() for c in args.countries.split(",") if c.strip()]
    with open(args.geojson, "r", encoding="utf-8") as f:
        fc = json.load(f)
    feats = fc.get("features", [])

    # 索引：按 (CNTR, LEVL_CODE, NUTS_ID) 收集
    by_id = {}
    for ft in feats:
        p = ft.get("properties", {})
        nid = p.get("NUTS_ID")
        if not nid:
            continue
        by_id[nid] = {
            "cntr": p.get("CNTR_CODE"),
            "level": int(p.get("LEVL_CODE", -1)),
            "name": p.get("NAME_LATN") or p.get("NUTS_NAME") or nid,
            "feature": ft,
        }

    os.makedirs(args.out_dir, exist_ok=True)
    swift_blocks = []
    loc_lines = {lang: [] for lang in LANGS}
    import_features = []

    for country in countries:
        cfg = COUNTRY_CONFIG.get(country)
        if not cfg:
            print(f"[skip] 未配置的国家: {country}", file=sys.stderr)
            continue
        unit_level = cfg["unit_level"]
        group_level = cfg["group_level"]

        units = sorted(
            [v for v in by_id.values() if v["cntr"] == country and v["level"] == unit_level],
            key=lambda v: v["feature"]["properties"]["NUTS_ID"],
        )
        if not units:
            print(f"[warn] {country}: 在 NUTS{unit_level} 没找到任何单元，检查输入文件层级。", file=sys.stderr)
            continue

        # 国家级名（region.<cc>）
        cc_key = f"region.{country.lower()}"
        cc_names = {"NL": {"en": "Netherlands", "zh-Hans": "荷兰", "zh-Hant": "荷蘭", "ja": "オランダ", "ko": "네덜란드"},
                    "FR": {"en": "France", "zh-Hans": "法国", "zh-Hant": "法國", "ja": "フランス", "ko": "프랑스"}}.get(country)
        if cc_names:
            for lang in LANGS:
                loc_lines[lang].append(f'"{cc_key}" = "{cc_names[lang]}";')

        # 分组：group_id -> [unit, ...]
        groups = {}
        for u in units:
            nid = u["feature"]["properties"]["NUTS_ID"]
            gid = nuts_parent(nid, group_level) if group_level is not None else nid
            groups.setdefault(gid, []).append(u)

        # ---- Swift 表 ----
        sw = [f"// {country}：由 tools/gen_regions.py 从 GISCO NUTS{unit_level} 自动生成，勿手改；改粒度请改脚本重跑。",
              f"let regionTable_{country}: [String: [Region]] = ["]
        for gid in sorted(groups.keys()):
            members = groups[gid]
            gkey = loc_key(country, gid)
            sw.append(f'    "{gkey}": [')
            for u in members:
                nid = u["feature"]["properties"]["NUTS_ID"]
                ukey = loc_key(country, nid)
                sw.append(f'        Region(regionID: "{nid}", regionName: "{ukey}"),')
            if sw[-1].endswith(","):
                sw[-1] = sw[-1][:-1]  # 去掉最后一个逗号
            sw.append("    ],")
        if sw[-1].endswith("],"):
            sw[-1] = "    ]"
        sw.append("]")
        swift_blocks.append("\n".join(sw))

        # ---- 本地化：分组名（若分组层级存在）+ 单元名 ----
        emitted = set()
        if group_level is not None:
            for gid in sorted(groups.keys()):
                gkey = loc_key(country, gid)
                gname = by_id.get(gid, {}).get("name", gid)
                names = display_names(gid, gname)
                if gkey not in emitted:
                    for lang in LANGS:
                        loc_lines[lang].append(f'"{gkey}" = "{names[lang]}";')
                    emitted.add(gkey)
        for u in units:
            nid = u["feature"]["properties"]["NUTS_ID"]
            ukey = loc_key(country, nid)
            names = display_names(nid, u["name"])
            if ukey not in emitted:
                for lang in LANGS:
                    loc_lines[lang].append(f'"{ukey}" = "{names[lang]}";')
                emitted.add(ukey)

        # ---- 服务端导入 GeoJSON ----
        for u in units:
            nid = u["feature"]["properties"]["NUTS_ID"]
            gid = nuts_parent(nid, group_level) if group_level is not None else nid
            ft = dict(u["feature"])
            ft["properties"] = {
                "region_id": nid,
                "country_code": country,
                "group_id": gid,
                "name_latn": u["name"],
            }
            import_features.append(ft)

    # 写文件
    swift_path = os.path.join(args.out_dir, "RegionTables.generated.swift")
    with open(swift_path, "w", encoding="utf-8") as f:
        f.write("import Foundation\n\n")
        f.write("\n\n".join(swift_blocks) + "\n")

    for lang in LANGS:
        p = os.path.join(args.out_dir, f"Localizable.{lang}.region.txt")
        with open(p, "w", encoding="utf-8") as f:
            f.write("\n".join(loc_lines[lang]) + "\n")

    import_path = os.path.join(args.out_dir, "regions_import.geojson")
    with open(import_path, "w", encoding="utf-8") as f:
        json.dump({"type": "FeatureCollection", "features": import_features}, f, ensure_ascii=False)

    print(f"✅ 生成完成 -> {args.out_dir}/")
    print(f"   - RegionTables.generated.swift（{len(swift_blocks)} 张表）")
    print(f"   - Localizable.<lang>.region.txt（{len(LANGS)} 份）")
    print(f"   - regions_import.geojson（{len(import_features)} 个 region）")


if __name__ == "__main__":
    main()
