# Vista Voice — Phase 1 实施方案

## 概览

本文档是 Phase 1 的详细开发方案，覆盖 5 周开发周期，目标是交付完整的语音桌面操控 + 桌面宠物 + 手势指向的端到端体验。

### 开发时间线

```
Week 1: vista-cmd CLI 完善 + 宠物窗口
Week 2: vista-agent 核心（ASR + LLM + Tool Calling）
Week 3: Context Manager
Week 4: Agent 委派 + 主动通知
Week 5: 手势检测 + 端到端联调
```

### 依赖关系图

```
Week 1                  Week 2                 Week 3              Week 4              Week 5
┌──────────┐       ┌──────────────┐       ┌───────────┐      ┌───────────┐      ┌───────────┐
│vista-cmd │──────▶│ vista-agent  │──────▶│  Context  │─────▶│  Agent    │─────▶│  手势 +   │
│  CLI     │       │  核心        │       │  Manager  │      │  委派     │      │  联调     │
└──────────┘       └──────────────┘       └───────────┘      └───────────┘      └───────────┘
      │                   ▲                      │                  │                   │
      ▼                   │                      ▼                  ▼                   ▼
┌──────────┐              │               ┌───────────┐      ┌───────────┐      ┌───────────┐
│ 宠物窗口 │──────────────┘               │ 窗口描述  │      │ 通知调度  │      │ Vision    │
│ (Swift)  │                              │ 自动生成  │      │           │      │ 手势检测  │
└──────────┘                              └───────────┘      └───────────┘      └───────────┘
```

---

## Week 1: vista-cmd CLI 完善 + 宠物窗口

### 1.1 vista-cmd CLI 补全

#### 文件结构

```
CLI/
├── main.swift                    # 已有，入口
Sources/Services/
├── YabaiService.swift            # 已有，补全缺失命令
├── YabaiModels.swift             # 已有
Sources/Features/
├── Pet/
│   ├── PetWindow.swift           # 宠物透明窗口
│   ├── PetViewController.swift   # 宠物视图控制
│   ├── PopupBubble.swift         # popup 气泡组件
│   └── PetStateIndicator.swift   # 状态指示器
```

#### 补全的 CLI 命令

当前 `vista-cmd` 需要支持以下命令供 vista-agent 调用：

```swift
// CLI 命令注册（main.swift 中扩展）
enum Command: String {
    // 查询类
    case query          // vista-cmd query windows|spaces|displays
    case focused        // vista-cmd focused → 当前窗口 JSON
    
    // 操作类
    case focus          // vista-cmd focus <app>
    case space          // vista-cmd space <index>
    case move           // vista-cmd move <left|right|display_id>
    case close          // vista-cmd close
    case fullscreen     // vista-cmd fullscreen
    case run            // vista-cmd run <command>
    case open           // vista-cmd open <url|app>
    
    // 宠物类
    case popup          // vista-cmd popup <text> [--duration 1.5]
    case petState       // vista-cmd pet-state <listening|thinking|acting|idle>
}
```

#### 关键接口

```swift
// YabaiService.swift 补全
extension YabaiService {
    /// 查询所有窗口完整信息（含 space/display）
    func queryWindows() -> [YabaiWindow]
    
    /// 查询所有 display
    func queryDisplays() -> [YabaiDisplay]
    
    /// 移动窗口到指定 display
    func moveToDisplay(_ displayId: Int) throws
    
    /// 移动窗口到指定 space
    func moveToSpace(_ spaceIndex: Int) throws
}

// 新增 YabaiDisplay 模型
struct YabaiDisplay: Codable {
    let id: Int
    let uuid: String
    let index: Int
    let frame: CGRect
    let spaces: [Int]
}
```

#### 依赖

- 无新依赖，纯 Swift，已有 yabai socket 通信

#### 验收标准

- [ ] `vista-cmd query windows` 返回完整 JSON（含 app/title/space/display/frame）
- [ ] `vista-cmd query displays` 返回显示器列表
- [ ] `vista-cmd move <display_id>` 成功移动窗口
- [ ] `vista-cmd popup "hello"` 在宠物窗口显示气泡
- [ ] `vista-cmd pet-state thinking` 切换状态指示

#### 预计工作量：2 天

---

### 1.2 桌面宠物窗口（Swift）

#### 实现方案

宠物是一个 **透明无边框、always-on-top 的 NSWindow**，悬浮在屏幕右下角，作为 popup 气泡和状态指示的载体。

#### 关键代码骨架

```swift
// PetWindow.swift
import AppKit

class PetWindow: NSWindow {
    
    private let stateIndicator = PetStateIndicator()
    private let popupBubble = PopupBubble()
    
    init() {
        // 窗口尺寸：48x48 常态，气泡展开时动态扩展
        let frame = NSRect(x: 0, y: 0, width: 48, height: 48)
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        // 透明 + always on top
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating           // always on top
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.hasShadow = false
        self.ignoresMouseEvents = false  // 允许拖拽移动
        
        // 定位：主屏右下角
        positionAtBottomRight()
        
        setupContentView()
    }
    
    private func positionAtBottomRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 20
        let y = screenFrame.minY + 20
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func setupContentView() {
        let hostView = NSHostingView(rootView: PetContentView(
            stateIndicator: stateIndicator,
            popupBubble: popupBubble
        ))
        contentView = hostView
    }
    
    // MARK: - Public API
    
    func showPopup(_ text: String, duration: TimeInterval = 1.5) {
        popupBubble.show(text: text, duration: duration)
    }
    
    func setState(_ state: PetState) {
        stateIndicator.state = state
    }
}

enum PetState: String {
    case idle = "idle"           // 无指示
    case listening = "listening" // 🎤 听
    case thinking = "thinking"   // 🤔 想
    case acting = "acting"       // ⚡ 做
}
```

