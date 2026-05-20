# Vista Voice — AI 驱动的桌面操控助手 PRD

## 1. 产品概述

### 1.1 产品定位

Vista Voice 是一个 **AI-first 的 macOS 桌面操控助手**。核心理念：**AI 永远是大脑**，所有用户意图 100% 经过 LLM 理解和决策，yabai + Computer Use 是 AI 的"双手"——yabai 加速高频窗口操作，Computer Use 覆盖一切 UI。

**核心竞争力：Context 管理** — AI 持续感知桌面状态、用户意图、Agent 进度，形成连贯的操控体验。

### 1.2 目标用户

- 开发者（编程工作流为主）
- 多显示器 / 多 Space 重度用户
- 希望解放双手、减少上下文切换的效率用户

### 1.3 核心价值主张

> "对电脑说话，它就去做。做完了，它会告诉你。"

- **AI 为核心** — 不是规则引擎配语音，是真正理解你意图的 AI
- **极速响应** — yabai 跳过截图循环，窗口操作 <10ms
- **万能操控** — Computer Use 兜底，任何 UI 都能操作
- **上下文感知** — AI 知道你在干什么、屏幕上有什么、Agent 做到哪了

---

## 2. 产品架构

### 2.1 核心设计原则

1. **AI 永远在环路中** — 每一条指令都经过 LLM 理解，不做 rule-based 分流
2. **yabai 是加速器** — 对于窗口级操作，绕过截图循环，直接结构化调用
3. **Computer Use 是通用能力** — 任何 yabai 做不到的 UI 操作（点按钮、填表单），走截图→推理→点击
4. **Context 是护城河** — 持续维护桌面状态、用户行为模式、Agent 进度

### 2.2 系统架构图

```
┌────────────────────────────────────────────────────────────────┐
│                         Voice I/O                               │
│               ASR (whisper) ←→ TTS (系统/Doubao)                │
└───────────────────────────┬────────────────────────────────────┘
                            │ 文本
┌───────────────────────────▼────────────────────────────────────┐
│                                                                 │
│                    LLM Brain (核心大脑)                          │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │              Context Manager (上下文管理)                   │ │
│  │                                                            │ │
│  │  • 窗口状态 (via yabai query: app/title/space/display)     │ │
│  │  • 屏幕快照 (定期截图 → 场景理解)                          │ │
│  │  • 用户意图历史 (多轮对话 + 操作序列)                       │ │
│  │  • Agent 工作状态 (进度/产出/错误)                          │ │
│  │  • 时间上下文 (刚才做了什么/接下来可能做什么)               │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                 │
│  LLM 决策：这条指令用什么执行？                                 │
│                                                                 │
└──────┬──────────────────┬──────────────────┬───────────────────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌─────────────┐   ┌─────────────┐   ┌──────────────┐
│  yabai      │   │ Computer    │   │  Agent       │
│  (结构化)   │   │ Use (视觉)  │   │  Delegation  │
│             │   │             │   │              │
│ • focus     │   │ • 截图      │   │ • coding     │
│ • move      │   │ • 识别 UI   │   │ • search     │
│ • close     │   │ • 点击/输入 │   │ • build      │
│ • space     │   │ • 拖拽      │   │ • 任意任务   │
│             │   │             │   │              │
│ 延迟:<10ms  │   │ 延迟:2-5s   │   │ 延迟:异步    │
└─────────────┘   └─────────────┘   └──────────────┘
```

### 2.3 LLM 决策逻辑

AI 拿到用户指令 + Context 后，自动选择最优执行路径：

| 操作类型 | 选择的"手" | 原因 |
|---------|-----------|------|
| 切换窗口/Space | yabai | 结构化数据已知，无需截图 |
| 移动/关闭窗口 | yabai | 同上 |
| 点击应用内按钮 | Computer Use | 需要视觉定位 |
| 填写表单/输入框 | Computer Use | 需要精确 UI 交互 |
| 启动新应用 | yabai + AppleScript | 快速，不需要视觉 |
| "帮我修这个 bug" | Agent Delegation | 异步任务 |
| "这个页面的表格里第三行是什么" | Computer Use (读取) | 需要屏幕理解 |

