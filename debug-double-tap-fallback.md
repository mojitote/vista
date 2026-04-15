# [OPEN] double-tap-fallback

## 症状
- 已开启双指轻点作为右键。
- 单次双指轻点可以产生右键。
- 双指双击轻点无法唤出 Vista。
- 当前代码已加入“两次 rightMouseDown 也算双击”的 fallback，但用户反馈仍然失败。

## 本轮目标
- 重新构建应用。
- 启动调试服务并采集现有埋点日志。
- 确认失败发生在事件接收、fallback 判定，还是最终触发链路。

## 初始假设
- A: 双指双击轻点虽然产生右键，但第二次事件没有进入全局 `rightMouseDown` 监听。
- B: 两次 `rightMouseDown` 都到了，但间隔超过 `0.35s`，被 fallback 时间窗过滤。
- C: 两次事件的位置漂移超过 `24px`，被 fallback 距离阈值过滤。
- D: fallback 已经判定成功，但后续 `triggerIfReady()` 被 cooldown 或屏幕定位分支吞掉。
- E: 重新构建后的产物没有被实际启动，用户测试的仍是旧版本。
