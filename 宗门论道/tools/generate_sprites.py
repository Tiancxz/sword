#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_sprites.py - 程序化生成像素风游戏精灵（透明底PNG）
用法: python3 tools/generate_sprites.py
输出: assets/art/*.png
说明: 每个精灵用字符画定义（每字符=1像素），统一色板，2x整数放大保证像素锐利。
"""
import os
from PIL import Image

OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art")

# ===== 全局色板（字符 -> RGBA）=====
T = (0, 0, 0, 0)          # . 透明
PAL = {
    "O": (24, 20, 30, 255),      # 描边近黑
    "S": (232, 190, 150, 255),   # 皮肤
    "H": (50, 40, 46, 255),      # 深发色
    "C": (60, 60, 74, 255),      # 浅发/灰
    "W": (170, 175, 185, 255),   # 金属/墙
    "w": (120, 125, 135, 255),   # 暗金属
    "E": (30, 30, 34, 255),      # 眼睛（黑）
    "R": (58, 96, 168, 255),     # 攻方蓝袍
    "r": (40, 66, 120, 255),     # 蓝袍暗部
    "D": (240, 238, 230, 255),   # 白（胡子）
    "G": (96, 200, 210, 255),    # 青（灵光/剑格）
    "g": (56, 140, 155, 255),    # 暗青
    "Y": (240, 200, 90, 255),    # 金/亮
    "y": (190, 150, 55, 255),    # 暗金
    "K": (44, 38, 52, 255),      # 刺客黑袍
    "k": (30, 26, 36, 255),      # 更黑
    "V": (170, 60, 70, 255),     # 红眼/红饰
    "P": (90, 84, 100, 255),     # 裤子灰紫
    "B": (150, 110, 60, 255),    # 腰带棕
    "N": (178, 82, 66, 255),     # 守方红袍
    "n": (130, 56, 48, 255),     # 红袍暗部
    "U": (70, 160, 90, 255),     # 兽毛绿? 未用
    "F": (70, 60, 56, 255),      # 鞋
    "L": (200, 120, 60, 255),    # 体修肤色暗（肌肉阴影）
    "X": (150, 160, 175, 255),   # 石/柱
}

def make_sprite(name: str, rows: list, scale: int = 2):
    """字符画 -> PNG。行可不等长（右侧自动补透明），未知字符报错。"""
    h = len(rows)
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), T)
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            if ch not in PAL:
                raise ValueError(f"[{name}] 未知色板字符: '{ch}' (行{y} 列{x})")
            px[x, y] = PAL[ch]
    if scale > 1:
        img = img.resize((w * scale, h * scale), Image.NEAREST)
    path = os.path.join(OUT_DIR, name + ".png")
    img.save(path)
    print(f"  {name}.png  {img.size[0]}x{img.size[1]}")

def derive_walk_frames(rows: list) -> list:
    """从基础帧推导走路动画帧。
    f0=双脚着地, f1=左脚抬起(上移1px), f2=右脚抬起。
    脚色='F'。无脚（浮空单位）或只有一只脚时返回单帧。"""
    import re
    feet_y = -1
    for y in range(len(rows) - 1, -1, -1):
        if "F" in rows[y]:
            feet_y = y
            break
    if feet_y < 0:
        return [rows]
    runs = [m.span() for m in re.finditer(r"F+", rows[feet_y])]
    if len(runs) < 2:
        return [rows]

    def lift(run) -> list:
        grid = [list(r) for r in rows]
        for x in range(run[0], run[1]):
            grid[feet_y][x] = "."
            # 脚上移1px（上方是透明才移，否则删除=收腿）
            if feet_y > 0 and grid[feet_y - 1][x] == ".":
                grid[feet_y - 1][x] = "F"
        return ["".join(r) for r in grid]

    return [rows, lift(runs[0]), lift(runs[-1])]

# ============================================================
# 单位精灵（13~14宽，2x放大后渲染为52px）
# ============================================================

# 御兽弟子：蓝袍 + 胸前灵兽铃(青) + 束发
BEAST = [
    ".....HHH.....",
    "....HHHHH....",
    "....HSSSH....",
    "....SESES....",
    ".....SSS.....",
    "....RRRRR....",
    "...RRRRRRR...",
    "..SRRRRRRS...",
    "..S.GGG.RS...",
    "....BRRRB....",
    "....RR.RR....",
    "....RR.RR....",
    "...FF...FF...",
]

# 体修弟子：光膀子肌肉 + 红腰带 + 束腕
BODY = [
    ".....HHH.....",
    "....HSSSH....",
    "....SESES....",
    ".....SSS.....",
    "...SSSSSSS...",
    "..SSSSSSSSS..",
    ".SSLSLLSLSS..",
    ".SS.SSSS.SS..",
    "..B.SSSS.B...",
    "....PPPPP....",
    "....PP.PP....",
    "....PP.PP....",
    "...FF...FF...",
]

# 剑修弟子：蓝袍 + 右侧竖剑(金属+金剑格) + 发髻
SWORD = [
    "......H......",
    ".....HHH.....",
    "....HSSSH....",
    "....SESES....",
    ".....SSS.....",
    "....RRRRR.W..",
    "...RRRRRR.W..",
    "..SRRRRRS.W..",
    "..S.RRRRYGW..",
    "....BRRRB.W..",
    "....RR.RR....",
    "....RR.RR....",
    "...FF...FF...",
]

# 影剑（守方刺客）：黑袍 + 红眼 + 红围巾 + 双臂交叉
YING = [
    ".....HHH.....",
    "....HHHHH....",
    "....HEVEH....",
    ".....VVV.....",
    "....KKKKK....",
    "...KKKKKKK...",
    "..SKKKKKKS...",
    "..S.KKKK.S...",
    "....KKKKK....",
    "....KkKkK....",
    "....KK.KK....",
    "....KK.KK....",
    "...FF...FF...",
]

# 护体剑灵（守方）：浮空巨剑 + 青色灵光环绕（非人形）
JIANLING = [
    ".....G.G.....",
    "......G......",
    ".....GYG.....",
    "......W......",
    "......W......",
    "......W......",
    "....GGWGG....",
    "...G.gWg.G...",
    "......W......",
    "......w......",
    "......w......",
    ".....gwg.....",
    ".....G.G.....",
]

# 守门灵兽（守方）：四足瑞兽 + 金角 + 红毛
GUARDIAN = [
    "...Y....Y....",
    "....YYYY.....",
    "....NNNN.....",
    "...NWNWNN....",
    "..NNNNNNNN...",
    ".NNNNNNNNNN..",
    ".NNNNNNNNNN..",
    ".NNnNNNNnNN..",
    ".NN.NNNN.NN..",
    ".NN.NNNN.NN..",
    ".FF.FFFF.FF..",
    ".............",
]

# 金丹长老（精英16x16，2x放大后渲染为64px）：金袍 + 白须 + 头顶金丹
ELDER = [
    "......YY......",
    ".....YYYY.....",
    ".....HHHH.....",
    "....HSSSSH....",
    "....SESESH....",
    "....HSSSSH....",
    "....DDDDDD....",
    "...YYYYYYYY...",
    "..SYYYWWYYYS..",
    "..S.YYYYYY.S..",
    "...ByYYYYyB...",
    "...YYYYYYYY...",
    "...YYY..YYY...",
    "...YYY..YYY...",
    "..FF......FF..",
    "..............",
]

# ============================================================
# 大殿精灵（19宽，2x放大后渲染为76px）
# ============================================================

# 攻方大殿：蓝瓦 + 金脊 + 白墙金柱
HALL_ATK = [
    ".......YYY.......",
    ".....YYYYYYY.....",
    "....RRRRRRRRR....",
    "...RRRRRRRRRRR...",
    "..RRRRRRRRRRRRR..",
    ".RRRRRRRRRRRRRRR.",
    ".rrrrrrrrrrrrrrr.",
    "..OOOOOOOOOOOOO..",
    "...XWWWWWWWWWX...",
    "...XWYWWWWWYWX...",
    "...XWYWWWWWYWX...",
    "...XWYOOWOOYWX...",
    "...XWYOOWOOYWX...",
    "...XWYOOWOOYWX...",
    "...XWWOOWOOWWX...",
    "...XXXXXXXXXXX...",
    "................",
]

# 守方大殿：红瓦 + 金脊 + 暗墙红旗
HALL_DEF = [
    ".......YYY.......",
    ".....YYYYYYY.....",
    "....NNNNNNNNN....",
    "...NNNNNNNNNNN...",
    "..NNNNNNNNNNNNN..",
    ".NNNNNNNNNNNNNNN.",
    ".nnnnnnnnnnnnnnn.",
    "..OOOOOOOOOOOOO..",
    "...XwwwwwwwwwX...",
    "...XwVwwwwwVwX...",
    "...XwVwwwwwVwX...",
    "...XwVOOwOOVwX...",
    "...XwVOOwOOVwX...",
    "...XwVOOwOOVwX...",
    "...XwwOOwOOwwX...",
    "...XXXXXXXXXXX...",
    "................",
]

def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("生成像素精灵 ->", os.path.abspath(OUT_DIR))
    # 单位（走路帧 f0/f1/f2，普通26px宽 / 精英32px宽，游戏内2x渲染）
    units = [
        ("unit_beast_disciple", BEAST),
        ("unit_body_disciple", BODY),
        ("unit_sword_disciple", SWORD),
        ("unit_ying_jian", YING),
        ("unit_huti_jianling", JIANLING),
        ("unit_guardian_beast", GUARDIAN),
        ("unit_elder_jindan", ELDER),
    ]
    frame_count = 0
    for name, art in units:
        for i, frame in enumerate(derive_walk_frames(art)):
            make_sprite("%s_f%d" % (name, i), frame)
            frame_count += 1
    # 大殿（单帧）
    make_sprite("hall_attacker", HALL_ATK)
    make_sprite("hall_defender", HALL_DEF)
    print("完成: %d 张单位动画帧 + 2 张大殿" % frame_count)

if __name__ == "__main__":
    main()
