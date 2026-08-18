; == 事件总线 ==

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
            try {
                callback(data)
            } catch Error as e {
                ; 单个订阅者异常不应阻断其余订阅者；记录日志后继续
                callbackName := ""
                try callbackName := callback.Name
                Logger.Error("EventBus", "事件回调异常：event=" eventName ", callback=" callbackName ", error=" e.Message)
            }
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
