# Vista Voice — Context Manager 设计文档

> 本文档是 [PRD](./PRD.md) 第 3 章和第 5.4 节的详细技术设计。阅读前建议先了解 PRD 中的产品架构和 Context 概述。

## 1. 设计目标

Context Manager 是 Vista Voice 的核心模块。它的职责是：**让 AI 在任意时刻都能理解用户当前的桌面状态、正在做的事、以及历史上下文**，从而做出最优决策。

好的 Context = AI 不需要你解释"哪个窗口"、"刚才那个"、"帮我继续"是什么意思。

---

## 2. Context 数据模型

### 2.1 完整结构

```typescript
interface DesktopContext {
  // ═══════════════════════════════════════════
  // Layer 1: 桌面物理状态（实时、结构化、零成本）
  // 数据源: yabai query
  // ═══════════════════════════════════════════
  desktop: {
    displays: Display[]          // 显示器列表（index, frame, spaces）
    spaces: Space[]              // 所有 Space（index, display, windows, focused, visible）
    windows: Window[]            // 所有窗口
    focusedWindow: Window | null // 当前聚焦窗口
    focusedSpace: Space          // 当前聚焦 Space
    focusedDisplay: Display      // 当前聚焦显示器
  }

  // ═══════════════════════════════════════════
  // Layer 2: 视觉状态（按需、高成本）
  // 数据源: screencapture + 多模态模型
  // ═══════════════════════════════════════════
  visual: {
    screenshot?: {
      image: Buffer              // 当前屏幕截图
      timestamp: Date
      display: number            // 哪个显示器
    }
    sceneDescription?: string    // AI 对屏幕内容的自然语言描述
    uiElements?: UIElement[]     // 识别出的 UI 元素（按钮、输入框等）
  }

  // ═══════════════════════════════════════════
  // Layer 3: 对话与操作历史（累积）
  // 数据源: 自身记录
  // ═══════════════════════════════════════════
  history: {
    turns: ConversationTurn[]    // 对话轮次（用户说+AI做+结果）
    recentOperations: Operation[] // 最近 N 次桌面操作
    referenceStack: Reference[]  // "这个"、"那个"、"刚才的" 指代栈
  }

  // ═══════════════════════════════════════════
  // Layer 4: 用户意图与任务（AI 推断）
  // 数据源: LLM 根据 Layer 1-3 推断
  // ═══════════════════════════════════════════
  intent: {
    currentTask?: string         // 用户当前在做什么（"在写 React 组件"）
    currentGoal?: string         // 更高层目标（"完成登录功能"）
    expectedNextAction?: string  // 预判下一步（"可能要测试"）
    userState: "active" | "waiting" | "idle" | "away"
  }

  // ═══════════════════════════════════════════
  // Layer 5: Agent 状态（事件驱动）
  // 数据源: Agent stdout/event
  // ═══════════════════════════════════════════
  agents: {
    active: AgentState[]         // 正在运行的 agent
    completed: AgentResult[]     // 最近完成的任务（待通知/已通知）
    pendingNotifications: Notification[] // 等待合适时机播报的通知
  }

  // ═══════════════════════════════════════════
  // Layer 6: 环境与配置
  // ═══════════════════════════════════════════
  environment: {
    sessionStart: Date
    lastInteraction: Date
    idleDuration: number         // 秒
    timeOfDay: string            // "morning" | "afternoon" | "evening" | "night"
    runningApps: string[]        // 所有运行中的应用
  }
}
```

### 2.2 子类型定义