```swift
// PopupBubble.swift
import SwiftUI

class PopupBubble: ObservableObject {
    @Published var text: String = ""
    @Published var isVisible: Bool = false
    
    private var hideTimer: Timer?
    
    func show(text: String, duration: TimeInterval = 1.5) {
        self.text = text
        self.isVisible = true
        
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            withAnimation(.easeOut(duration: 0.3)) {
                self.isVisible = false
            }
        }
    }
}

struct PopupBubbleView: View {
    @ObservedObject var bubble: PopupBubble
    
    var body: some View {
        if bubble.isVisible {
            Text(bubble.text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.75))
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}
```

```swift
// PetStateIndicator.swift
import SwiftUI

class PetStateIndicator: ObservableObject {
    @Published var state: PetState = .idle
    
    var emoji: String {
        switch state {
        case .idle: return ""
        case .listening: return "🎤"
        case .thinking: return "🤔"
        case .acting: return "⚡"
        }
    }
}

struct PetStateView: View {
    @ObservedObject var indicator: PetStateIndicator
    
    var body: some View {
        ZStack {
            // 小圆点底色
            Circle()
                .fill(stateColor)
                .frame(width: 32, height: 32)
            
            if !indicator.emoji.isEmpty {
                Text(indicator.emoji)
                    .font(.system(size: 16))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: indicator.state)
    }
    
    private var stateColor: Color {
        switch indicator.state {
        case .idle: return .gray.opacity(0.3)
        case .listening: return .green.opacity(0.6)
        case .thinking: return .orange.opacity(0.6)
        case .acting: return .blue.opacity(0.6)
        }
    }
}
```

#### 依赖

- SwiftUI（macOS 13+）
- 无第三方依赖

#### 验收标准

- [ ] 透明小窗口出现在屏幕右下角
- [ ] 不遮挡 Dock，不在 app switcher 中出现
- [ ] `popup("→ Terminal")` 气泡出现 1.5s 后自动消失
- [ ] 状态指示正确显示 🎤/🤔/⚡
- [ ] 可拖拽移动位置
- [ ] 不影响其他窗口的鼠标事件

#### 预计工作量：3 天

---

## Week 2: vista-agent 核心（ASR + LLM + Tool Calling）

### 2.1 项目结构

```
agent/
├── vista_agent.py              # 已有，需重构
├── requirements.txt            # 已有，需更新
├── setup.sh                    # 已有
├── src/
│   ├── __init__.py
│   ├── config.py               # 配置管理
│   ├── asr/
│   │   ├── __init__.py
│   │   ├── whisper_engine.py   # faster-whisper 封装
│   │   └── vad.py             # 语音活动检测
│   ├── llm/
│   │   ├── __init__.py
│   │   ├── doubao_client.py   # 豆包 API 客户端
│   │   ├── tools.py           # Tool 定义
│   │   └── prompts.py         # System Prompt
│   ├── tools/
│   │   ├── __init__.py
│   │   ├── router.py          # Tool Router
│   │   ├── yabai.py           # yabai_query/action → vista-cmd
│   │   ├── terminal.py        # terminal_run
│   │   ├── speech.py          # speak/ask
│   │   ├── popup.py           # show_popup → vista-cmd popup
│   │   └── gesture.py         # gesture_direction（Week 5 实现）
│   ├── tts/
│   │   ├── __init__.py
│   │   └── macos_tts.py       # macOS say 命令封装
│   └── main.py                # 新入口
└── tests/
    ├── test_tools.py
    ├── test_llm.py
    └── test_asr.py
```

### 2.2 whisper.cpp / faster-whisper 集成

```python
# src/asr/whisper_engine.py
from faster_whisper import WhisperModel
import numpy as np
from typing import Optional

class WhisperEngine:
    """本地 ASR 引擎，支持中英混合"""
    
    def __init__(self, model_size: str = "small", device: str = "cpu"):
        self.model = WhisperModel(
            model_size, 
            device=device, 
            compute_type="int8"  # Apple Silicon 优化
        )
    
    def transcribe(self, audio_path: str) -> str:
        """转录音频文件，返回文本"""
        segments, info = self.model.transcribe(
            audio_path,
            language=None,          # 自动检测
            beam_size=5,
            vad_filter=True,        # 内置 VAD 过滤
            vad_parameters=dict(
                min_silence_duration_ms=500,
                speech_pad_ms=200
            )
        )
        return "".join(seg.text for seg in segments).strip()
    
    def transcribe_stream(self, audio_chunks: list[np.ndarray]) -> str:
        """流式转录（拼接后一次性识别）"""
        audio = np.concatenate(audio_chunks)
        # 保存为临时文件后转录
        import tempfile, soundfile as sf
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
            sf.write(f.name, audio, 16000)
            return self.transcribe(f.name)
```

### 2.3 豆包 API Tool Calling 对接

```python
# src/llm/doubao_client.py
from openai import OpenAI
from typing import Optional
from .tools import TOOL_DEFINITIONS
from .prompts import SYSTEM_PROMPT

class DoubaoClient:
    """豆包 LLM 客户端，支持 Tool Calling"""
    
    def __init__(self, api_key: str, model: str, base_url: str):
        self.client = OpenAI(api_key=api_key, base_url=base_url)
        self.model = model
    
    def chat_with_tools(
        self, 
        messages: list[dict],
        context: str,           # Always Context 注入
        tools: list[dict] = None
    ) -> dict:
        """
        发送消息并获取 tool calling 响应
        
        Returns:
            {
                "content": str | None,        # 文本回复（通常为 None）
                "tool_calls": [               # 工具调用列表
                    {"name": str, "arguments": dict}
                ]
            }
        """
        system_msg = {
            "role": "system",
            "content": f"{SYSTEM_PROMPT}\n\n## 当前状态\n{context}"
        }
        
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[system_msg] + messages,
            tools=tools or TOOL_DEFINITIONS,
            tool_choice="auto",
            temperature=0.1,
            max_tokens=500
        )
        
        msg = response.choices[0].message
        result = {"content": msg.content, "tool_calls": []}
        
        if msg.tool_calls:
            for tc in msg.tool_calls:
                result["tool_calls"].append({
                    "id": tc.id,
                    "name": tc.function.name,
                    "arguments": json.loads(tc.function.arguments)
                })
        
        return result
```

