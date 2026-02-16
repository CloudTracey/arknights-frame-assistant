; == 事件总线 ==
; 提供发布-订阅模式，解耦模块间的直接依赖

class EventBus {
    ; 存储所有事件监听器
    static Listeners := Map()
    
    ; 订阅事件
    ; eventName: 事件名称
    ; callback: 回调函数
    static Subscribe(eventName, callback) {
        if (!this.Listeners.Has(eventName)) {
            this.Listeners[eventName] := []
        }
        this.Listeners[eventName].Push(callback)
    }
    
    ; 发布事件
    ; eventName: 事件名称
    ; data: 传递给监听器的数据
    static Publish(eventName, data := "") {
        if (!this.Listeners.Has(eventName)) {
            return
        }
        for callback in this.Listeners[eventName] {
            callback(data)
        }
    }
    
    ; 取消订阅（可选功能）
    static Unsubscribe(eventName, callback) {
        if (!this.Listeners.Has(eventName)) {
            return
        }
        newListeners := []
        for cb in this.Listeners[eventName] {
            if (cb != callback) {
                newListeners.Push(cb)
            }
        }
        this.Listeners[eventName] := newListeners
    }
}