### 2.4 数据流

```
用户说话 → ASR → LLM Brain (+ Context) → 决策执行路径
                      │                         │
                      │ 更新 Context ◀──────────┘
                      │                         │
                      └── TTS 反馈 ◀────────────┘

外部事件 (Agent完成/构建结果) → Context 更新 → LLM 判断是否打断用户 → TTS
```

---

## 3. Context Manager（核心模块）

### 3.1 Context 包含什么

```typescript
interface DesktopContext {
  // 结构化状态（via yabai，实时，零成本）
  windows: Window[]           // 所有窗口: app, title, space, display, focused
  spaces: Space[]             // 所有桌面状态
  currentFocus: Window        // 当前聚焦窗口
  
  // 视觉状态（定期截图，或按需触发）
  screenSnapshot?: Screenshot // 当前屏幕截图
  lastScreenChange?: string   // 屏幕变化摘要
  
  // 用户意图（历史）
  recentCommands: Command[]   // 最近 N 条指令 + 结果
  currentTask?: string        // 用户当前在做什么（AI 推断）
  
  // Agent 状态
  activeAgents: AgentState[]  // 正在工作的 Agent
  pendingNotifications: Notification[] // 待播报的通知
  
  // 时间上下文
  sessionStart: Date
  lastInteraction: Date
  idleDuration: Duration
}
```

> 完整数据模型（6 层结构 + 子类型定义）详见 [context-design.md](./context-design.md) 第 2 章。

### 3.2 Context 更新策略

| 数据源 | 更新频率 | 方式 |
|--------|---------|------|
| yabai 窗口/桌面状态 | 每次指令前 + 每 3 秒轮询 | yabai query（<10ms） |
| 屏幕截图 | 按需（用户问"屏幕上有什么"时） | screencapture |
| 对话历史 | 每次交互后 | append |
| Agent 状态 | Agent 输出时 | event 驱动 |
| 当前任务推断 | 每次交互后 | LLM 总结 |

> 详细的分层更新策略、时序图、视觉触发条件见 [context-design.md](./context-design.md) 第 3 章。

### 3.3 为什么 Context 是护城河

1. **让 AI 的决策更准确** — "切到刚才那个" AI 知道"刚才"是什么
2. **让 AI 能主动行动** — 知道构建失败了+知道你在等构建 → 主动告诉你
3. **让 Computer Use 更高效** — 已知窗口在哪，只需截具体区域而非全屏
4. **让多轮对话连贯** — "再往右移一点" AI 知道移的是哪个窗口

---

## 4. MVP 范围（Phase 1）

### 4.1 核心能力

#### 语音 I/O

| 项目 | 规格 |
|------|------|
| 触发方式 | 唤醒词（"Hey Vista"）或快捷键 toggle |
| ASR | whisper.cpp（本地，small/medium 模型） |
| 语言 | 中文 + 英文混合 |
| VAD | 检测说话起止，自动分句 |
| TTS | macOS 系统 TTS（零延迟）|
| ASR 延迟 | < 500ms |

#### LLM Brain（核心大脑）

| 项目 | 规格 |
|------|------|
| 模型 | 豆包 API（Doubao） |
| 角色 | 100% 所有指令经过 LLM，不做 rule-based 分流 |
| Tool Calling | 通过 function calling 调用执行工具 |
| Context 注入 | 每次调用携带 Always Context（窗口描述 + 状态） |
| 对话是工具 | speak()/ask() 是 LLM 的可选工具，非义务 |

#### 执行层工具

| 工具 | 能力 | 延迟 | 阶段 |
|------|------|------|------|
| `yabai_query` | 查询窗口/Space/显示器状态 | <10ms | Phase 1 |
| `yabai_action` | focus/move/close/fullscreen | <10ms | Phase 1 |
| `terminal_run` | AppleScript 在终端执行命令 | <200ms | Phase 1 |
| `agent_delegate` | 委派异步任务给 coding agent | 异步 | Phase 1 |
| `show_popup` | 宠物气泡显示文本（轻量视觉反馈，自动消失） | 0 | Phase 1 |
| `speak` | 对用户说话（TTS，用于重要信息）| <100ms | Phase 1 |
| `ask` | 追问用户并等待回答 | — | Phase 1 |
| `update_window_description` | 更新窗口语义描述 | 0 | Phase 1 |
| `computer_use` | 截图 + 视觉操作（点击/输入/拖拽） | 2-5s | Phase 2 |