### 2.4 Tool 定义

```python
# src/llm/tools.py
import json

TOOL_DEFINITIONS = [
    {
        "type": "function",
        "function": {
            "name": "yabai_query",
            "description": "查询桌面状态：窗口列表、Space列表、显示器列表",
            "parameters": {
                "type": "object",
                "properties": {
                    "target": {
                        "type": "string",
                        "enum": ["windows", "spaces", "displays", "focused"],
                        "description": "查询目标"
                    }
                },
                "required": ["target"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "yabai_action",
            "description": "执行窗口操作：focus切换、move移动、close关闭、fullscreen全屏",
            "parameters": {
                "type": "object",
                "properties": {
                    "action": {
                        "type": "string",
                        "enum": ["focus", "move", "close", "fullscreen", "space"],
                        "description": "操作类型"
                    },
                    "target": {
                        "type": "string",
                        "description": "操作目标（app名/方向/space编号/display_id）"
                    }
                },
                "required": ["action"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "terminal_run",
            "description": "在终端执行命令",
            "parameters": {
                "type": "object",
                "properties": {
                    "command": {
                        "type": "string",
                        "description": "要执行的终端命令"
                    }
                },
                "required": ["command"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "agent_delegate",
            "description": "委派异步任务给 coding agent（编程、搜索、构建等）",
            "parameters": {
                "type": "object",
                "properties": {
                    "task": {
                        "type": "string",
                        "description": "任务描述"
                    },
                    "context": {
                        "type": "string",
                        "description": "相关上下文（文件路径、错误信息等）"
                    }
                },
                "required": ["task"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "show_popup",
            "description": "在桌面宠物气泡中显示文本，轻量确认，1-2秒自动消失",
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "要显示的文本（尽量简短：1-6字）"
                    },
                    "duration": {
                        "type": "number",
                        "description": "显示时长（秒），默认1.5",
                        "default": 1.5
                    }
                },
                "required": ["text"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "speak",
            "description": "对用户说话（TTS），仅在需要用户注意力时使用",
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "要说的内容（简短、直接）"
                    }
                },
                "required": ["text"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "ask",
            "description": "追问用户并等待回答（当意图不明确时）",
            "parameters": {
                "type": "object",
                "properties": {
                    "question": {
                        "type": "string",
                        "description": "追问内容"
                    }
                },
                "required": ["question"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "update_window_description",
            "description": "更新某个窗口的语义描述和标签",
            "parameters": {
                "type": "object",
                "properties": {
                    "window_id": {
                        "type": "integer",
                        "description": "窗口ID"
                    },
                    "description": {
                        "type": "string",
                        "description": "语义描述（如'跑着dev server的终端'）"
                    },
                    "tags": {
                        "type": "array",
                        "items": {"type": "string"},
                        "description": "标签列表"
                    }
                },
                "required": ["window_id"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "gesture_direction",
            "description": "获取用户手势指向的显示器方向，用于'在这里''移到那边'等空间指令",
            "parameters": {
                "type": "object",
                "properties": {},
                "required": []
            }
        }
    }
]
```

### 2.5 Tool Router 实现

```python
# src/tools/router.py
import subprocess
import json
from typing import Any

class ToolRouter:
    """将 LLM tool_call 路由到具体执行"""
    
    def __init__(self, vista_cmd_path: str):
        self.vista_cmd = vista_cmd_path
        self.handlers = {
            "yabai_query": self._handle_yabai_query,
            "yabai_action": self._handle_yabai_action,
            "terminal_run": self._handle_terminal_run,
            "agent_delegate": self._handle_agent_delegate,
            "show_popup": self._handle_show_popup,
            "speak": self._handle_speak,
            "ask": self._handle_ask,
            "update_window_description": self._handle_update_description,
            "gesture_direction": self._handle_gesture_direction,
        }
    
    def execute(self, tool_name: str, arguments: dict) -> dict:
        """执行工具调用，返回结果"""
        handler = self.handlers.get(tool_name)
        if not handler:
            return {"success": False, "error": f"Unknown tool: {tool_name}"}
        return handler(arguments)
    
    def _run_cmd(self, args: list[str]) -> dict:
        """调用 vista-cmd subprocess"""
        try:
            result = subprocess.run(
                [self.vista_cmd] + args,
                capture_output=True, text=True, timeout=5
            )
            if result.stdout.strip():
                try:
                    return json.loads(result.stdout.strip())
                except json.JSONDecodeError:
                    return {"success": result.returncode == 0, "output": result.stdout.strip()}
            return {"success": result.returncode == 0, "output": result.stderr.strip() or "done"}
        except subprocess.TimeoutExpired:
            return {"success": False, "error": "timeout"}
    
    def _handle_yabai_query(self, args: dict) -> dict:
        return self._run_cmd(["query", args["target"]])
    
    def _handle_yabai_action(self, args: dict) -> dict:
        cmd = [args["action"]]
        if "target" in args:
            cmd.append(args["target"])
        return self._run_cmd(cmd)
    
    def _handle_terminal_run(self, args: dict) -> dict:
        return self._run_cmd(["run", args["command"]])
    
    def _handle_show_popup(self, args: dict) -> dict:
        cmd = ["popup", args["text"]]
        if "duration" in args:
            cmd += ["--duration", str(args["duration"])]
        return self._run_cmd(cmd)
    
    def _handle_speak(self, args: dict) -> dict:
        subprocess.run(["say", "-r", "200", args["text"]], capture_output=True)
        return {"success": True}
    
    def _handle_ask(self, args: dict) -> dict:
        # TTS 播放问题，然后等待用户语音回答
        subprocess.run(["say", "-r", "200", args["question"]], capture_output=True)
        return {"success": True, "waiting_for_response": True}
    
    def _handle_agent_delegate(self, args: dict) -> dict:
        # Week 4 实现，这里先占位
        return {"success": True, "status": "delegated", "task": args["task"]}
    
    def _handle_update_description(self, args: dict) -> dict:
        # Context Manager 负责存储，这里直接返回成功
        return {"success": True, "window_id": args["window_id"]}
    
    def _handle_gesture_direction(self, args: dict) -> dict:
        # Week 5 实现，这里先返回 mock
        return {"success": True, "display": None, "direction": None}
```

