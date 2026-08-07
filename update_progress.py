#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""更新Excel开发管理表中的任务状态
用法: python3 update_progress.py <任务编号> <状态>
示例: python3 update_progress.py A1.01 完成
      python3 update_progress.py A1.01,A1.02,A1.03 完成
"""
import sys
from openpyxl import load_workbook

EXCEL_PATH = '/workspace/宗门论道_Godot开发管理工具包.xlsx'
MAIN_SHEET = '2.开发主表'
STATUS_COL = 15  # O列

# 状态颜色（与Excel样式一致）
STATUS_COLORS = {
    '待办': 'FCE4D6',
    '进行中': 'FFF2CC',
    '完成': 'C6EFCE',
}

def update_status(codes, status):
    """更新指定任务编号的状态"""
    if status not in STATUS_COLORS:
        print(f'错误: 状态必须是 {list(STATUS_COLORS.keys())} 之一')
        return False
    
    wb = load_workbook(EXCEL_PATH)
    ws = wb[MAIN_SHEET]
    
    found = {code: False for code in codes}
    updated = 0
    
    for row in range(3, ws.max_row + 1):
        code = ws.cell(row=row, column=2).value  # B列=编号
        if code in codes:
            found[code] = True
            cell = ws.cell(row=row, column=STATUS_COL)
            old_status = cell.value
            cell.value = status
            # 更新背景色
            from openpyxl.styles import PatternFill
            cell.fill = PatternFill('solid', fgColor=STATUS_COLORS[status])
            print(f'  {code}: {old_status} → {status}')
            updated += 1
    
    # 检查未找到的任务
    for code, was_found in found.items():
        if not was_found:
            print(f'  ⚠ {code}: 未找到（请检查编号）')
    
    if updated > 0:
        wb.save(EXCEL_PATH)
        print(f'\n✓ 已更新 {updated} 个任务，Excel已保存')
        
        # 打印当前进度统计
        print_progress(wb)
        return True
    else:
        print('\n✗ 没有任务被更新')
        return False

def print_progress(wb):
    """打印当前进度统计"""
    ws_main = wb[MAIN_SHEET]
    total = done = 0
    for row in range(3, ws_main.max_row + 1):
        lvl = ws_main.cell(row=row, column=1).value
        if lvl == 'L3':
            total += 1
            if ws_main.cell(row=row, column=STATUS_COL).value == '完成':
                done += 1
    pct = done / total * 100 if total > 0 else 0
    print(f'\n📊 当前进度: {done}/{total} ({pct:.1f}%)')

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print('用法: python3 update_progress.py <任务编号> <状态>')
        print('示例: python3 update_progress.py A1.01 完成')
        print('      python3 update_progress.py A1.01,A1.02 完成')
        sys.exit(1)
    
    codes = sys.argv[1].split(',')
    status = sys.argv[2]
    update_status(codes, status)