```typescript
interface Window {
  id: number
  app: string                    // "Visual Studio Code"
  title: string                  // "App.tsx — myproject"
  space: number
  display: number
  focused: boolean
  visible: boolean
  minimized: boolean
  frame: { x, y, w, h }
  hasAXReference: boolean
  
  // ═══ AI 维护的语义描述 ═══
  description: string            // AI 对这个窗口"在干什么"的理解
                                 // 示例: "用户在写登录表单的验证逻辑"
                                 // 示例: "React useEffect 文档页"
                                 // 示例: "跑着 dev server (localhost:3000)"
  tags: string[]                 // 语义标签，辅助匹配
                                 // 示例: ["coding", "react", "login"]
                                 // 示例: ["docs", "reference", "react"]
                                 // 示例: ["terminal", "server", "running"]
  lastActivity?: string          // 上次在这个窗口做了什么
                                 // 示例: "2分钟前修改了 handleSubmit 函数"
  userLabel?: string             // 用户主动给的标签（"我的文档窗口"）
}

interface ConversationTurn {
  timestamp: Date
  userInput: string              // 用户说的原文
  aiDecision: {
    intent: string               // AI 理解的意图
    executionPath: string        // "yabai" | "computer_use" | "agent" | "chat"
    toolCalls: ToolCall[]        // 实际调用了什么
  }
  result: {
    success: boolean
    message: string              // 给用户的反馈
    sideEffects: string[]        // 产生了什么变化
  }
}

interface Operation {
  timestamp: Date
  type: string                   // "focus_window" | "move_window" | "run_command" ...
  target: string                 // "Terminal" | "space 3" | ...
  success: boolean
}

interface Reference {
  pronoun: string                // "这个" | "那个" | "刚才的"
  resolvedTo: {
    type: "window" | "app" | "space" | "file" | "command"
    value: any                   // 具体指向的对象
  }
  timestamp: Date
}

interface AgentState {
  id: string
  type: string                   // "coding" | "search" | "build"
  task: string                   // "修复 login 页面的 bug"
  startedAt: Date
  lastOutput: string             // 最近一行输出
  progress?: number              // 0-100 如果可估计
  status: "running" | "waiting_input" | "done" | "error"
}

interface Notification {
  id: string
  source: string                 // "agent" | "build" | "system"
  priority: "high" | "normal" | "low"
  message: string
  createdAt: Date
  deliveredAt?: Date
  shouldInterrupt: boolean       // 是否应该打断用户当前操作
}

interface UIElement {
  type: "button" | "input" | "link" | "menu" | "text" | "other"
  label: string
  bounds: { x, y, w, h }        // 屏幕坐标
  confidence: number             // 识别置信度
}
```

### 2.3 窗口描述（Window Description）生命周期

窗口的 `description` 是 AI 维护的语义字段，不是静态数据。它随着用户行为动态演化。

#### 描述来源（从哪来）

| 来源 | 触发时机 | 示例 |
|------|---------|------|
| **App + Title 推断** | 窗口首次出现时 | title "React Docs - Chrome" → "React 文档页面" |
| **用户操作推断** | 用户在该窗口操作后 | 用户在 VS Code 里让 agent 改 login → "在开发登录功能" |
| **用户主动描述** | 用户提到该窗口时 | "那个查文档的" → 该窗口被标记为 "查文档用的" |
| **截图理解** | Computer Use 截过该窗口时 | 截图看到 Figma 画布 → "登录页 UI 设计稿" |
| **Agent 回报** | Agent 在该窗口相关文件工作时 | Agent 改了 LoginForm.tsx → VS Code 描述更新 |

#### 描述更新规则

```typescript
// AI 在每次交互后可以选择更新窗口描述
interface WindowDescriptionUpdate {
  windowId: number
  newDescription?: string    // 覆盖描述
  addTags?: string[]         // 追加标签
  removeTags?: string[]      // 移除标签
  lastActivity?: string      // 更新最后活动
}

// 触发更新的时机:
// 1. 用户 focus 到一个窗口时 → 根据上下文更新 description
// 2. 用户用自然语言指代窗口时 → 将用户的描述融入 description
// 3. Agent 完成任务涉及某窗口时 → 更新 lastActivity
// 4. 窗口 title 变化时 → 重新推断 description
```

#### 示例：描述的演化过程

```
时间线:

T0: Chrome 窗口出现, title = "Google"
    → description: "Google 搜索页面"
    → tags: ["browser", "search"]

T1: 用户说 "帮我查一下 React useEffect"
    AI 在这个 Chrome 里打开了文档
    → description: "React useEffect 文档（用户在查 hook 用法）"
    → tags: ["browser", "docs", "react", "reference"]

T2: 用户说 "切到我查文档那个窗口"
    AI 匹配: "查文档" ∈ description → 找到这个 Chrome
    → userLabel: "查文档的窗口" (用户的叫法被记住)

T3: 用户在 VS Code 写代码，提到 "参考刚才查的 useEffect"
    AI 知道: referenceStack 中 "查的" 指向那个 Chrome
    → 无需更新描述，但强化了关联
```

#### 描述用于窗口匹配

当用户说模糊的话时，AI 用 description + tags 做语义匹配：