### 2.6 依赖

```
# requirements.txt (更新)
faster-whisper>=1.0.0
pyaudio>=0.2.14
openai>=1.12.0
numpy>=1.24.0
soundfile>=0.12.0
```

#### 系统权限

- 麦克风权限（ASR 录音）
- Accessibility 权限（已有，yabai 需要）

### 2.7 验收标准

- [ ] 录音 → ASR 转录 → 输出文本，延迟 < 500ms（small 模型）
- [ ] 豆包 API tool calling 正确返回工具调用
- [ ] "切到终端" → `yabai_action(focus, Terminal)` 正确执行
- [ ] "跑 npm start" → `terminal_run("npm start")` 正确执行
- [ ] tool 执行后 popup 反馈正确显示
- [ ] 多轮对话 messages 正确传递

### 2.8 预计工作量：5 天

---

## Week 3: Context Manager

### 3.1 文件结构

```
agent/src/context/
├── __init__.py
├── manager.py              # ContextManager 主类
├── models.py               # 数据模型
├── window_description.py   # 窗口描述生成/更新
├── reference_stack.py      # "刚才"/"这个" 解析
├── history.py              # 对话历史管理
└── serializer.py           # Always Context 序列化
```

### 3.2 数据模型

```python
# src/context/models.py
from dataclasses import dataclass, field
from typing import Optional
from datetime import datetime

@dataclass
class WindowInfo:
    """窗口信息（结构化 + 语义）"""
    window_id: int
    app: str
    title: str
    space: int
    display: int
    frame: dict                         # {"x", "y", "w", "h"}
    is_focused: bool
    # AI 维护的语义信息
    description: Optional[str] = None   # "跑着 dev server 的终端"
    tags: list[str] = field(default_factory=list)  # ["server", "dev"]
    user_label: Optional[str] = None    # 用户起的名字
    last_active: Optional[datetime] = None

@dataclass
class SpaceInfo:
    index: int
    display: int
    windows: list[int]          # window_id 列表
    is_focused: bool

@dataclass
class DisplayInfo:
    id: int
    index: int
    frame: dict
    spaces: list[int]

@dataclass
class CommandRecord:
    """一次交互记录"""
    timestamp: datetime
    user_text: str              # 用户说的话
    intent: str                 # AI 理解的意图
    tool_calls: list[dict]      # 执行的工具
    result: str                 # 结果摘要
    affected_windows: list[int] # 影响的窗口 ID

@dataclass
class AgentTask:
    """委派的 Agent 任务"""
    task_id: str
    description: str
    status: str                 # "running" | "completed" | "failed"
    started_at: datetime
    completed_at: Optional[datetime] = None
    result: Optional[str] = None

@dataclass
class DesktopContext:
    """完整桌面上下文"""
    windows: list[WindowInfo] = field(default_factory=list)
    spaces: list[SpaceInfo] = field(default_factory=list)
    displays: list[DisplayInfo] = field(default_factory=list)
    focused_window: Optional[WindowInfo] = None
    history: list[CommandRecord] = field(default_factory=list)
    active_agents: list[AgentTask] = field(default_factory=list)
    reference_stack: list[int] = field(default_factory=list)  # 最近操作的 window_id
    session_start: datetime = field(default_factory=datetime.now)
    last_interaction: datetime = field(default_factory=datetime.now)
```

### 3.3 Context Manager 核心

```python
# src/context/manager.py
from datetime import datetime, timedelta
from typing import Optional
from .models import DesktopContext, WindowInfo, CommandRecord
from .window_description import WindowDescriptionEngine
from .reference_stack import ReferenceStack
from .serializer import ContextSerializer

class ContextManager:
    """上下文管理器：持续维护桌面状态"""
    
    MAX_HISTORY = 20
    
    def __init__(self, vista_cmd_path: str):
        self.context = DesktopContext()
        self.vista_cmd_path = vista_cmd_path
        self.description_engine = WindowDescriptionEngine()
        self.reference_stack = ReferenceStack()
        self.serializer = ContextSerializer()
    
    def refresh_desktop_state(self):
        """刷新桌面状态（每次指令前 + 定时轮询）"""
        # 调用 vista-cmd query 获取最新状态
        windows_data = self._query("windows")
        spaces_data = self._query("spaces")
        displays_data = self._query("displays")
        
        # 更新窗口列表，保留已有的 description/tags
        self._merge_windows(windows_data)
        self._update_spaces(spaces_data)
        self._update_displays(displays_data)
        self._update_focus()
    
    def record_command(self, user_text: str, intent: str, 
                       tool_calls: list[dict], result: str,
                       affected_windows: list[int] = None):
        """记录一次交互"""
        record = CommandRecord(
            timestamp=datetime.now(),
            user_text=user_text,
            intent=intent,
            tool_calls=tool_calls,
            result=result,
            affected_windows=affected_windows or []
        )
        self.context.history.append(record)
        
        # 维护历史上限
        if len(self.context.history) > self.MAX_HISTORY:
            self.context.history = self.context.history[-self.MAX_HISTORY:]
        
        # 更新 reference stack
        if affected_windows:
            for wid in affected_windows:
                self.reference_stack.push(wid)
        
        self.context.last_interaction = datetime.now()
    
    def update_window_description(self, window_id: int, 
                                   description: str = None, 
                                   tags: list[str] = None,
                                   user_label: str = None):
        """更新窗口语义描述"""
        for w in self.context.windows:
            if w.window_id == window_id:
                if description:
                    w.description = description
                if tags:
                    w.tags = tags
                if user_label:
                    w.user_label = user_label
                break
    
    def resolve_reference(self, ref: str) -> Optional[WindowInfo]:
        """解析模糊指代：'这个'/'那个'/'刚才的'"""
        if ref in ("这个", "当前", "this"):
            return self.context.focused_window
        elif ref in ("那个", "刚才", "上一个", "last"):
            wid = self.reference_stack.peek_previous()
            return self._find_window(wid) if wid else None
        return None
    
    def get_always_context(self) -> str:
        """生成 Always Context（<500 tokens，每次带给 LLM）"""
        return self.serializer.serialize(self.context)
    
    @property
    def idle_duration(self) -> timedelta:
        """用户空闲时长"""
        return datetime.now() - self.context.last_interaction
    
    def _query(self, target: str) -> list[dict]:
        import subprocess, json
        result = subprocess.run(
            [self.vista_cmd_path, "query", target],
            capture_output=True, text=True, timeout=3
        )
        return json.loads(result.stdout) if result.stdout.strip() else []
    
    def _merge_windows(self, new_data: list[dict]):
        """合并窗口数据，保留已有语义信息"""
        existing = {w.window_id: w for w in self.context.windows}
        updated = []
        for wd in new_data:
            wid = wd["id"]
            if wid in existing:
                w = existing[wid]
                w.title = wd.get("title", w.title)
                w.space = wd.get("space", w.space)
                w.display = wd.get("display", w.display)
                w.frame = wd.get("frame", w.frame)
                w.is_focused = wd.get("has-focus", False)
                updated.append(w)
            else:
                updated.append(WindowInfo(
                    window_id=wid,
                    app=wd.get("app", ""),
                    title=wd.get("title", ""),
                    space=wd.get("space", 0),
                    display=wd.get("display", 0),
                    frame=wd.get("frame", {}),
                    is_focused=wd.get("has-focus", False)
                ))
        self.context.windows = updated
    
    def _find_window(self, window_id: int) -> Optional[WindowInfo]:
        for w in self.context.windows:
            if w.window_id == window_id:
                return w
        return None
```

