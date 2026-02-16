; == 设置管理入口 ==
; 包含设置相关的所有模块

; 加载器：负责从配置文件加载设置
#Include ./settings/loader.ahk

; 保存器：负责保存设置到配置文件
#Include ./settings/saver.ahk

; 操作器：负责处理用户设置操作
#Include ./settings/actions.ahk