| 用户说 | 匹配逻辑 |
|--------|---------|
| "切到写代码的" | 匹配 tags 含 "coding" 或 description 含 "写/开发" |
| "那个文档" | 匹配 tags 含 "docs" 或 description 含 "文档" |
| "跑 server 的终端" | 匹配 description 含 "server" 且 app == "Terminal" |
| "我的设计稿" | 匹配 description 含 "设计" 或 userLabel 含 "设计" |
| "刚才让 agent 改的那个" | 匹配 lastActivity 含 "agent" |

#### AI 主动更新描述的 tool

```json
{
  "name": "update_window_description",
  "description": "更新窗口的语义描述。在以下情况调用：1)用户的话暗示了某窗口的用途 2)操作改变了窗口内容 3)窗口title变了需要重新理解",
  "parameters": {
    "window_id": "number",
    "description": "string (一句话描述这个窗口在干什么)",
    "tags": "string[] (语义标签)",
    "last_activity": "string (optional, 最近做了什么)"
  }
}
```

**关键设计：这个 tool 是 AI 自主调用的，不需要用户触发。** AI 在每次交互中如果获得了关于某窗口的新信息，就会顺手更新。

---

## 3. Context 更新策略

### 3.1 分层更新

| Layer | 触发时机 | 更新成本 | 策略 |
|-------|---------|---------|------|
| L1 桌面状态 | 每次用户指令前 + 3s 轮询 | 极低（<10ms） | 始终保持最新 |
| L2 视觉状态 | 按需（用户提到屏幕内容时） | 高（截图+推理 1-3s） | 懒加载 + 缓存 |
| L3 对话历史 | 每次交互后 | 低 | 滑动窗口（保留最近 50 轮） |
| L4 用户意图 | 每 5 次交互或任务切换时 | 中（LLM 推断） | 定期刷新 |
| L5 Agent 状态 | 事件驱动 | 低 | 实时 |
| L6 环境 | 每次交互时顺带更新 | 极低 | 被动 |

### 3.2 更新时序图

```
用户说 "切到刚才那个"
         │
         ▼
┌─── Context 刷新 ───────────────────────────────┐
│                                                 │
│  1. [L1] yabai query → 获取最新窗口列表 (5ms)   │
│  2. [L3] 查 referenceStack → "刚才" = 上一个    │
│          focusedWindow 变更记录                  │
│  3. [L6] 更新 lastInteraction                   │
│                                                 │
└─── Context ready ──────────────────────────────┘
         │
         ▼
┌─── LLM 决策 ──────────────────────────────────┐
│                                                 │
│  Input: "切到刚才那个"                           │
│  Context 关键信息:                               │
│    - 刚才的窗口: Chrome (id:1234, space:2)      │
│    - 当前窗口: VS Code (id:5678, space:1)       │
│                                                 │
│  Output: yabai.focusSpace(2) + focusWindow(1234)│
│                                                 │
└────────────────────────────────────────────────┘
         │
         ▼
┌─── Context 更新 ───────────────────────────────┐
│                                                 │
│  1. [L3] 记录本次操作 → referenceStack push     │
│  2. [L3] 记录 ConversationTurn                  │
│  3. [L1] 更新 focusedWindow                     │
│                                                 │
└────────────────────────────────────────────────┘
```

### 3.3 视觉 Context 触发条件

L2（截图+视觉理解）是高成本操作，只在以下情况触发：

| 触发条件 | 示例 |
|---------|------|
| 用户明确问屏幕内容 | "屏幕上写了什么"、"这个按钮在哪" |
| 操作需要视觉定位 | "点那个红色的按钮" |
| Computer Use 执行前 | 需要截图才能操作 |
| 用户指代不明确且 L1 无法解析 | "关掉那个弹窗"（弹窗可能不在 yabai window list 中） |
| 定期场景感知（可选） | 每 30s 轻量截图，检测屏幕是否有重大变化 |

**不触发的情况：**
- 简单窗口切换
- Space 操作
- 终端命令执行
- Agent 对话

---

## 4. Context 压缩与传递给 LLM

### 4.1 问题

Context 可能很大（几十个窗口、几十轮对话），但每次 LLM 调用的 token 有限且影响速度。

### 4.2 策略：分级 Context 注入

