; web 引擎（UiEngine=web）聚合入口：main.ahk 只 include 本文件一行，
; 避免在上游唯一的 include 热点里展开多个条目。

#Include ../../vendor/Promise.ahk
#Include ../../vendor/WebView2/WebView2.ahk
#Include web_host.ahk