### 3.4 Always Context 序列化

```python
# src/context/serializer.py
from .models import DesktopContext

class ContextSerializer:
    """将 Context 序列化为 LLM 可读的紧凑文本（<500 tokens）"""
    
    def serialize(self, ctx: DesktopContext) -> str:
        lines = []
        
        # 1. 聚焦窗口
        if ctx.focused_window:
            f = ctx.focused_window
            desc = f.description or f.title
            lines.append(f"[Focus] {f.app}: {desc} (space:{f.space} display:{f.display})")
        
        # 2. 其他窗口（按 space 分组，最多显示 8 个）
        other = [w for w in ctx.windows if not w.is_focused][:8]
        if other:
            lines.append("[Windows]")
            for w in other:
                label = w.user_label or w.description or w.title
                lines.append(f"  • {w.app}: {label} (s:{w.space} d:{w.display})")
        
        # 3. 最近操作（最近 3 条）
        recent = ctx.history[-3:]
        if recent:
            lines.append("[Recent]")
            for r in recent:
                lines.append(f"  • \"{r.user_text}\" → {r.result}")
        
        # 4. Agent 状态
        running = [a for a in ctx.active_agents if a.status == "running"]
        if running:
            lines.append("[Agents]")
            for a in running:
                lines.append(f"  • {a.description} (running)")
        
        # 5. 显示器
        if len(ctx.displays) > 1:
            lines.append(f"[Displays] {len(ctx.displays)}个: " + 
                        ", ".join(f"d{d.index}" for d in ctx.displays))
        
        return "\n".join(lines)
```

### 3.5 窗口描述自动生成

```python
# src/context/window_description.py

class WindowDescriptionEngine:
    """基于窗口 title 变化自动推断描述"""
    
    # 常见 app 的 title 解析规则
    TITLE_PATTERNS = {
        "Terminal": lambda t: f"终端: {t.split('—')[-1].strip()}" if "—" in t else "终端",
        "Visual Studio Code": lambda t: f"编辑器: {t.split('—')[0].strip()}" if "—" in t else "VS Code",
        "Google Chrome": lambda t: t.split(" - Google Chrome")[0] if " - Google Chrome" in t else t,
        "Safari": lambda t: t.split(" — ")[0] if " — " in t else t,
    }
    
    def auto_describe(self, app: str, title: str) -> str:
        """根据 app + title 自动生成描述"""
        parser = self.TITLE_PATTERNS.get(app)
        if parser:
            return parser(title)
        return f"{app}: {title[:30]}"
    
    def should_update(self, old_title: str, new_title: str) -> bool:
        """title 变化是否值得更新描述"""
        if old_title == new_title:
            return False
        # 忽略微小变化（如光标闪烁导致的 title 变化）
        if len(old_title) > 5 and old_title[:5] == new_title[:5]:
            return False
        return True
```

### 3.6 Reference Stack

```python
# src/context/reference_stack.py
from collections import deque

class ReferenceStack:
    """维护最近操作的窗口引用，用于解析 "刚才"/"那个" """
    
    def __init__(self, max_size: int = 10):
        self._stack: deque[int] = deque(maxlen=max_size)
    
    def push(self, window_id: int):
        """推入最近操作的窗口"""
        # 去重：如果已在栈中，移到顶部
        if window_id in self._stack:
            self._stack.remove(window_id)
        self._stack.append(window_id)
    
    def peek_current(self) -> int | None:
        """当前（最近操作的）"""
        return self._stack[-1] if self._stack else None
    
    def peek_previous(self) -> int | None:
        """上一个（倒数第二）"""
        return self._stack[-2] if len(self._stack) >= 2 else None
    
    def recent(self, n: int = 5) -> list[int]:
        """最近 N 个"""
        return list(self._stack)[-n:]
```

### 3.7 依赖

- 无新 Python 依赖（纯数据结构）

### 3.8 验收标准

- [ ] `refresh_desktop_state()` 正确拉取并合并窗口数据
- [ ] 窗口 title 变化时 description 自动更新
- [ ] `resolve_reference("刚才")` 正确返回上一个操作的窗口
- [ ] `get_always_context()` 输出 < 500 tokens
- [ ] 对话历史保持最近 20 轮
- [ ] description/tags 在窗口列表刷新后被保留

### 3.9 预计工作量：4 天