```
┌───────────────────────────────────────────────────────┐
│ System Prompt (固定)                                    │
│ • 你是桌面操控 AI，可用工具: yabai/computer_use/agent  │
│ • 输出格式规范                                         │
│ • 行为准则                                             │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ Always Context (每次都带，<500 tokens)                   │
│ • 当前聚焦: {app} - {title} (space {n}, display {n})  │
│ • 运行中应用: [列表，去重]                              │
│ • 用户当前任务: {currentTask}                           │
│ • 用户状态: {active/waiting/idle}                      │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ Recent Context (最近 5 轮对话，<1000 tokens)             │
│ • 对话轮次摘要 (非完整回复)                             │
│ • referenceStack top 3                                 │
└───────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────┐
│ On-Demand Context (按需注入)                            │
│ • 完整窗口列表 (当指令涉及 "哪个"/"所有")              │
│ • 截图 (当需要视觉操作)                                │
│ • Agent 完整状态 (当用户问 agent 进度)                  │
│ • 对话完整历史 (当用户说 "之前我说的...")               │
└───────────────────────────────────────────────────────┘
```

### 4.3 Always Context 模板

```
当前桌面状态:
- 聚焦: Visual Studio Code — "App.tsx — myproject" (桌面1, 左屏)
         描述: 在写登录表单的验证逻辑
- 运行中窗口:
  [1] VS Code — "App.tsx" | 在写登录表单验证 | tags: coding, react, login
  [2] Chrome — "React Docs" | 查 useEffect 文档 | tags: docs, react
  [3] Chrome — "localhost:3000" | 预览开发中的页面 | tags: preview, dev
  [4] Terminal — "zsh" | 跑着 dev server | tags: terminal, server
  [5] Terminal — "zsh" | 刚跑了 npm test (3个失败) | tags: terminal, test
  [6] Feishu — "工作群" | 未读消息 | tags: chat
  [7] Finder — "Downloads" | (无特殊活动) | tags: files

用户状态: 活跃 | 任务: 开发 React 登录组件 | 上次交互: 30s前
Agent: coding-agent 正在运行 (修复登录bug, 已2分钟)

最近操作:
1. [1分钟前] 切到 VS Code
2. [3分钟前] 在终端[5]跑了 npm test
3. [5分钟前] 让 agent 修 login bug
```

### 4.4 Reference 解析规则

| 用户说 | 解析逻辑 | Context 依赖 |
|--------|---------|-------------|
| "这个" / "当前" | focusedWindow | L1 |
| "那个" / "刚才那个" | referenceStack[-1] 或上一个 focused | L3 |
| "上一个" | referenceStack[-1] | L3 |
| "它" | 上一轮提到的对象 | L3 conversationTurn |
| "再来一次" | 上一轮的操作 | L3 recentOperations[-1] |
| "继续" | 当前任务的下一步 | L4 intent |
| "所有 Chrome" | windows.filter(app == "Chrome") | L1 |
| "左边的" | 指 left display 的窗口 | L1 display |
| "第三个桌面" | spaces[index: 3] | L1 |

---

## 5. Context 与三种执行路径的配合

### 5.1 yabai 路径（结构化操作）

```
Context 提供:
  - 完整窗口列表 (id, app, title, space, display)
  - 当前焦点

AI 输出:
  - tool_call: yabai.focus_window(id=1234)
  - tool_call: yabai.move_window(id=1234, display=2)

Context 特殊能力:
  - 模糊匹配 "编辑器" → 从窗口列表中找 "Visual Studio Code"
  - 解析 "上一个" → 从 referenceStack 拿 window id
  - 智能选择 → 多个 Chrome 窗口时，选当前显示器上的那个
```

### 5.2 Computer Use 路径（视觉操作）

```
Context 提供:
  - 截图（触发截取）
  - 已知窗口位置 (frame) → 可以只截目标窗口区域
  - UI 元素缓存（如果之前识别过）

AI 输出:
  - tool_call: computer_use.screenshot(region={focused_window.frame})
  - tool_call: computer_use.click(x=450, y=320)
  - tool_call: computer_use.type("hello")

Context 加速:
  - 已知窗口 frame → 缩小截图范围 → 减少推理时间
  - 已知 app 类型 → 预测 UI 布局 → 提高定位准确度
  - 操作后自动更新 L1（yabai re-query）验证结果
```

### 5.3 Agent 路径（异步委派）

```
Context 提供:
  - 当前项目/文件信息（从 VS Code title 推断）
  - 用户意图完整描述（多轮对话汇总）
  - Agent 之前的工作历史

AI 输出:
  - tool_call: agent.delegate(task="修复 login 页面表单验证", context={...})

Context 持续更新:
  - 监听 agent stdout → 更新 agents.active[].lastOutput
  - 检测完成 → 移到 agents.completed
  - 决定通知时机（用户 idle 时立即播报 vs 用户忙时等一等）
```