#### Context Manager

| 功能 | MVP 范围 |
|------|---------|
| 窗口描述（description + tags） | ✅ AI 自动维护 |
| 窗口/Space 实时状态 | ✅ yabai query |
| 对话历史 | ✅ 最近 20 轮 |
| Reference Stack（"刚才"/"这个"） | ✅ |
| Agent 状态追踪 | ✅ 基础（运行中/完成） |
| 主动通知调度 | ✅ idle 时播报 |
| 屏幕截图/视觉理解 | ⬜ Phase 2 |
| 用户任务推断 | ⬜ Phase 2 |
| 跨 Session 持久化 | ⬜ Phase 2 |

---

### 4.2 MVP 不做的事

| 不做 | 原因 | 阶段 |
|------|------|------|
| Computer Use（截图+视觉操作） | Phase 1 聚焦窗口管理 | Phase 2 |
| 全屏视觉理解（定期截图） | 成本高 | Phase 2 |
| 高级手势（挥手/捏合快捷操作） | 先做指向检测 | Phase 3 |
| 跨平台 | 先做好 macOS | 远期 |
| 用户行为模式学习 | 需要数据积累 | Phase 3 |

---

## 5. 技术方案

### 5.1 架构

```
Vista Voice = Swift CLI (vista-cmd) + Python Agent (vista-agent)

┌─────────────────────────────────────────────┐
│  vista-agent (Python 进程，常驻)              │
│                                              │
│  ┌─────────┐  ┌─────────┐  ┌────────────┐  │
│  │ whisper │  │  豆包    │  │  Context   │  │
│  │ (ASR)   │→│  (LLM)   │→│  Manager   │  │
│  └─────────┘  └────┬────┘  └────────────┘  │
│                     │ tool calls             │
│  ┌──────────────────▼──────────────────────┐│
│  │           Tool Router                    ││
│  │  yabai_* → vista-cmd (subprocess)        ││
│  │  terminal_* → vista-cmd run              ││
│  │  computer_use → Gemini/Claude API        ││
│  │  agent_delegate → coding agent pipe      ││
│  │  speak/ask → macOS say / mic input       ││
│  └──────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
         │
         │ subprocess
         ▼
┌─────────────────────────────────────────────┐
│  vista-cmd (Swift CLI)                       │
│  直连 yabai socket + AppleScript             │
└─────────────────────────────────────────────┘
```

### 5.2 技术选型

| 模块 | 选型 | 理由 |
|------|------|------|
| ASR | whisper.cpp (faster-whisper) | 本地、中英混合好 |
| LLM | 豆包 API (Doubao) | 国内快、Tool Calling 支持好 |
| 窗口管理 | yabai (现有 socket) | 已有，极快 |
| Computer Use | Gemini 2.5 Computer Use API | 浏览器操作强、延迟低 |
| TTS | macOS `say` 命令 | 零延迟、免费 |
| Agent 通信 | stdin/stdout pipe | 通用 |
| CLI | Swift (vista-cmd) | 与 Vista 一体 |
| Agent | Python (vista-agent) | 生态好（whisper/openai SDK） |

### 5.3 LLM System Prompt

