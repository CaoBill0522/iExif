#!/usr/bin/env python3
"""生成 ExifEditor/Resources/Devices.json。

数据来源：
- 焦距 / 光圈 / 等效焦距：Wikimedia Commons "Taken with <device>" 分类下真机照片的 EXIF 统计。
- LensModel 模块命名（back camera / back dual camera / back dual wide camera / back triple camera /
  front camera）：ExploreCams、sampleshots 等站点收录的真机 EXIF 字符串。
- 标记 est=True 的镜头没有找到真机 EXIF，按官方规格推算，App 中会显示“估算”。
"""
import json, os, re

def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return s

# (kind, position, focalLength mm, fNumber, 35mm equivalent, estimated)
def L(kind, fl, fn, f35, est=False):
    pos = "front" if kind == "front" else "back"
    return dict(kind=kind, position=pos, fl=fl, fn=fn, f35=f35, est=est)

W, UW, T, F = "wide", "ultraWide", "telephoto", "front"

FRONT_VGA_4   = L(F, 3.85, 2.4, 35)            # ExploreCams 真机字符串
FRONT_4S      = L(F, 1.85, 2.4, 35)            # ExploreCams；等效焦距同 iPad 2 前置（Commons 真机 35mm）
FRONT_5       = L(F, 2.18, 2.4, 35)            # ExploreCams；Commons 真机 35mm
FRONT_5S      = L(F, 2.15, 2.4, 31)            # ExploreCams 真机字符串
FRONT_6       = L(F, 2.65, 2.2, 31)
FRONT_7       = L(F, 2.87, 2.2, 32)
FRONT_11      = L(F, 2.71, 2.2, 23)
FRONT_14      = L(F, 2.69, 1.9, 23)
# 18MP Center Stage 前置：GSMArena 评测原图 EXIF（17 / Air / 17 Pro / 17 Pro Max 一致）
FRONT_17      = dict(L(F, 2.71484375, 1.8994140625, 20), label="2.71484mm f/1.89941")
# 17 Pro / 17 Pro Max 长焦：GSMArena 评测原图 EXIF
TELE_17PRO    = dict(L(T, 16.890625, 2.798828125, 100), label="16.8906mm f/2.79883")

# 现在的 iOS 在带 TrueDepth（面容 ID）前置的机型上写 "front TrueDepth camera"（GSMArena 各代评测原图）；
# 16e 例外写 "front camera"，17e 写 TrueDepth。
TRUEDEPTH_NAME = "front TrueDepth camera"
TRUEDEPTH = {"iPhone X", "iPhone XR", "iPhone XS", "iPhone XS Max", "iPhone 11", "iPhone 11 Pro", "iPhone 11 Pro Max",
             "iPhone 12 mini", "iPhone 12", "iPhone 12 Pro", "iPhone 12 Pro Max", "iPhone 13 mini", "iPhone 13",
             "iPhone 13 Pro", "iPhone 13 Pro Max", "iPhone 14", "iPhone 14 Plus", "iPhone 14 Pro", "iPhone 14 Pro Max",
             "iPhone 15", "iPhone 15 Plus", "iPhone 15 Pro", "iPhone 15 Pro Max", "iPhone 16", "iPhone 16 Plus",
             "iPhone 16 Pro", "iPhone 16 Pro Max", "iPhone 17e",
             # 面容 ID 的 iPad Pro（按 iPhone 规律推断，尚无 iPad 真机字符串）
             "iPad Pro (11-inch)", "iPad Pro (12.9-inch) (3rd generation)", "iPad Pro (11-inch) (2nd generation)",
             "iPad Pro (12.9-inch) (4th generation)", "iPad Pro (11-inch) (3rd generation)",
             "iPad Pro (12.9-inch) (5th generation)", "iPad Pro (11-inch) (4th generation)",
             "iPad Pro (12.9-inch) (6th generation)", "iPad Pro 11-inch (M4)", "iPad Pro 13-inch (M4)",
             "iPad Pro 11-inch (M5)", "iPad Pro 13-inch (M5)"}

