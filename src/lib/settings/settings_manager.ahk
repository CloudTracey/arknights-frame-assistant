; == 设置管理入口 ==

; 加载器：负责从配置文件加载设置
#Include ./loader.ahk

; 热键冲突验证器：供实时 GUI 提示和保存阶段校验复用
#Include ./hotkey_conflict_validator.ahk

; 保存器：负责保存设置到配置文件
#Include ./saver.ahk

; 操作器：负责处理用户设置操作
#Include ./actions.ahk