```
你是 Vista，一个自主的 macOS 桌面操控 Agent。

## 核心身份
你不是聊天机器人。你是执行者。
用户对你说话 = 下达指令。默认行为：执行，不回复。

## 工具
- yabai_action: 窗口操作（极快<10ms），优先用
- terminal_run: 终端命令
- agent_delegate: 委派异步任务
- show_popup(text): 宠物气泡提示（轻量确认，1-2秒自动消失）
- speak(text): 对用户说话（TTS，仅重要信息时用）
- ask(question): 追问用户
- update_window_description: 更新窗口描述
- gesture_direction(): 获取手势指向的显示器（配合"在这里""移过去"等指令）
- (Phase 2) computer_use: 视觉操作（截图+点击），窗口内 UI 操作时用

## 沟通规则（三级反馈）
- 操作成功 + 结果可见 → popup() 轻量确认（"→ Terminal"）
- 操作成功 + 结果不可见（异步） → speak() 通知
- 意图不明 → ask()
- 失败/意外 → speak() 告知
- 说话风格：最短。永远不说"好的""收到"

## popup vs speak 选择
- popup: 快速确认、不打断、用户余光能看到即可（"→ Terminal" "▶ npm start" "✓ 已关闭"）
- speak: 需要用户注意力的信息（"构建挂了" "Agent做完了改了3个文件"）

## Context 使用
- "这个" = 当前聚焦窗口
- "那个"/"刚才" = referenceStack 上一个
- 窗口匹配靠 description + tags（AI 自己维护）
- 能用结构化数据(yabai)的，不截图
```

> Agent 沟通决策的完整设计（决策树、speak() 约束）详见 [context-design.md](./context-design.md) 第 8 章。

### 5.4 Context 管理

详见 [context-design.md](./context-design.md)

核心要点：
- 6 层 Context（桌面状态 → 视觉 → 历史 → 意图 → Agent → 环境）
- 每个窗口有 AI 维护的 `description` + `tags`
- 用户的描述反向更新窗口标签（"跑server那个" → 永久标记）
- Always Context < 500 tokens，每次带给 LLM
- speak() 是工具不是义务

---

## 6. 用户场景

### 场景 A：沉默执行 + Popup 反馈

```
用户：      "切到终端"
Vista：     [yabai focus Terminal，沉默]
宠物：      [popup 气泡: "→ Terminal" ，1秒后消失]

用户：      "跑 npm start"
Vista：     [终端执行，沉默]
宠物：      [popup: "▶ npm start"，1秒后消失]
            [更新终端窗口描述: "跑着 dev server"]
```

### 场景 B：Agent 异步 + 主动通知

```
用户：      "帮我把表单加个验证"
Vista：     [agent_delegate，沉默]

            ... 2 分钟后，agent 完成 ...
            [检查: 用户 idle 3 秒]

Vista：     speak("验证加好了，改了 LoginForm 和 validators")
```

### 场景 C：语义匹配 + 描述更新

```
用户：      "切到跑 server 那个终端"
Vista：     [匹配 description 含 "server" → Terminal #4]
            [yabai focus，沉默]
            [该窗口 userLabel 更新为 "server 终端"]

            ... 1 小时后 ...

用户：      "切到 server"
Vista：     [直接匹配 userLabel，沉默切换]
```

### 场景 D：歧义追问

```
用户：      "关掉那个"
Vista：     [Context: 最近操作了 Chrome 和 Terminal]
            ask("关哪个？Chrome 还是终端？")

用户：      "Chrome"
Vista：     [yabai close，沉默]
```

### 场景 F：构建失败打断

```
            ... 用户在浏览器看文档 ...
Vista：     [Event: 构建失败]
            [用户 idle 2 秒]
            speak("构建挂了，第 42 行类型错误")

用户：      "帮我修"
Vista：     [agent_delegate，context 含具体错误信息]
            [沉默]
```

### 场景 G：手势指向 + 语音 + 宠物反馈

```
用户：      [手指向右边屏幕] "在这里开个终端"
Vista：     [gesture_direction → display 2 (右屏)]
            [在 display 2 打开 Terminal]
宠物：      🎤→🤔→⚡ [状态流转]
            [popup: "→ Terminal @ 右屏"，1.5秒后消失]

用户：      [手指向左屏] "把这个移过去"
Vista：     [gesture_direction → display 1 (左屏)]
            [yabai_action: move current → display 1]
宠物：      [popup: "← 已移到左屏"]

用户：      "现在在干嘛"
宠物：      [当前状态: 🎤 听 — 表示正在等待指令]
Vista：     speak("2个Agent在跑，一个写测试，一个查bug")
```

---