# (model, year, software, backModule, lenses)
IPHONES = [
    ("iPhone 4", 2010, "4.0", "back camera", [L(W, 3.85, 2.8, 35), FRONT_VGA_4]),
    ("iPhone 4S", 2011, "5.0", "back camera", [L(W, 4.28, 2.4, 35), FRONT_4S]),
    ("iPhone 5", 2012, "6.0", "back camera", [L(W, 4.12, 2.4, 33), FRONT_5]),
    ("iPhone 5c", 2013, "7.0", "back camera", [L(W, 4.12, 2.4, 33), FRONT_5S]),
    ("iPhone 5s", 2013, "7.0", "back camera", [L(W, 4.15, 2.2, 29), FRONT_5S]),
    ("iPhone 6", 2014, "8.0", "back camera", [L(W, 4.15, 2.2, 29), FRONT_6]),
    ("iPhone 6 Plus", 2014, "8.0", "back camera", [L(W, 4.15, 2.2, 29), FRONT_6]),
    ("iPhone 6s", 2015, "9.0", "back camera", [L(W, 4.15, 2.2, 29), FRONT_6]),
    ("iPhone 6s Plus", 2015, "9.0", "back camera", [L(W, 4.15, 2.2, 29), FRONT_6]),
    ("iPhone SE", 2016, "9.3", "back camera", [L(W, 4.15, 2.2, 29), FRONT_5S]),
    ("iPhone 7", 2016, "10.0", "back camera", [L(W, 3.99, 1.8, 28), FRONT_7]),
    ("iPhone 7 Plus", 2016, "10.0", "back dual camera", [L(W, 3.99, 1.8, 28), L(T, 6.6, 2.8, 57), FRONT_7]),
    ("iPhone 8", 2017, "11.0", "back camera", [L(W, 3.99, 1.8, 28), FRONT_7]),
    ("iPhone 8 Plus", 2017, "11.0", "back dual camera", [L(W, 3.99, 1.8, 28), L(T, 6.6, 2.8, 57), FRONT_7]),
    ("iPhone X", 2017, "11.0.1", "back dual camera", [L(W, 4.0, 1.8, 28), L(T, 6.0, 2.4, 52), FRONT_7]),
    ("iPhone XR", 2018, "12.0", "back camera", [L(W, 4.25, 1.8, 26), FRONT_7]),
    ("iPhone XS", 2018, "12.0", "back dual camera", [L(W, 4.25, 1.8, 26), L(T, 6.0, 2.4, 52), FRONT_7]),
    ("iPhone XS Max", 2018, "12.0", "back dual camera", [L(W, 4.25, 1.8, 26), L(T, 6.0, 2.4, 52), FRONT_7]),
    ("iPhone 11", 2019, "13.0", "back dual wide camera", [L(UW, 1.54, 2.4, 13), L(W, 4.25, 1.8, 26), FRONT_11]),
    ("iPhone 11 Pro", 2019, "13.0", "back triple camera", [L(UW, 1.54, 2.4, 13), L(W, 4.25, 1.8, 26), L(T, 6.0, 2.0, 52), FRONT_11]),
    ("iPhone 11 Pro Max", 2019, "13.0", "back triple camera", [L(UW, 1.54, 2.4, 13), L(W, 4.25, 1.8, 26), L(T, 6.0, 2.0, 52), FRONT_11]),
    ("iPhone SE (2nd generation)", 2020, "13.4", "back camera", [L(W, 3.99, 1.8, 28), FRONT_7]),
    ("iPhone 12 mini", 2020, "14.2", "back dual wide camera", [L(UW, 1.55, 2.4, 14), L(W, 4.2, 1.6, 26), FRONT_11]),
    ("iPhone 12", 2020, "14.1", "back dual wide camera", [L(UW, 1.55, 2.4, 14), L(W, 4.2, 1.6, 26), FRONT_11]),
    ("iPhone 12 Pro", 2020, "14.1", "back triple camera", [L(UW, 1.54, 2.4, 14), L(W, 4.2, 1.6, 26), L(T, 6.0, 2.0, 52), FRONT_11]),
    ("iPhone 12 Pro Max", 2020, "14.2", "back triple camera", [L(UW, 1.54, 2.4, 14), L(W, 5.1, 1.6, 26), L(T, 7.5, 2.2, 65), FRONT_11]),
    ("iPhone 13 mini", 2021, "15.0", "back dual wide camera", [L(UW, 1.54, 2.4, 13), L(W, 5.1, 1.6, 26), FRONT_11]),
    ("iPhone 13", 2021, "15.0", "back dual wide camera", [L(UW, 1.54, 2.4, 14), L(W, 5.1, 1.6, 26), FRONT_11]),
    ("iPhone 13 Pro", 2021, "15.0", "back triple camera", [L(UW, 1.57, 1.8, 13), L(W, 5.7, 1.5, 26), L(T, 9.0, 2.8, 77), FRONT_11]),
    ("iPhone 13 Pro Max", 2021, "15.0", "back triple camera", [L(UW, 1.57, 1.8, 13), L(W, 5.7, 1.5, 26), L(T, 9.0, 2.8, 77), FRONT_11]),
    ("iPhone SE (3rd generation)", 2022, "15.4", "back camera", [L(W, 3.99, 1.8, 28), FRONT_7]),
    ("iPhone 14", 2022, "16.0", "back dual wide camera", [L(UW, 1.54, 2.4, 14), L(W, 5.7, 1.5, 26), FRONT_14]),
    ("iPhone 14 Plus", 2022, "16.0", "back dual wide camera", [L(UW, 1.54, 2.4, 14), L(W, 5.7, 1.5, 26), FRONT_14]),
    ("iPhone 14 Pro", 2022, "16.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.86, 1.78, 24), L(T, 9.0, 2.8, 77), FRONT_14]),
    ("iPhone 14 Pro Max", 2022, "16.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.86, 1.78, 24), L(T, 9.0, 2.8, 77), FRONT_14]),
    ("iPhone 15", 2023, "17.0", "back dual wide camera", [L(UW, 1.54, 2.4, 13), L(W, 5.96, 1.6, 26), FRONT_14]),
    ("iPhone 15 Plus", 2023, "17.0", "back dual wide camera", [L(UW, 1.54, 2.4, 13), L(W, 5.96, 1.6, 26), FRONT_14]),
    ("iPhone 15 Pro", 2023, "17.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.765, 1.78, 24), L(T, 9.0, 2.8, 77), FRONT_14]),
    ("iPhone 15 Pro Max", 2023, "17.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.765, 1.78, 24), L(T, 15.66, 2.8, 120), FRONT_14]),
    ("iPhone 16", 2024, "18.0", "back dual wide camera", [L(UW, 2.22, 2.2, 14), L(W, 5.96, 1.6, 26), FRONT_14]),
    ("iPhone 16 Plus", 2024, "18.0", "back dual wide camera", [L(UW, 2.22, 2.2, 14), L(W, 5.96, 1.6, 26), FRONT_14]),
    ("iPhone 16 Pro", 2024, "18.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.765, 1.78, 24), L(T, 15.66, 2.8, 120), FRONT_14]),
    ("iPhone 16 Pro Max", 2024, "18.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.765, 1.78, 24), L(T, 15.66, 2.8, 120), FRONT_14]),
    ("iPhone 16e", 2025, "18.3", "back camera", [L(W, 4.2, 1.64, 26), FRONT_14]),
    ("iPhone 17", 2025, "26.0", "back dual wide camera", [L(UW, 2.22, 2.2, 14), L(W, 5.96, 1.6, 26), FRONT_17]),
    ("iPhone Air", 2025, "26.0", "back camera", [L(W, 5.96, 1.6, 26), FRONT_17]),
    ("iPhone 17 Pro", 2025, "26.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.765, 1.78, 24), TELE_17PRO, FRONT_17]),
    ("iPhone 17 Pro Max", 2025, "26.0", "back triple camera", [L(UW, 2.22, 2.2, 14), L(W, 6.765, 1.78, 24), TELE_17PRO, FRONT_17]),
    ("iPhone 17e", 2026, None, "back camera", [L(W, 4.2, 1.64, 26), FRONT_14]),
    # 2026 年 9 月发布。18 Pro Max 的主摄焦距、超广角来自真机样本；主摄为可变光圈（f/1.48–f/4），
    # EXIF 默认记录 f/1.8，LensModel 按镜头最大光圈 f/1.48 书写（尚无真机字符串，标为估算）。
    ("iPhone 18 Pro", 2026, "27.0", "back triple camera", [dict(L(UW, 2.22, 2.2, 14), est=True), dict(L(W, 6.93, 1.8, 24, est=True), lensFn=1.48), dict(TELE_17PRO, est=True), dict(FRONT_17, est=True)]),
    ("iPhone 18 Pro Max", 2026, "27.0", "back triple camera", [L(UW, 2.22, 2.2, 14), dict(L(W, 6.93, 1.8, 24, est=True), lensFn=1.48), dict(TELE_17PRO, est=True), dict(FRONT_17, est=True)]),
    # 折叠屏，主摄与 17e 相近（26mm f/1.6），超广角 13mm f/2.2；暂无真机样本。
    ("iPhone Duo", 2026, "27.0", "back dual wide camera", [L(UW, 2.22, 2.2, 14, est=True), L(W, 4.2, 1.6, 26, est=True), dict(FRONT_17, est=True)]),
]

# iPad：(显示名称, EXIF Model, year, software, backModule, lenses)
IPAD_FRONT_VGA = L(F, 1.85, 2.4, 35)           # ExploreCams + Commons
IPAD_FRONT_12  = L(F, 2.18, 2.4, 35)           # ExploreCams；同 iPhone 5 前置模组
IPAD_FRONT_5   = L(F, 2.15, 2.4, 31)
IPAD_FRONT_AIR2 = L(F, 2.65, 2.2, 31)
IPAD_FRONT_7MP = L(F, 2.87, 2.2, 32, est=True)
IPAD_FRONT_UW  = L(F, 1.65, 2.4, 28)
IPAD_WIDE_8MP  = L(W, 3.3, 2.4, 31)
IPAD_WIDE_12MP = L(W, 3.0, 1.8, 29)
IPAD_FRONT_TD  = L(F, 2.87, 2.2, 32)            # 2018–2020 iPad Pro TrueDepth，真机样本
IPAD_PRO_UW    = L(UW, 1.27, 2.4, 14)           # 2020–2022 iPad Pro 超广角，真机样本
IPAD_FRONT_M4  = L(F, 1.5, 2.0, 15)             # M4 iPad Pro 横向前置

IPADS = [
    ("iPad 2", "iPad 2", 2011, "4.3", "back camera", [L(W, 2.03, 2.4, 44), IPAD_FRONT_VGA]),
    ("iPad (3rd generation)", "iPad", 2012, "5.1", "back camera", [L(W, 4.28, 2.4, 35), IPAD_FRONT_VGA]),
    ("iPad (4th generation)", "iPad", 2012, "6.0", "back camera", [L(W, 4.28, 2.4, 35), IPAD_FRONT_12]),
    ("iPad mini", "iPad mini", 2012, "6.0", "back camera", [L(W, 3.3, 2.4, 33), IPAD_FRONT_12]),
    ("iPad Air", "iPad Air", 2013, "7.0", "back camera", [L(W, 3.3, 2.4, 32), IPAD_FRONT_5]),
    ("iPad mini 2", "iPad mini 2", 2013, "7.0", "back camera", [L(W, 3.3, 2.4, 32), IPAD_FRONT_5]),
    ("iPad Air 2", "iPad Air 2", 2014, "8.1", "back camera", [L(W, 3.3, 2.4, 31), IPAD_FRONT_AIR2]),
    ("iPad mini 3", "iPad mini 3", 2014, "8.1", "back camera", [L(W, 3.3, 2.4, 32), IPAD_FRONT_5]),
    ("iPad mini 4", "iPad mini 4", 2015, "9.0", "back camera", [L(W, 3.3, 2.4, 31), IPAD_FRONT_AIR2]),
    ("iPad Pro (12.9-inch)", "iPad Pro", 2015, "9.1", "back camera", [L(W, 3.3, 2.4, 31), IPAD_FRONT_AIR2]),
    ("iPad Pro (9.7-inch)", "iPad Pro", 2016, "9.3", "back camera", [L(W, 4.15, 2.2, 29), IPAD_FRONT_AIR2]),
    ("iPad (5th generation)", "iPad (5th generation)", 2017, "10.2.1", "back camera", [IPAD_WIDE_8MP, IPAD_FRONT_5]),
    ("iPad Pro (10.5-inch)", "iPad Pro (10.5-inch)", 2017, "10.3.2", "back camera", [L(W, 3.99, 1.8, 28), IPAD_FRONT_7MP]),
    ("iPad Pro (12.9-inch) (2nd generation)", "iPad Pro (12.9-inch) (2nd generation)", 2017, "10.3.2", "back camera", [L(W, 3.99, 1.8, 28), L(F, 2.87, 2.2, 32)]),
    ("iPad (6th generation)", "iPad (6th generation)", 2018, "11.3", "back camera", [IPAD_WIDE_8MP, IPAD_FRONT_5]),
    ("iPad Pro (11-inch)", "iPad Pro (11-inch)", 2018, "12.1", "back camera", [IPAD_WIDE_12MP, IPAD_FRONT_TD]),
    ("iPad Pro (12.9-inch) (3rd generation)", "iPad Pro (12.9-inch) (3rd generation)", 2018, "12.1", "back camera", [IPAD_WIDE_12MP, IPAD_FRONT_TD]),
    ("iPad Air (3rd generation)", "iPad Air (3rd generation)", 2019, "12.2", "back camera", [IPAD_WIDE_8MP, IPAD_FRONT_7MP]),
    ("iPad mini (5th generation)", "iPad mini (5th generation)", 2019, "12.2", "back camera", [IPAD_WIDE_8MP, IPAD_FRONT_7MP]),
    ("iPad (7th generation)", "iPad (7th generation)", 2019, "13.1", "back camera", [IPAD_WIDE_8MP, IPAD_FRONT_5]),
    ("iPad Pro (11-inch) (2nd generation)", "iPad Pro (11-inch) (2nd generation)", 2020, "13.4", "back dual wide camera", [IPAD_PRO_UW, IPAD_WIDE_12MP, IPAD_FRONT_TD]),
    ("iPad Pro (12.9-inch) (4th generation)", "iPad Pro (12.9-inch) (4th generation)", 2020, "13.4", "back dual wide camera", [IPAD_PRO_UW, IPAD_WIDE_12MP, IPAD_FRONT_TD]),
    ("iPad (8th generation)", "iPad (8th generation)", 2020, "14.0", "back camera", [IPAD_WIDE_8MP, L(F, 2.15, 2.4, 31, est=True)]),
    ("iPad Air (4th generation)", "iPad Air (4th generation)", 2020, "14.1", "back camera", [IPAD_WIDE_12MP, IPAD_FRONT_7MP]),
    ("iPad Pro (11-inch) (3rd generation)", "iPad Pro (11-inch) (3rd generation)", 2021, "14.5", "back dual wide camera", [IPAD_PRO_UW, IPAD_WIDE_12MP, IPAD_FRONT_UW]),
    ("iPad Pro (12.9-inch) (5th generation)", "iPad Pro (12.9-inch) (5th generation)", 2021, "14.5", "back dual wide camera", [IPAD_PRO_UW, IPAD_WIDE_12MP, IPAD_FRONT_UW]),
    ("iPad (9th generation)", "iPad (9th generation)", 2021, "15.0", "back camera", [IPAD_WIDE_8MP, dict(IPAD_FRONT_UW, est=True)]),
    ("iPad mini (6th generation)", "iPad mini (6th generation)", 2021, "15.0", "back camera", [dict(IPAD_WIDE_12MP, est=True), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad Air (5th generation)", "iPad Air (5th generation)", 2022, "15.4", "back camera", [IPAD_WIDE_12MP, dict(IPAD_FRONT_UW, est=True)]),
    ("iPad (10th generation)", "iPad (10th generation)", 2022, "16.1", "back camera", [IPAD_WIDE_12MP, IPAD_FRONT_UW]),
    ("iPad Pro (11-inch) (4th generation)", "iPad Pro (11-inch) (4th generation)", 2022, "16.1", "back dual wide camera", [IPAD_PRO_UW, IPAD_WIDE_12MP, IPAD_FRONT_UW]),
    ("iPad Pro (12.9-inch) (6th generation)", "iPad Pro (12.9-inch) (6th generation)", 2022, "16.1", "back dual wide camera", [IPAD_PRO_UW, IPAD_WIDE_12MP, IPAD_FRONT_UW]),
    ("iPad Air 11-inch (M2)", "iPad Air 11-inch (M2)", 2024, "17.4", "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad Air 13-inch (M2)", "iPad Air 13-inch (M2)", 2024, "17.4", "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad Pro 11-inch (M4)", "iPad Pro 11-inch (M4)", 2024, "17.5", "back camera", [L(W, 3.0, 1.8, 28), IPAD_FRONT_M4]),
    ("iPad Pro 13-inch (M4)", "iPad Pro 13-inch (M4)", 2024, "17.5", "back camera", [L(W, 3.0, 1.8, 28), IPAD_FRONT_M4]),
    ("iPad mini (A17 Pro)", "iPad mini (A17 Pro)", 2024, "18.0", "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad (A16)", "iPad (A16)", 2025, "18.3", "back camera", [IPAD_WIDE_12MP, IPAD_FRONT_UW]),
    ("iPad Air 11-inch (M3)", "iPad Air 11-inch (M3)", 2025, "18.3", "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad Air 13-inch (M3)", "iPad Air 13-inch (M3)", 2025, "18.3", "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad Pro 11-inch (M5)", "iPad Pro 11-inch (M5)", 2025, "26.0", "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_M4, est=True)]),
    ("iPad Pro 13-inch (M5)", "iPad Pro 13-inch (M5)", 2025, "26.0", "back camera", [L(W, 3.0, 1.8, 28, est=True), dict(IPAD_FRONT_M4, est=True)]),
    ("iPad Air 11-inch (M4)", "iPad Air 11-inch (M4)", 2026, None, "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
    ("iPad Air 13-inch (M4)", "iPad Air 13-inch (M4)", 2026, None, "back camera", [L(W, 3.0, 1.8, 28), dict(IPAD_FRONT_UW, est=True)]),
]

def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


# ---- 默认输出分辨率（4:3 横向，长边 × 短边）与 HEIC 支持 ----
MP = {
    "0.3": (640, 480), "0.9": (1280, 960), "0.7": (960, 720), "1.2": (1280, 960), "5": (2592, 1936), "5f": (2576, 1932),
    "7": (3088, 2320), "8": (3264, 2448), "10": (3648, 2736), "12": (4032, 3024), "18": (4896, 3672), "24": (5712, 4284),
}

# 相机默认输出 24MP 的机型（主摄 48MP，默认合成 24MP）
MAIN_24MP = {"iPhone 15", "iPhone 15 Plus", "iPhone 15 Pro", "iPhone 15 Pro Max", "iPhone 16", "iPhone 16 Plus",
             "iPhone 16 Pro", "iPhone 16 Pro Max", "iPhone 16e", "iPhone 17", "iPhone Air", "iPhone 17 Pro",
             "iPhone 17 Pro Max", "iPhone 17e", "iPhone 18 Pro", "iPhone 18 Pro Max", "iPhone Duo"}
ALL_24MP = {"iPhone 17", "iPhone 17 Pro", "iPhone 17 Pro Max", "iPhone 18 Pro", "iPhone 18 Pro Max"}
FRONT_18MP = {"iPhone 17", "iPhone Air", "iPhone 17 Pro", "iPhone 17 Pro Max", "iPhone 18 Pro", "iPhone 18 Pro Max"}

# 不支持 HEIC 拍摄的机型（A10 之前的芯片），其余默认 HEIC
JPEG_ONLY = {"iPhone 4", "iPhone 4S", "iPhone 5", "iPhone 5c", "iPhone 5s", "iPhone 6", "iPhone 6 Plus", "iPhone 6s",
             "iPhone 6s Plus", "iPhone SE", "iPad 2", "iPad (3rd generation)", "iPad (4th generation)", "iPad mini",
             "iPad Air", "iPad mini 2", "iPad Air 2", "iPad mini 3", "iPad mini 4", "iPad Pro (12.9-inch)",
             "iPad Pro (9.7-inch)", "iPad (5th generation)"}

IPAD_REAR = {
    "iPad 2": "0.7", "iPad (3rd generation)": "5", "iPad (4th generation)": "5", "iPad mini": "5", "iPad Air": "5",
    "iPad mini 2": "5", "iPad mini 3": "5", "iPad Air 2": "8", "iPad mini 4": "8", "iPad Pro (12.9-inch)": "8",
    "iPad Pro (9.7-inch)": "12", "iPad (5th generation)": "8", "iPad (6th generation)": "8", "iPad (7th generation)": "8",
    "iPad (8th generation)": "8", "iPad (9th generation)": "8", "iPad Air (3rd generation)": "8", "iPad mini (5th generation)": "8",
}
IPAD_FRONT = {
    "iPad 2": "0.3", "iPad (3rd generation)": "0.3", "iPad Pro (9.7-inch)": "5f",
    "iPad Pro (10.5-inch)": "7", "iPad Pro (12.9-inch) (2nd generation)": "7", "iPad Pro (11-inch)": "7",
    "iPad Pro (12.9-inch) (3rd generation)": "7", "iPad Pro (11-inch) (2nd generation)": "7",
    "iPad Pro (12.9-inch) (4th generation)": "7", "iPad Air (3rd generation)": "7", "iPad mini (5th generation)": "7",
    "iPad Air (4th generation)": "7",
}
IPAD_FRONT_12 = ("(9th generation)", "(10th generation)", "(A16)", "mini (6th", "mini (A17", "Air (5th", "M2)", "M3)", "M4)", "M5)",
                 "(11-inch) (3rd", "(12.9-inch) (5th", "(11-inch) (4th", "(12.9-inch) (6th")

def output_size(name, kind):
    if name.startswith("iPad"):
        if kind == "front":
            if name in IPAD_FRONT: return MP[IPAD_FRONT[name]]
            if any(k in name for k in IPAD_FRONT_12): return MP["12"]
            return MP["0.9"]
        if kind == "ultraWide": return MP["10"]
        return MP[IPAD_REAR.get(name, "12")]
    if kind == "front":
        if name in FRONT_18MP: return MP["18"]
        if name in ("iPhone 4", "iPhone 4S"): return MP["0.3"]
        if name in ("iPhone 5", "iPhone 5c", "iPhone 5s", "iPhone 6", "iPhone 6 Plus", "iPhone SE"): return MP["0.9"]
        if name in ("iPhone 6s", "iPhone 6s Plus"): return MP["5f"]
        if name in ("iPhone 7", "iPhone 7 Plus", "iPhone 8", "iPhone 8 Plus", "iPhone X", "iPhone XR", "iPhone XS",
                    "iPhone XS Max", "iPhone SE (2nd generation)", "iPhone SE (3rd generation)"): return MP["7"]
        return MP["12"]
    if name == "iPhone 4": return MP["5"]
    if name in ("iPhone 4S", "iPhone 5", "iPhone 5c", "iPhone 5s", "iPhone 6", "iPhone 6 Plus"): return MP["8"]
    if kind == "wide" and name in MAIN_24MP: return MP["24"]
    # GSMArena 原图：17 / 17 Pro / 17 Pro Max 的超广角和长焦默认也输出 24MP
    if kind in ("ultraWide", "telephoto") and name in ALL_24MP: return MP["24"]
    return MP["12"]

def build(family, model, year, software, module, lenses, name=None):
    out = []
    for lens in lenses:
        mod = (TRUEDEPTH_NAME if (name or model) in TRUEDEPTH else "front camera") if lens["position"] == "front" else module
        entry = {
            "id": lens["kind"],
            "position": lens["position"],
            "kind": lens["kind"],
            "lensModel": f"{model} {mod} " + (lens.get("label") or f"{num(lens['fl'])}mm f/{num(lens.get('lensFn', lens['fn']))}"),
            "focalLength": lens["fl"],
            "fNumber": lens["fn"],
            "focalLength35mm": lens["f35"],
        }
        w, h = output_size(name or model, lens["kind"])
        entry["pixelWidth"], entry["pixelHeight"] = w, h
        if lens.get("est"):
            entry["estimated"] = True
        out.append(entry)
    order = {"ultraWide": 0, "wide": 1, "telephoto": 2, "front": 3}
    out.sort(key=lambda l: order[l["kind"]])
    d = {"id": slug(name or model), "family": family, "model": model, "make": "Apple", "year": year, "lenses": out}
    if name and name != model:
        d["name"] = name
    if software:
        d["software"] = software
    d["heif"] = (name or model) not in JPEG_ONLY
    return d

devices = [build("iPhone", *row) for row in IPHONES]
devices += [build("iPad", model, year, software, module, lenses, name=name)
            for name, model, year, software, module, lenses in IPADS]

ids = [d["id"] for d in devices]
assert len(ids) == len(set(ids)), "duplicate ids"
dest = os.path.join(os.path.dirname(__file__), "..", "ExifEditor", "Resources", "Devices.json")
json.dump({"version": 1, "devices": devices}, open(dest, "w"), indent=1, ensure_ascii=False)
print(f"{len(devices)} devices, {sum(len(d['lenses']) for d in devices)} lenses, "
      f"{sum(1 for d in devices for l in d['lenses'] if l.get('estimated'))} estimated")