---

## 6. 通知智能调度

### 6.1 打断策略

不是所有通知都应该立即播报。AI 根据 Context 判断时机：

```typescript
function shouldInterruptNow(notification: Notification, context: DesktopContext): boolean {
  // 高优先级 + 用户在等 → 立即打断
  if (notification.priority === "high" && context.intent.userState === "waiting") {
    return true
  }
  
  // 用户空闲超过 5 秒 → 可以打断
  if (context.environment.idleDuration > 5) {
    return true
  }
  
  // 用户正在打字/操作 → 等一等
  if (context.intent.userState === "active" && notification.priority !== "high") {
    return false  // 加入 pendingNotifications
  }
  
  // 错误/失败 → 总是立即
  if (notification.source === "build" && notification.message.includes("失败")) {
    return true
  }
  
  return false
}
```

### 6.2 通知合并

```
Agent 完成 + 构建成功 → 合并为: "Agent 改完了，构建也通过了，改了 3 个文件"
而不是分两次播报。
```

### 6.3 通知摘要

长消息自动摘要：
- Agent 输出 200 行 → 摘要为 "改了 LoginForm 和 validators，加了邮箱验证"
- 构建日志 → "构建成功，耗时 8 秒" 或 "第 42 行类型错误"

---

## 7. Context 持久化

### 7.1 Session vs Persistent

| 数据 | 生命周期 | 存储 |
|------|---------|------|
| 窗口/桌面状态 | 实时（不持久化） | 内存 |
| 对话历史 | Session 内 | 内存，可选写磁盘 |
| 用户任务推断 | 跨 Session | 本地文件/SQLite |
| App 别名/偏好 | 永久 | 配置文件 |
| 操作模式 | 学习积累 | 本地文件 |

### 7.2 跨 Session 恢复

用户重新启动 Vista Voice 时：
1. 读取持久化的用户偏好和别名
2. 通过 yabai query 重建 L1
3. 读取上次 session 的任务摘要："上次你在做 React 登录功能"
4. 检查是否有未处理的 Agent 结果

---

## 8. Agent 沟通哲学：对话是工具，不是义务

### 8.1 核心原则

**主 Agent 是一个自主决策者，"和用户说话"只是它的工具之一。**

传统助手：用户输入 → 处理 → **必须输出回复**
Vista Voice：用户输入 → AI 自主决策 → **可能沉默执行，也可能对话**

```
主 Agent 的完整工具箱:
  │
  ├── 感知工具（获取信息）
  │   ├── yabai_query        → 查询桌面状态
  │   ├── screenshot         → 截图看屏幕
  │   └── listen()           → 主动追问用户（需要更多信息时）
  │
  ├── 操作工具（改变世界）
  │   ├── yabai_action       → 窗口操作（沉默，极快）
  │   ├── computer_use       → 视觉操作（沉默，较慢）
  │   ├── terminal_run       → 终端命令（沉默）
  │   └── agent_delegate     → 委派子任务（沉默）
  │
  └── 沟通工具（对话是可选的）
      ├── speak(text)        → 对用户说话
      └── ask(question)      → 追问用户并等待回答
```

### 8.2 什么时候 AI 选择不说话

| 场景 | AI 行为 | 原因 |
|------|---------|------|
| "切到终端" | 直接切，不说话 | 结果不言自明 |
| "关掉这个" | 直接关，不说话 | 同上 |
| "跑 npm start" | 切终端+执行，不说话 | 用户能看到 |
| "移到左屏" | 直接移，不说话 | 视觉反馈已经够了 |

### 8.3 什么时候 AI 选择说话

| 场景 | AI 行为 | 原因 |
|------|---------|------|
| 歧义 | ask("找到 3 个 Chrome，你要哪个？") | 需要用户决策 |
| 失败 | speak("Terminal 没开，帮你开了") | 意外情况需告知 |
| 异步完成 | speak("Agent 改完了，3 个文件") | 用户看不到 |
| 主动通知 | speak("构建失败了") | 重要事件 |
| 用户明确对话 | speak("...回答...") | 用户在问问题 |
| 确认危险操作 | ask("要删除这 5 个窗口吗？") | 不可逆操作 |

### 8.4 AI 的沟通决策树