## 7. 阶段规划

### Phase 1: MVP — 语音窗口管理 + 桌面宠物 + 手势

- [x] vista-cmd CLI（yabai + AppleScript）
- [ ] vista-agent Python（whisper + 豆包 + tool calling）
- [ ] Context Manager（窗口描述 + 历史 + reference）
- [ ] 主动通知调度
- [ ] 桌面宠物（极简形态：透明小窗口 + popup 气泡载体 + 状态指示 🎤听/🤔想/⚡做）
- [ ] 手势检测（macOS Vision framework，摄像头检测手指指向方向 → 映射到显示器）
- [ ] 端到端语音操控流程（纯窗口管理 + 终端命令 + 手势组合）

**Phase 1 能力边界：** 窗口级操作（切换/移动/关闭/全屏）+ 终端命令 + Agent 委派 + 桌面宠物反馈 + 手势指向定位。不做应用内 UI 操作。

### Phase 2: Computer Use + 深度操控

- [ ] Computer Use 集成（Gemini API）— 截图+视觉操作
- [ ] AX API 集成（加速 Computer Use，原生 app 免截图）
- [ ] 全屏视觉理解（定期截图场景感知）
- [ ] 用户任务推断（AI 自动识别你在做什么）
- [ ] 跨 Session 持久化（窗口描述/用户偏好）
- [ ] 更多 Agent 对接（MCP 协议）

**Phase 2 能力边界：** 可以操作应用内任何 UI（点按钮、填表单、拖拽）。

### Phase 3: 深度空间感知 + 高级手势

- [ ] 手势快捷操作（挥手=切窗口，捏合=关闭）
- [ ] 显示器空间映射优化（物理方位自动校准）
- [ ] 多模态实时对话（看屏幕+说话+手势同时进行）
- [ ] 用户行为模式学习
- [ ] 工作流录制与回放

#### 手势 + 语音场景示例（Phase 3 高级手势）

```
用户：      [手掌挥一下]
Vista：     [手势识别: 挥手 = 切到上一个窗口]
            [yabai focus 上一个窗口]
```

---

## 8. 成功指标

### MVP

| 指标 | 目标 |
|------|------|
| 端到端延迟（说完→操作发生） | 窗口操作 < 1.5s，视觉操作 < 5s |
| 意图理解准确率 | > 90%（含模糊指代） |
| 每天无需鼠标操作的比例 | > 50%（窗口管理场景） |
| AI 不该说话时沉默的比例 | > 95% |
| 窗口描述准确率 | > 80%（用户认可 AI 的描述） |

### 长期

| 指标 | 目标 |
|------|------|
| 全天不碰鼠标比例 | > 70% |
| Context 匹配模糊指代准确率 | > 90% |
| 通知时机合适率 | > 95% |

---

## 9. 风险与应对

| 风险 | 应对 |
|------|------|
| ASR 中英混合差 | LLM 容错 + 用户纠正 |
| 豆包 API 延迟波动 | 简单窗口操作本地快速路径 |
| yabai 兼容性 | 跟随更新，必要时 fork |
| Computer Use 准确度 | yabai 提供结构化信息辅助定位 |
| 窗口描述过期 | title 变化时自动重新推断 |
| 误触发 | 唤醒词 + 危险操作 ask() 确认 |

---

## 10. 与竞品差异

| 维度 | Vista Voice | Claude Computer Use | Gemini Desktop | Copilot |
|------|------------|--------------------|----|---------|
| 窗口操作延迟 | <10ms (yabai) | 2-5s (截图) | 不支持桌面 | 不支持 |
| Context 感知 | 窗口描述+标签+历史 | 每次只看一张截图 | 仅当前窗口 | 仅当前窗口 |
| 对话风格 | 沉默执行为主 | 每次都回复 | 每次都回复 | 每次都回复 |
| 精细 UI 操作 | Computer Use 兜底 | 全靠截图 | 浏览器内 | 不支持 |
| Agent 异步通知 | ✅ 智能调度 | ❌ | ❌ | ❌ |
| 用户描述更新窗口 | ✅ | ❌ | ❌ | ❌ |
