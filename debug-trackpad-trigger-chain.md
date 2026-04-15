# [OPEN] trackpad-trigger-chain

## 症状
- 选择 `Two-Finger Double-Tap` 后，热区有时仍然生效或切换状态混乱。
- 选择 `Two-Finger Double-Tap` 后，两指轻点多次没有触发侧边栏。

## 复现
1. 启动 `Vista.app`
2. 打开设置并切换触发模式
3. 观察热区是否关闭
4. 执行两指双击轻点，观察是否触发侧边栏

## 假设
- A: `triggerMode` 切换链路仍有状态漂移，`hotZoneManager` / `trackpadManager` 最终状态与 UI 选择不一致。
- B: `NSEvent.addGlobalMonitorForEvents(matching: [.gesture])` 根本收不到触控板轻点事件，导致 `handleGestureEvent` 从未进入。
- C: 轻点事件不是 `.gesture`，而是别的 `NSEvent.EventTypeMask` 或必须走 `CGEventTap` / `NSTouch` 相关链路。
- D: 事件进来了，但 `allTouches()` / `phase` 组合与当前检测条件不匹配，导致被误判为未触发。
- E: 触发其实发生了，但 `showSidebarAtPosition` 或其前置屏幕定位分支没有成功执行。

## 计划
- 仅做运行时插桩，不改业务判断。
- 用调试服务器采集模式切换、事件到达、事件判定、最终触发四段证据。
- 证据确认后再做最小修复。