```
用户指令进来
    │
    ├─ 意图明确 + 操作无风险 + 结果可见？
    │   └─ YES → 直接执行，不说话
    │
    ├─ 意图不明确？
    │   └─ ask() 追问
    │
    ├─ 操作失败 / 意外情况？
    │   └─ speak() 告知
    │
    ├─ 操作成功但结果不可见（异步/后台）？
    │   └─ speak() 简短确认（"交给 agent 了"）
    │
    └─ 用户在问问题（非操作指令）？
        └─ speak() 回答
```

### 8.5 speak() 的设计约束

```
speak() 规则:
  - 能不说就不说
  - 说就说最短的（"好了" 而非 "好的，我已经帮你切换到终端了"）
  - 失败比成功更值得说
  - 永远不要说 "好的"、"收到"、"明白" 这类废话
  - 如果操作结果用户能直接看到，不需要 speak
```

> System Prompt 的完整文本见 [PRD](./PRD.md) 第 5.3 节。本章内容是 prompt 背后的设计逻辑和决策依据。

---

## 9. 工具定义（完整 Schema）

```json
{
  "tools": [
    {
      "name": "yabai_query",
      "description": "查询当前桌面状态（窗口、Space、显示器）",
      "parameters": {
        "target": "windows | spaces | displays"
      }
    },
    {
      "name": "yabai_action",
      "description": "执行窗口管理操作（速度极快<10ms）",
      "parameters": {
        "action": "focus_window | focus_space | move_to_display | move_to_space | close | fullscreen",
        "window_id": "number (optional)",
        "target": "number (optional, space/display index)"
      }
    },
    {
      "name": "computer_use_screenshot",
      "description": "截取屏幕或窗口区域",
      "parameters": {
        "region": "full | focused_window | {x,y,w,h}"
      }
    },
    {
      "name": "computer_use_action",
      "description": "视觉定位后执行点击/输入（延迟2-5s）",
      "parameters": {
        "action": "click | type | scroll | drag",
        "x": "number",
        "y": "number",
        "text": "string (for type)"
      }
    },
    {
      "name": "terminal_run",
      "description": "在终端执行命令",
      "parameters": {
        "command": "string",
        "new_tab": "boolean"
      }
    },
    {
      "name": "agent_delegate",
      "description": "委派异步任务给 coding/search agent",
      "parameters": {
        "task": "string",
        "type": "coding | search | build",
        "context": "string (相关上下文)"
      }
    },
    {
      "name": "speak",
      "description": "对用户说话（TTS）",
      "parameters": {
        "text": "string"
      }
    }
  ]
}
```

> 工具的使用原则和 LLM System Prompt 见 [PRD](./PRD.md) 第 5.3 节。

---

## 10. 性能预算

| 操作类型 | 目标延迟 | 瓶颈 |
|---------|---------|------|
| 窗口切换 | < 1s（ASR 500ms + LLM 300ms + yabai 10ms） | LLM |
| UI 点击 | < 4s（ASR 500ms + LLM 300ms + 截图 200ms + 推理 2s + 点击 10ms） | 视觉推理 |
| Agent 委派 | < 1.5s（到用户听到"交给 agent 了"） | LLM |
| Context 刷新 | < 50ms | yabai query |
| 通知播报 | < 500ms（从事件到开始说话） | TTS |

### 10.1 优化手段

1. **yabai 状态预加载** — 后台 3s 轮询，指令来时直接用缓存
2. **LLM 流式输出** — 不等完整响应，拿到第一个 tool call 就执行
3. **截图区域限制** — 只截目标窗口区域而非全屏
4. **高频指令快速路径** — "切到 X"这类模式固定的指令，LLM 几乎零思考
5. **Context 差量更新** — 只传变化部分，不重复传整个状态

---

## 11. 实现优先级

### Phase 1（MVP）

- [x] L1: yabai 桌面状态查询
- [ ] L3: 对话历史（内存，最近 20 轮）
- [ ] L3: referenceStack（"刚才"/"这个" 解析）
- [ ] Always Context 模板生成
- [ ] Tool calling 基础框架

### Phase 2

- [ ] L2: 按需截图 + 视觉理解
- [ ] L4: 用户任务推断
- [ ] L5: Agent 状态追踪 + 智能通知
- [ ] Context 压缩策略优化
- [ ] 通知合并与摘要

### Phase 3

- [ ] L6: 跨 Session 持久化
- [ ] 用户行为模式学习
- [ ] 定期场景感知（主动截图）
- [ ] 自适应 Context 窗口大小