---

## Week 4: Agent 委派 + 主动通知

### 4.1 文件结构

```
agent/src/
├── delegation/
│   ├── __init__.py
│   ├── agent_manager.py      # Agent 生命周期管理
│   ├── pipe_protocol.py      # stdin/stdout 通信协议
│   └── task_tracker.py       # 任务状态追踪
├── notification/
│   ├── __init__.py
│   ├── scheduler.py          # 通知调度器
│   ├── events.py             # 事件类型定义
│   └── strategy.py           # 调度策略（idle检测等）
```

### 4.2 Agent 委派实现

```python
# src/delegation/agent_manager.py
import subprocess
import threading
import json
from typing import Callable, Optional
from datetime import datetime

class AgentManager:
    """管理委派的 Agent 子进程"""
    
    def __init__(self, on_complete: Callable, on_error: Callable):
        self.on_complete = on_complete
        self.on_error = on_error
        self.active_agents: dict[str, subprocess.Popen] = {}
        self._task_counter = 0
    
    def delegate(self, task: str, context: str = "", 
                 agent_cmd: str = "aider") -> str:
        """
        委派任务给 coding agent
        
        Args:
            task: 任务描述
            context: 相关上下文
            agent_cmd: agent 可执行文件（默认 aider）
        
        Returns:
            task_id
        """
        self._task_counter += 1
        task_id = f"task_{self._task_counter}_{int(datetime.now().timestamp())}"
        
        # 构建 agent 输入
        prompt = f"{task}\n\nContext:\n{context}" if context else task
        
        # 启动子进程
        proc = subprocess.Popen(
            [agent_cmd, "--message", prompt],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )
        
        self.active_agents[task_id] = proc
        
        # 异步等待完成
        thread = threading.Thread(
            target=self._wait_for_completion,
            args=(task_id, proc),
            daemon=True
        )
        thread.start()
        
        return task_id
    
    def _wait_for_completion(self, task_id: str, proc: subprocess.Popen):
        """等待 agent 完成"""
        try:
            stdout, stderr = proc.communicate(timeout=300)  # 5分钟超时
            
            if proc.returncode == 0:
                self.on_complete(task_id, stdout.strip())
            else:
                self.on_error(task_id, stderr.strip() or f"exit code {proc.returncode}")
        except subprocess.TimeoutExpired:
            proc.kill()
            self.on_error(task_id, "timeout (5min)")
        finally:
            self.active_agents.pop(task_id, None)
    
    def get_status(self, task_id: str) -> str:
        """查询任务状态"""
        if task_id in self.active_agents:
            return "running"
        return "unknown"
```

### 4.3 通知调度策略

```python
# src/notification/scheduler.py
from datetime import datetime, timedelta
from typing import Optional
from dataclasses import dataclass, field

@dataclass
class Notification:
    """待播报的通知"""
    message: str
    priority: str          # "high" | "normal" | "low"
    source: str            # "agent" | "build" | "system"
    created_at: datetime = field(default_factory=datetime.now)
    
class NotificationScheduler:
    """
    通知调度器
    策略：
    1. high 优先级 → 立即 speak（等 idle 2s）
    2. normal → 等 idle 5s 再 speak
    3. low → 合并后在长 idle 时一起播报
    4. 如果通知堆积 > 3 条，合并为摘要
    """
    
    IDLE_THRESHOLD_HIGH = timedelta(seconds=2)
    IDLE_THRESHOLD_NORMAL = timedelta(seconds=5)
    IDLE_THRESHOLD_LOW = timedelta(seconds=15)
    MAX_QUEUE_BEFORE_MERGE = 3
    
    def __init__(self):
        self.queue: list[Notification] = []
    
    def add(self, notification: Notification):
        self.queue.append(notification)
    
    def check_and_dispatch(self, idle_duration: timedelta) -> Optional[str]:
        """
        检查是否应该播报通知
        
        Returns:
            要 speak 的文本，或 None
        """
        if not self.queue:
            return None
        
        # 按优先级排序
        self.queue.sort(key=lambda n: {"high": 0, "normal": 1, "low": 2}[n.priority])
        
        top = self.queue[0]
        threshold = {
            "high": self.IDLE_THRESHOLD_HIGH,
            "normal": self.IDLE_THRESHOLD_NORMAL,
            "low": self.IDLE_THRESHOLD_LOW,
        }[top.priority]
        
        if idle_duration < threshold:
            return None
        
        # 播报
        if len(self.queue) <= self.MAX_QUEUE_BEFORE_MERGE:
            # 逐条播报最高优先级的
            msg = self.queue.pop(0).message
            return msg
        else:
            # 合并播报
            messages = [n.message for n in self.queue[:5]]
            self.queue = self.queue[5:]
            return f"有{len(messages)}条通知：" + "；".join(messages)
```

### 4.4 事件监听

```python
# src/notification/events.py
from dataclasses import dataclass
from enum import Enum

class EventType(Enum):
    AGENT_COMPLETED = "agent_completed"
    AGENT_FAILED = "agent_failed"
    BUILD_SUCCESS = "build_success"
    BUILD_FAILED = "build_failed"
    PROCESS_EXITED = "process_exited"

@dataclass
class Event:
    type: EventType
    data: dict
    
    def to_notification_message(self) -> str:
        """转换为人类可读的通知消息"""
        if self.type == EventType.AGENT_COMPLETED:
            return f"Agent做完了: {self.data.get('summary', '任务完成')}"
        elif self.type == EventType.AGENT_FAILED:
            return f"Agent失败: {self.data.get('error', '未知错误')}"
        elif self.type == EventType.BUILD_FAILED:
            return f"构建失败: {self.data.get('error', '')}"
        elif self.type == EventType.BUILD_SUCCESS:
            return "构建成功"
        elif self.type == EventType.PROCESS_EXITED:
            return f"{self.data.get('process', '进程')}退出了"
        return str(self.data)
```

### 4.5 依赖

- 无新依赖（标准库 threading/subprocess）

### 4.6 验收标准

- [ ] `agent_delegate("写个测试")` 启动子进程并异步等待
- [ ] Agent 完成后，在用户 idle 时 speak 通知
- [ ] 多个通知堆积时自动合并
- [ ] high 优先级通知（构建失败）在 2s idle 后立即播报
- [ ] 正在说话/操作时不打断用户

### 4.7 预计工作量：4 天

---

## Week 5: 手势检测 + 端到端联调

### 5.1 文件结构

```
Sources/Features/
├── Gesture/
│   ├── GestureDetector.swift       # Vision framework 手势检测
│   ├── DirectionMapper.swift       # 手指方向 → display 映射
│   └── GestureService.swift        # 对外服务接口
agent/src/tools/
├── gesture.py                      # Python 侧 gesture_direction 实现
```

### 5.2 macOS Vision Framework 手势方向检测

```swift
// Sources/Features/Gesture/GestureDetector.swift
import Vision
import AVFoundation
import AppKit

class GestureDetector: NSObject, ObservableObject {
    
    @Published var pointingDirection: CGVector? = nil  // 归一化方向向量
    @Published var isDetecting: Bool = false
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let processingQueue = DispatchQueue(label: "gesture.processing")
    
    override init() {
        super.init()
        handPoseRequest.maximumHandCount = 1
    }
    
    // MARK: - Public API
    
    func startDetection() {
        guard !isDetecting else { return }
        setupCamera()
        captureSession?.startRunning()
        isDetecting = true
    }
    
    func stopDetection() {
        captureSession?.stopRunning()
        isDetecting = false
        pointingDirection = nil
    }
    
    /// 获取当前手指指向方向（归一化到 -1...1）
    /// x: -1=左, 1=右
    /// y: -1=下, 1=上
    func getCurrentDirection() -> CGVector? {
        return pointingDirection
    }
    
    // MARK: - Camera Setup
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium
        
        guard let camera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .front
        ) else {
            print("⚠️ No front camera available")
            return
        }
        
        guard let input = try? AVCaptureDeviceInput(device: camera) else { return }
        session.addInput(input)
        
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: processingQueue)
        output.alwaysDiscardsLateVideoFrames = true
        session.addOutput(output)
        
        self.captureSession = session
        self.videoOutput = output
    }
}

// MARK: - Video Frame Processing

extension GestureDetector: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, 
                       didOutput sampleBuffer: CMSampleBuffer, 
                       from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        do {
            try handler.perform([handPoseRequest])
            
            guard let observation = handPoseRequest.results?.first else {
                DispatchQueue.main.async { self.pointingDirection = nil }
                return
            }
            
            // 提取食指尖和食指根部的关节点
            let indexTip = try observation.recognizedPoint(.indexTip)
            let indexMCP = try observation.recognizedPoint(.indexMCP)
            
            // 置信度检查
            guard indexTip.confidence > 0.5 && indexMCP.confidence > 0.5 else {
                DispatchQueue.main.async { self.pointingDirection = nil }
                return
            }
            
            // 计算指向方向（从指根到指尖的向量）
            let dx = indexTip.location.x - indexMCP.location.x
            let dy = indexTip.location.y - indexMCP.location.y
            
            // 归一化
            let magnitude = sqrt(dx * dx + dy * dy)
            guard magnitude > 0.05 else {  // 太短=没有明确指向
                DispatchQueue.main.async { self.pointingDirection = nil }
                return
            }
            
            let direction = CGVector(
                dx: dx / magnitude,
                dy: dy / magnitude
            )
            
            DispatchQueue.main.async {
                self.pointingDirection = direction
            }
            
        } catch {
            // 静默忽略帧处理错误
        }
    }
}
```

### 5.3 方向 → Display 映射

```swift
// Sources/Features/Gesture/DirectionMapper.swift
import AppKit

class DirectionMapper {
    
    struct DisplayPosition {
        let displayId: Int
        let index: Int
        let frame: CGRect
        let centerAngle: Double  // 相对于用户的角度（度）
    }
    
    /// 根据手指方向向量，映射到最近的显示器
    /// 
    /// 逻辑：
    /// 1. 获取所有显示器的物理位置
    /// 2. 计算每个显示器中心相对于主显示器的角度
    /// 3. 将手指方向角度与显示器角度匹配
    func mapToDisplay(direction: CGVector) -> Int? {
        let screens = NSScreen.screens
        guard screens.count > 1 else {
            return screens.first.map { displayId(for: $0) }
        }
        
        // 手指方向角度（弧度→度）
        // 注意：摄像头是镜像的，x 需要翻转
        let fingerAngle = atan2(direction.dy, -direction.dx) * 180 / .pi
        
        // 获取主屏位置作为参考中心
        guard let mainScreen = NSScreen.main else { return nil }
        let mainCenter = CGPoint(
            x: mainScreen.frame.midX, 
            y: mainScreen.frame.midY
        )
        
        // 计算每个屏幕相对于主屏的角度
        var bestMatch: (displayId: Int, angleDiff: Double) = (0, .infinity)
        
        for screen in screens {
            let screenCenter = CGPoint(
                x: screen.frame.midX,
                y: screen.frame.midY
            )
            
            let dx = screenCenter.x - mainCenter.x
            let dy = screenCenter.y - mainCenter.y
            let screenAngle = atan2(dy, dx) * 180 / .pi
            
            // 角度差
            var diff = abs(fingerAngle - screenAngle)
            if diff > 180 { diff = 360 - diff }
            
            let did = displayId(for: screen)
            if diff < bestMatch.angleDiff {
                bestMatch = (did, diff)
            }
        }
        
        // 角度差 < 60度 才认为是有效匹配
        return bestMatch.angleDiff < 60 ? bestMatch.displayId : nil
    }
    
    private func displayId(for screen: NSScreen) -> Int {
        return Int(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID ?? 0)
    }
}
```

### 5.4 手势服务（CLI 接口）

```swift
// Sources/Features/Gesture/GestureService.swift
import Foundation

class GestureService {
    
    static let shared = GestureService()
    
    private let detector = GestureDetector()
    private let mapper = DirectionMapper()
    
    /// 获取当前手指指向的 display
    /// 返回 JSON: {"display_id": 2, "direction": "right", "confidence": 0.8}
    func getPointingDisplay() -> [String: Any] {
        guard let direction = detector.getCurrentDirection() else {
            return ["display_id": NSNull(), "direction": NSNull(), "error": "no_hand_detected"]
        }
        
        let displayId = mapper.mapToDisplay(direction: direction)
        
        // 方向描述
        let directionName: String
        if direction.dx > 0.5 {
            directionName = "right"
        } else if direction.dx < -0.5 {
            directionName = "left"
        } else if direction.dy > 0.5 {
            directionName = "up"
        } else {
            directionName = "forward"
        }
        
        return [
            "display_id": displayId as Any,
            "direction": directionName,
            "vector": ["x": direction.dx, "y": direction.dy]
        ]
    }
    
    func startBackgroundDetection() {
        detector.startDetection()
    }
    
    func stopDetection() {
        detector.stopDetection()
    }
}
```

### 5.5 Python 侧 gesture_direction 实现

```python
# src/tools/gesture.py
import subprocess
import json

class GestureTool:
    """手势方向检测工具 —— 调用 vista-cmd gesture"""
    
    def __init__(self, vista_cmd_path: str):
        self.vista_cmd = vista_cmd_path
    
    def get_direction(self) -> dict:
        """
        获取手势指向的显示器
        
        Returns:
            {
                "success": True,
                "display_id": 2,       # 指向的显示器 ID
                "direction": "right",  # 方向描述
                "vector": {"x": 0.8, "y": 0.1}  # 归一化方向向量
            }
            
            或者无手势时:
            {
                "success": False,
                "error": "no_hand_detected"
            }
        """
        try:
            result = subprocess.run(
                [self.vista_cmd, "gesture", "direction"],
                capture_output=True, text=True, timeout=2
            )
            data = json.loads(result.stdout.strip())
            if data.get("display_id") is None:
                return {"success": False, "error": "no_hand_detected"}
            return {"success": True, **data}
        except Exception as e:
            return {"success": False, "error": str(e)}
```

### 5.6 语音+手势组合指令流程

```
用户说话时，agent 自动检查是否需要手势信息：

1. ASR 识别文本
2. LLM 判断是否包含空间指代（"这里"/"那边"/"右边屏幕"）
3. 如果包含 → LLM 调用 gesture_direction() 工具
4. 获取 display_id → 作为 yabai_action 的参数
5. 执行 + popup 反馈

LLM 识别空间指代的 prompt 示例：
- "在这里开个终端" → 需要 gesture_direction
- "移到那边" → 需要 gesture_direction  
- "切到右边屏幕" → 不需要（明确说了"右边"）
- "切到终端" → 不需要（无空间指代）
```

### 5.7 依赖

- macOS Vision framework（系统内置，macOS 11+）
- AVFoundation（摄像头访问）

#### 系统权限

- **摄像头权限**：Info.plist 添加 `NSCameraUsageDescription`
- 在 `Info.plist` 中添加：

```xml
<key>NSCameraUsageDescription</key>
<string>Vista 需要摄像头来检测手势方向，用于指向操作显示器。</string>
```

### 5.8 端到端联调清单

| 流程 | 验证点 |
|------|--------|
| 语音 → 窗口切换 | "切到终端" → focus Terminal + popup |
| 语音 → 移动窗口 | "移到左边" → move left + popup |
| 手势 + 语音 | [指右屏] "在这里开终端" → gesture → Terminal on display 2 |
| Agent 委派 | "帮我写测试" → delegate → 完成后 speak |
| 通知调度 | 构建失败 → idle 2s → speak |
| Context 连贯 | "切到终端" → "跑 npm" → "切回刚才的" → focus 上一个 |
| 宠物状态 | 全程状态指示正确流转：idle → 🎤 → 🤔 → ⚡ → idle |

### 5.9 验收标准

- [ ] 摄像头检测手指方向，延迟 < 100ms
- [ ] 方向正确映射到对应显示器（双屏场景下 > 80% 准确率）
- [ ] "在这里开终端" + 指右屏 → Terminal 出现在右屏
- [ ] 无手势时 graceful fallback（ask 用户在哪里）
- [ ] 端到端完整流程无阻塞
- [ ] 宠物状态指示全程正确

### 5.10 预计工作量：5 天

---

## 总结

### 工作量汇总

| Week | 模块 | 工作量 | 关键交付物 |
|------|------|--------|-----------|
| 1 | CLI + 宠物窗口 | 5 天 | vista-cmd 完整命令集 + 宠物窗口 |
| 2 | Agent 核心 | 5 天 | ASR + LLM Tool Calling + 执行管线 |
| 3 | Context Manager | 4 天 | 窗口描述 + 历史 + Reference Stack |
| 4 | 委派 + 通知 | 4 天 | Agent 子进程 + 通知调度 |
| 5 | 手势 + 联调 | 5 天 | Vision 手势 + 端到端验证 |
| **总计** | | **23 天** | |

### 技术栈总览

| 层 | 技术 | 语言 |
|----|------|------|
| CLI + 宠物 | Swift + SwiftUI + yabai socket | Swift |
| Agent 核心 | faster-whisper + OpenAI SDK | Python |
| LLM | 豆包 API (Tool Calling) | — |
| 手势 | Vision framework + AVFoundation | Swift |
| TTS | macOS `say` 命令 | — |
| 进程通信 | subprocess (stdin/stdout) | Python → Swift |

### 风险点

| 风险 | 缓解措施 |
|------|---------|
| Vision 手势方向精度不够 | 加入校准流程（用户首次指向各屏幕） |
| 多屏映射角度不准 | 支持手动配置显示器物理方位 |
| whisper small 中文差 | fallback 到 medium 模型，或接入在线 ASR |
| 豆包 API 延迟波动 | 简单指令缓存 + 本地快速路径 |
| 宠物窗口被遮挡 | NSWindow.level = .floating + canJoinAllSpaces |
